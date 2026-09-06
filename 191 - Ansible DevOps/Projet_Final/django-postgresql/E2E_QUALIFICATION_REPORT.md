# Rapport final de qualification E2E — Django + PostgreSQL

## 1. Résumé exécutif

Le projet Ansible `django-postgresql` est **QUALIFIÉ GREEN dans le périmètre CI d'intégration/E2E défini par le projet**.

La qualification finale a été réalisée par le workflow GitHub Actions :

```text
Ansible Django PostgreSQL E2E Final
```

Référence canonique :

| Élément | Valeur |
|---|---|
| Workflow | `Ansible Django PostgreSQL E2E Final` |
| Run | `#8` |
| Run ID | `34052400653` |
| Job | `final-e2e` |
| Job ID | `101538231238` |
| Commit qualifié | `2855c8f4daad1b8d962a576279ed7fd1c32dcb46` |
| Début | `2026-09-06T18:39:12Z` |
| Fin | `2026-09-06T18:43:09Z` |
| Conclusion | `success` |

URL du run :

```text
https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34052400653
```

Le pipeline a prouvé dans une même exécution :

```text
static checks
      ↓
2 cibles Ubuntu 24.04 isolées
      ↓
first site.yml
      ↓
PostgreSQL + Django + Gunicorn + Nginx
      ↓
runtime validation
      ↓
HTTP /health/ + /health/database/
      ↓
Django → psycopg → PostgreSQL → SELECT 1
      ↓
second site.yml
      ↓
app1 changed=0 / db1 changed=0
      ↓
runtime validation post-idempotence
      ↓
ZIP
      ↓
SHA-256 verify
      ↓
package safety gate
      ↓
GitHub Actions artifact
```

---

## 2. Périmètre qualifié

L'architecture vérifiée est :

```text
                          CONTROL NODE CI
                                │
                     community.docker.docker
                                │
                  ┌─────────────┴─────────────┐
                  │                           │
                  ▼                           ▼
       ┌─────────────────────┐     ┌─────────────────────┐
       │ app1                │     │ db1                 │
       │ Ubuntu 24.04        │     │ Ubuntu 24.04        │
       │                     │     │                     │
       │ Nginx :80           │     │ PostgreSQL :5432    │
       │      │              │     │ DB: django_app      │
       │      ▼              │     │ user: django_app    │
       │ Gunicorn            │────►│ SCRAM-SHA-256       │
       │ 127.0.0.1:8000      │ SQL │                     │
       │      │              │     │ accès limité app1   │
       │      ▼              │     │                     │
       │ Django              │     │                     │
       └─────────────────────┘     └─────────────────────┘
```

Le projet qualifie les quatre rôles :

```text
common
postgresql
django_app
nginx
```

et les deux playbooks principaux :

```text
playbooks/site.yml
playbooks/validate.yml
```

---

## 3. Environnement de qualification

### 3.1 Control node

Le run final a utilisé :

| Composant | Version / valeur observée |
|---|---|
| GitHub Actions runner | `ubuntu-24.04` |
| OS runner | Ubuntu `24.04.4 LTS` |
| Python | `3.12.14` |
| Ansible Core | `2.20.8` |
| `community.postgresql` | `4.2.0` |
| `community.docker` | `4.8.8` |

### 3.2 Cibles

Deux cibles systemd Ubuntu 24.04 isolées ont été provisionnées à partir de :

```text
geerlingguy/docker-ubuntu2404-ansible:latest
```

Digest observé lors du run :

```text
sha256:18bf80157ea24b3210eb25ca89a5460912271b0ee61f238f36d2b115c89e39e6
```

Adresses de qualification de ce run :

```text
app1 = 172.18.0.2
db1  = 172.18.0.3
```

Ces adresses sont éphémères et n'ont aucune valeur de configuration de production.

---

## 4. Gate statique

Avant toute configuration distante, le pipeline a exécuté `tests/static_checks.sh`.

Résultats observés :

```text
OK: Ansible project structure
OK: Django scaffold and dependencies
OK: Bash syntax
OK: Python source parses with ast
OK: YAML parses with PyYAML
OK: venv, PostgreSQL, Gunicorn and allowed-host hardening
OK: No forbidden sensitive runtime files tracked
OK: site.yml syntax-check
OK: validate.yml syntax-check
All available static checks passed.
```

Le gate couvre notamment :

