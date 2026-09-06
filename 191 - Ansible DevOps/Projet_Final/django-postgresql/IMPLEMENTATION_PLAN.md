# Plan d’implémentation — Django + PostgreSQL avec Ansible

> **Projet :** second projet applicatif du module `191 — Ansible DevOps`  
> **Stack cible :** Nginx → Gunicorn → Django → PostgreSQL  
> **Branche :** `feat/ansible-django-postgresql-project`  
> **Statut :** planification de l’implémentation

---

## 1. Objectif

L’objectif est de construire puis qualifier un déploiement Ansible complet d’une application Django connectée à PostgreSQL.

Le projet doit aller au-delà d’une simple installation de paquets. Il doit démontrer toute la chaîne :

```text
Infrastructure Linux disponible
        ↓
Inventaire Ansible
        ↓
Préparation système
        ↓
PostgreSQL
        ↓
Base + utilisateur applicatif
        ↓
Django + virtualenv
        ↓
Migrations
        ↓
Gunicorn / systemd
        ↓
Nginx
        ↓
HTTP
        ↓
Health checks
        ↓
Validation Django → PostgreSQL
        ↓
Deuxième déploiement
        ↓
Idempotence
        ↓
Packaging + preuves
```

---

## 2. Architecture cible

```text
                         ANSIBLE CONTROL NODE
                                │
                                │ SSH
                  ┌─────────────┴─────────────┐
                  │                           │
                  ▼                           ▼
       ┌─────────────────────┐     ┌─────────────────────┐
       │ app1                │     │ db1                 │
       │ Ubuntu 24.04        │     │ Ubuntu 24.04        │
       │                     │     │                     │
       │ Nginx :80           │     │ PostgreSQL :5432    │
       │      │              │     │                     │
       │      ▼              │     │ database: django_app│
       │ Gunicorn :8000      │────►│ user: django_app    │
       │      │              │ SQL │                     │
       │      ▼              │     │ accès depuis app1   │
       │ Django              │     │ uniquement          │
       └─────────────────────┘     └─────────────────────┘
                  ▲
                  │ HTTP :80
                  │
               Client
```

Gunicorn n’est pas exposé publiquement. Il écoute sur `127.0.0.1:8000` et Nginx constitue le point d’entrée HTTP.

---

## 3. Principes d’implémentation

Le projet suivra les principes suivants :

1. **Séparation des responsabilités** avec quatre rôles Ansible : `common`, `postgresql`, `django_app`, `nginx`.
2. **Secrets hors Git** avec Ansible Vault.
3. **Compte PostgreSQL applicatif dédié**, sans accès distant du superutilisateur.
4. **Gunicorn non exposé au réseau externe**.
5. **PostgreSQL accessible uniquement depuis le tier applicatif** lorsque le réseau permet de déterminer précisément son CIDR.
6. **FQCN Ansible** dans les tâches exécutables.
7. **Handlers** pour les redémarrages/reloads de services.
8. **Idempotence** comme critère de qualification, pas uniquement comme intention.
9. **Health checks applicatifs réels**, incluant une requête PostgreSQL depuis Django.
10. **Aucune preuve runtime fictive** : les logs ne seront considérés comme preuves qu’après exécution réelle.

---

## 4. Arborescence cible

```text
django-postgresql/
├── README.md
├── ARCHITECTURE.md
├── IMPLEMENTATION_PLAN.md
├── IMPLEMENTATION_GUIDE.md
├── TESTS_AND_VALIDATION.md
├── TROUBLESHOOTING.md
├── E2E_QUALIFICATION_REPORT.md
│
├── django-app/
│   ├── manage.py
│   ├── requirements.txt
│   ├── config/
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   └── health/
│       ├── urls.py
│       └── views.py
│
├── ansible-project/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventories/prod/
│   │   ├── hosts.example.yml
│   │   ├── group_vars/
│   │   │   ├── all.yml
│   │   │   └── vault.example.yml
│   │   └── host_vars/
│   │       ├── app1.example.yml
│   │       └── db1.example.yml
│   ├── playbooks/
│   │   ├── site.yml
│   │   └── validate.yml
│   ├── roles/
│   │   ├── common/
│   │   ├── postgresql/
│   │   ├── django_app/
│   │   └── nginx/
│   ├── scripts/
│   │   ├── preflight.sh
│   │   ├── deploy.sh
│   │   ├── validate_runtime.sh
│   │   └── package.sh
│   └── tests/
│       └── static_checks.sh
│
└── evidence/
    ├── logs/
    ├── screenshots/
    └── validation/
```

---

# 5. Lots d’implémentation

## LOT 00 — Bootstrap et contrats du projet

### Objectif

Créer le squelette reproductible avant toute logique système.

### Livrables

```text
README.md
ARCHITECTURE.md
IMPLEMENTATION_PLAN.md
ansible-project/ansible.cfg
ansible-project/requirements.yml
inventories/prod/*
django-app/*
```

### Critères de sortie

- structure cohérente ;
- aucun secret réel ;
- inventaire d’exemple présent ;
- variables publiques séparées des variables Vault ;
- mini-application Django définie.

---

## LOT 01 — Application Django minimale

### Objectif

Disposer d’une application suffisamment petite pour rester pédagogique, mais capable de prouver la chaîne applicative.

### Endpoints

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

### Contrat attendu

`/health/` doit répondre sans dépendre de PostgreSQL :

```json
{"status": "healthy"}
```

`/health/database/` doit exécuter une vraie requête :

```sql
SELECT 1;
```

puis répondre :

```json
{
  "status": "healthy",
  "database": "connected",
  "query": 1
}
```

En cas d’échec DB, l’endpoint doit retourner HTTP `503`.

### Critères de sortie

- configuration par variables d’environnement ;
- aucune `SECRET_KEY` codée en dur ;
- PostgreSQL utilisé via Django ORM/backend ;
- Gunicorn présent dans les dépendances.

---

## LOT 02 — Rôle `common`

### Objectif

Préparer un socle Linux identique sur les deux machines.

### Responsabilités

```text
apt cache
packages communs
timezone / prérequis si nécessaires
répertoires communs
outils de diagnostic
```

Le rôle ne doit contenir aucune logique Django ou PostgreSQL spécifique.

### Validation

```bash
ansible all -m ansible.builtin.ping
```

---

## LOT 03 — Rôle `postgresql`

### Objectif

Construire entièrement le tier base de données.

### Pipeline

```text
Install PostgreSQL
        ↓
Install Python PostgreSQL driver
        ↓
Start + enable PostgreSQL
        ↓
postgresql.conf
        ↓
listen_addresses
        ↓
pg_hba.conf
        ↓
Create django_app database
        ↓
Create django_app user
        ↓
Grant required privileges
        ↓
Reload / restart
```

### Variables sensibles

```yaml
vault_postgresql_password: ...
```

### Sécurité

À éviter :

```text
host all all 0.0.0.0/0 trust
```

La règle `pg_hba.conf` devra viser le compte et la base applicatifs et, lorsque possible, l’adresse/CIDR de `app1`.

### Validation

Sur `db1` :

```text
PostgreSQL active       ✅
TCP :5432               ✅
DB django_app           ✅
role django_app         ✅
```

---

## LOT 04 — Rôle `django_app`

### Objectif

Déployer l’application et son runtime Python.

### Pipeline

```text
Create django user/group
        ↓
Create /opt/datascientest-django
        ↓
Deploy source code
        ↓
Create Python venv
        ↓
pip install requirements.txt
        ↓
Render environment file
        ↓
manage.py migrate
        ↓
manage.py collectstatic
        ↓
Install gunicorn.service
        ↓
systemctl daemon-reload
        ↓
Start + enable Gunicorn
```

### Fichier d’environnement cible

Exemple conceptuel :

```text
/etc/datascientest-django/django.env
```

Il contiendra notamment :

```text
DJANGO_SECRET_KEY
DJANGO_DEBUG
DJANGO_ALLOWED_HOSTS
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_HOST
POSTGRES_PORT
```

Permissions attendues : accès limité à l’utilisateur/service applicatif.

### Vault

```yaml
vault_django_secret_key: ...
vault_postgresql_password: ...
```

### Gunicorn

```text
systemd
   │
   ▼
gunicorn.service
   │
   ▼
127.0.0.1:8000
```

### Critères de sortie