- structure du projet ;
- syntaxe Bash, Python et YAML ;
- environnement Python standard `venv` nommé `.venv` ;
- Gunicorn lié à `127.0.0.1:8000` ;
- authentification PostgreSQL SCRAM ;
- absence de règle PostgreSQL `trust` ;
- absence de CIDR global `0.0.0.0/0` / `::/0` ;
- absence de wildcard `DJANGO_ALLOWED_HOSTS=*` dans la configuration canonique ;
- absence de fichiers runtime sensibles suivis par Git.

---

## 5. Premier déploiement

Le premier `site.yml` s'est terminé sans échec ni cible inaccessible.

```text
app1      : ok=37 changed=24 unreachable=0 failed=0 skipped=0
db1       : ok=23 changed=13 unreachable=0 failed=0 skipped=0
localhost : ok=1  changed=0  unreachable=0 failed=0 skipped=0
```

Les changements sont attendus pour un premier provisioning : packages, timezone, PostgreSQL, base et rôle applicatif, code Django, `.venv`, dépendances Python, migrations, collectstatic, unité systemd Gunicorn et configuration Nginx.

---

## 6. Validation runtime

Après déploiement, `playbooks/validate.yml` a vérifié l'état fonctionnel sans modifier les cibles.

```text
app1      : ok=13 changed=0 unreachable=0 failed=0
 db1      : ok=6  changed=0 unreachable=0 failed=0
localhost : ok=1  changed=0 unreachable=0 failed=0
```

Les services ont été vérifiés actifs :

```text
app1 nginx=active
app1 gunicorn=active
db1 postgresql=active
```

La qualification couvre :

- PostgreSQL actif ;
- port local PostgreSQL disponible ;
- base `django_app` présente ;
- rôle PostgreSQL `django_app` présent ;
- Gunicorn actif ;
- port local Gunicorn disponible ;
- Nginx actif ;
- `nginx -t` valide ;
- app1 capable d'atteindre PostgreSQL ;
- endpoints HTTP applicatifs conformes.

---

## 7. Validation applicative et SQL

Les endpoints suivants sont qualifiés :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

Le contrôle le plus important est :

```text
GET /health/database/
        │
        ▼
      Nginx
        │
        ▼
     Gunicorn
        │
        ▼
      Django
        │
        ▼
      psycopg
        │
        ▼
   PostgreSQL
        │
        ▼
     SELECT 1
        │
        ▼
     HTTP 200
```

Le payload validé doit notamment prouver :

```json
{
  "status": "healthy",
  "database": "connected",
  "query": 1
}
```

Cette preuve couvre donc la chaîne applicative complète et pas uniquement l'ouverture du port TCP 5432.

---

## 8. Idempotence stricte

Le même `site.yml` a ensuite été appliqué une deuxième fois sur les mêmes cibles, avec le même inventaire et les mêmes secrets.

Résultat :

```text
app1      : ok=34 changed=0 unreachable=0 failed=0 skipped=1
db1       : ok=21 changed=0 unreachable=0 failed=0 skipped=0
localhost : ok=1  changed=0  unreachable=0 failed=0 skipped=0
```

Assertions du harness :

```text
IDEMPOTENCE PASS: app1 changed=0
IDEMPOTENCE PASS: db1 changed=0
```

La validation runtime a été rejouée après ce second déploiement et est restée GREEN :

```text
app1 : ok=13 changed=0 unreachable=0 failed=0
db1  : ok=6  changed=0 unreachable=0 failed=0
```

L'idempotence est donc prouvée conjointement avec la conservation de l'état fonctionnel.

---

## 9. Secrets et sécurité

Les secrets utilisés en CI sont créés de façon éphémère et chiffrés avec Ansible Vault avant le déploiement.

Le projet applique les principes suivants :

- aucun mot de passe réel dans Git ;
- aucun `.vault_pass` dans Git ou le package qualifié ;
- `no_log: true` sur les tâches contenant les secrets ;
- utilisateur PostgreSQL applicatif dédié et non superuser ;
- authentification `scram-sha-256` ;
- `pg_hba.conf` limité au réseau / à l'hôte applicatif attendu ;
- Gunicorn non exposé au réseau, uniquement `127.0.0.1:8000` ;
- Nginx comme point d'entrée HTTP ;
- inventaire runtime exclu du package final ;
- clés privées et fichiers `.pem` / `.key` exclus.

---