```text
migrations OK
collectstatic OK
Gunicorn active
127.0.0.1:8000 accessible
Django peut joindre PostgreSQL
```

---

## LOT 05 — Rôle `nginx`

### Objectif

Créer le frontend HTTP du projet.

### Architecture

```text
Client
  │
  │ :80
  ▼
Nginx
  │
  ├── /static/ → STATIC_ROOT
  │
  └── / → proxy_pass http://127.0.0.1:8000
                         │
                         ▼
                      Gunicorn
```

### Responsabilités

- installer Nginx ;
- créer le vhost Django ;
- désactiver le site par défaut ;
- configurer le reverse proxy ;
- servir les assets statiques ;
- tester la configuration avant reload ;
- activer et démarrer le service.

### Validation

```text
nginx -t                    ✅
systemctl is-active nginx   ✅
HTTP :80                    ✅
```

---

## LOT 06 — Orchestration `site.yml`

### Ordre cible

```text
PLAY 1 — all
    role common
        ↓
PLAY 2 — database
    role postgresql
        ↓
PLAY 3 — app
    role django_app
        ↓
PLAY 4 — app
    role nginx
```

L’ordre est intentionnel : Django ne doit pas lancer ses migrations avant que PostgreSQL soit prêt.

### Critères de sortie

```bash
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml
```

sans `failed` ni `unreachable`.

---

## LOT 07 — Validation runtime

Créer `playbooks/validate.yml` afin de vérifier le système réellement déployé.

### Tier DB

```text
PostgreSQL active
PostgreSQL :5432
DB existante
```

### Tier App

```text
Gunicorn active
Gunicorn :8000 local
Nginx active
Nginx :80
app1 → db1:5432
```

### Validation applicative

```text
GET /                    → 200
GET /health/             → 200
GET /health/database/    → 200
GET /api/info/           → 200
```

Le contrôle `/health/database/` constitue la preuve principale du chemin :

```text
HTTP
 ↓
Nginx
 ↓
Gunicorn
 ↓
Django
 ↓
psycopg
 ↓
PostgreSQL
 ↓
SELECT 1
 ↓
HTTP 200
```

---

## LOT 08 — Scripts d’exploitation et preuves

Créer :

```text
scripts/preflight.sh
scripts/deploy.sh
scripts/validate_runtime.sh
scripts/package.sh
```

### `preflight.sh`

Doit vérifier :

```text
inventory graph
ping app1/db1
syntax-check
```

### `deploy.sh`

Doit exécuter `site.yml` et enregistrer la sortie dans :

```text
evidence/logs/deploy-<timestamp>.txt
```

### `validate_runtime.sh`

Doit exécuter `validate.yml` et enregistrer :

```text
evidence/logs/validation-<timestamp>.txt
```

### `package.sh`

Doit produire un ZIP portable en excluant :

```text
vault.yml
.vault_pass
private keys
inventaire réel sensible
fichiers temporaires
anciens ZIP
```

---

## LOT 09 — Tests statiques

Créer `tests/static_checks.sh`.

Il devra au minimum vérifier :

```text
structure attendue
YAML parsable
playbooks présents
4 rôles présents
templates présents
application Django présente
absence des fichiers secrets runtime
```

Si Ansible et un inventaire local sont disponibles :

```text
ansible-playbook --syntax-check
```

---

## LOT 10 — Première qualification end-to-end

### Scénario

```text
Provision app1 + db1
        ↓
Generate ephemeral secrets
        ↓
Encrypt Vault
        ↓
Preflight
        ↓
Deploy
        ↓
Validate services
        ↓
Validate app1 → db1:5432
        ↓
Validate Django DB query
        ↓
Validate HTTP from control node
```

### Matrice attendue

| ID | Test | Résultat attendu |
|---|---|---|
| E2E-01 | Inventory | PASS |
| E2E-02 | Ansible ping app1 | PASS |
| E2E-03 | Ansible ping db1 | PASS |
| E2E-04 | Syntax check | PASS |
| E2E-05 | PostgreSQL service | PASS |
| E2E-06 | PostgreSQL 5432 | PASS |
| E2E-07 | DB + user | PASS |
| E2E-08 | app1 → db1:5432 | PASS |
| E2E-09 | migrations Django | PASS |
| E2E-10 | Gunicorn service | PASS |
| E2E-11 | Gunicorn local 8000 | PASS |
| E2E-12 | Nginx | PASS |
| E2E-13 | `/health/` | HTTP 200 |
| E2E-14 | `/health/database/` | HTTP 200 |
| E2E-15 | SQL `SELECT 1` via Django | PASS |