## 10. Packaging final

Le workflow final exécute :

```text
scripts/package.sh
      ↓
ZIP
      ↓
sha256sum -c
      ↓
tests/package_safety_check.sh
```

Archive interne qualifiée :

```text
django-postgresql-ansible-20260906-184304.zip
```

SHA-256 de l'archive projet :

```text
022740bacb16ebdd0bd9edbf04fe568fddd550079db9e5a9f5c08edfe378c664
```

Contrôles observés :

```text
sha256sum -c : OK
PACKAGE SAFETY PASS
```

Le package safety gate vérifie l'absence des catégories sensibles attendues avant upload.

---

## 11. Artefact GitHub Actions

L'artefact final publié est :

```text
ansible-django-postgresql-qualified-34052400653
```

| Élément | Valeur |
|---|---|
| Artifact ID | `9994995760` |
| Taille | `69139` octets |
| Digest de l'artefact GitHub | `sha256:06b6712b71e35d7df6443655423cfba177dcd94605b04efba284758d31bd80d0` |
| Créé | `2026-09-06T18:43:05Z` |
| Expiration | `2026-09-20T18:43:04Z` |

URL :

```text
https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34052400653/artifacts/9994995760
```

Le digest de l'artefact GitHub Actions est distinct du SHA-256 de l'archive projet, car l'artefact GitHub encapsule le ZIP qualifié, son checksum et les fichiers de preuve.

---

## 12. Definition of Done

| Exigence | Statut |
|---|---|
| architecture app1 / db1 | ✅ |
| rôle `common` | ✅ |
| rôle `postgresql` | ✅ |
| rôle `django_app` | ✅ |
| rôle `nginx` | ✅ |
| Python standard `venv` `.venv` | ✅ |
| Ansible Vault | ✅ |
| PostgreSQL SCRAM | ✅ |
| migrations Django | ✅ |
| collectstatic | ✅ |
| Gunicorn systemd | ✅ |
| Nginx reverse proxy | ✅ |
| app1 → db1 | ✅ |
| `/health/` | ✅ |
| `/health/database/` + `SELECT 1` | ✅ |
| static gate | ✅ |
| premier déploiement E2E | ✅ |
| validation runtime | ✅ |
| second déploiement | ✅ |
| `app1 changed=0` | ✅ |
| `db1 changed=0` | ✅ |
| ZIP qualifié | ✅ |
| SHA-256 vérifié | ✅ |
| package safety gate | ✅ |
| artefact GitHub Actions | ✅ |

---

## 13. Limites de la qualification

La mention **QUALIFIÉ E2E** doit être comprise dans le périmètre exact de cette campagne.

Elle prouve une intégration réelle des rôles, services, réseau inter-cibles et application sur deux systèmes Ubuntu 24.04 isolés. Elle **ne constitue pas** une qualification de production publique par SSH.

En particulier, le run final ne prouve pas :

- déploiement sur VM / serveurs publics réels via SSH ;
- DNS public ;
- TLS / certificats HTTPS ;
- firewall cloud ou security groups ;
- haute disponibilité ;
- load balancing multi-instance ;
- sauvegarde / restauration PostgreSQL ;
- observabilité de production ;
- rotation réelle de secrets ;
- tests de charge ou de performance ;
- reprise après sinistre.

Le transport Ansible de la campagne est `community.docker.docker`, utilisé comme harness reproductible de CI pour piloter deux cibles systemd séparées.

---

## 14. Conclusion

La progression du projet aboutit à une chaîne DevOps cohérente :

```text
code Django
   ↓
4 rôles Ansible
   ↓
site.yml
   ↓
validate.yml
   ↓
static checks
   ↓
E2E réel sur deux OS cibles
   ↓
idempotence stricte
   ↓
packaging sécurisé
   ↓
SHA-256
   ↓
artefact de preuve
```

Au terme du LOT 13, le projet peut être présenté comme :

> **Projet Ansible Django + PostgreSQL implémenté et qualifié E2E dans le harness CI GitHub Actions, avec validation applicative Django→PostgreSQL, idempotence stricte `changed=0`, packaging contrôlé et preuves reproductibles.**

Pour une qualification production supplémentaire, la prochaine étape naturelle serait de rejouer le même contrat sur de vraies VM Linux accessibles par SSH, avec DNS, TLS, règles réseau réelles, sauvegarde PostgreSQL et observabilité.