---

## LOT 11 — Idempotence

Après le premier run vert :

```bash
ansible-playbook playbooks/site.yml
```

sera exécuté une seconde fois sans reconstruire les machines.

Critère strict :

```text
app1 : changed=0
db1  : changed=0
```

Toute tâche restant en `changed` devra être analysée avant qualification finale.

---

## LOT 12 — GitHub Actions E2E

Après qualification locale du scénario, créer un workflow reproductible :

```text
.github/workflows/ansible-django-postgresql-e2e.yml
```

Pipeline cible :

```text
checkout
   ↓
install Ansible
   ↓
install collections
   ↓
provision 2 Ubuntu targets
   ↓
generate ephemeral Vault
   ↓
preflight
   ↓
deploy
   ↓
runtime validation
   ↓
HTTP validation
   ↓
second deployment
   ↓
assert changed=0
   ↓
package
   ↓
SHA-256
   ↓
upload evidence
```

---

## LOT 13 — Rapport de qualification

Une fois le workflow réellement vert, créer :

```text
E2E_QUALIFICATION_REPORT.md
```

Il devra contenir uniquement des preuves réellement observées :

- environnement ;
- versions ;
- run GitHub Actions ;
- PLAY RECAP ;
- health checks ;
- validation PostgreSQL ;
- second run ;
- SHA-256 ;
- artifact ID ;
- incidents et root causes ;
- limites de la preuve.

Le rapport ne sera pas pré-rempli avec de faux résultats.

---

# 6. Roadmap synthétique

```text
LOT 00  Bootstrap                         ⏳
   ↓
LOT 01  Mini application Django           ⏳
   ↓
LOT 02  common                            ⏳
   ↓
LOT 03  postgresql                        ⏳
   ↓
LOT 04  django_app                        ⏳
   ↓
LOT 05  nginx                             ⏳
   ↓
LOT 06  site.yml                          ⏳
   ↓
LOT 07  validate.yml                      ⏳
   ↓
LOT 08  scripts + evidence                ⏳
   ↓
LOT 09  static checks                     ⏳
   ↓
LOT 10  première qualification E2E        ⏳
   ↓
LOT 11  idempotence changed=0             ⏳
   ↓
LOT 12  GitHub Actions E2E                ⏳
   ↓
LOT 13  E2E_QUALIFICATION_REPORT.md       ⏳
```

---

# 7. Définition de Done globale

Le projet sera considéré **terminé et qualifié** uniquement lorsque les conditions suivantes seront réunies :

```text
4 rôles Ansible opérationnels             ✅ attendu
Django réellement déployé                 ✅ attendu
PostgreSQL réellement déployé             ✅ attendu
Gunicorn géré par systemd                  ✅ attendu
Nginx reverse proxy                        ✅ attendu
Vault                                      ✅ attendu
migrations                                 ✅ attendu
collectstatic                              ✅ attendu
app1 → db1:5432                            ✅ attendu
/health/                                   ✅ attendu
/health/database/                          ✅ attendu
HTTP depuis control node                   ✅ attendu
second run changed=0                       ✅ attendu
ZIP                                        ✅ attendu
SHA-256                                    ✅ attendu
artifact de preuves                        ✅ attendu
rapport E2E basé sur le run réel           ✅ attendu
```

Avant ces validations, le statut doit rester **implémenté / en qualification**, et non **qualifié E2E**.

---

# 8. Ordre de réalisation recommandé

La prochaine livraison de code après ce document sera :

```text
LOT 01 — Mini application Django
        +
LOT 02 — rôle common
        +
LOT 03 — rôle postgresql
```

Ce découpage permet de disposer rapidement du premier chemin critique :

```text
Django
   ↓
configuration DB
   ↓
PostgreSQL
```

avant d’ajouter Gunicorn, Nginx et la qualification HTTP complète.
