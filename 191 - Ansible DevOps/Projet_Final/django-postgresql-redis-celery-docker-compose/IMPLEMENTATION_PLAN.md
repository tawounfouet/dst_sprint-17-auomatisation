# Plan d’implantation — Django + PostgreSQL + Redis + Celery

## 1. Objectif

Créer une **nouvelle variante du projet Ansible Django/PostgreSQL mono-serveur déjà qualifié**, dans un dossier distinct, puis l’étendre avec **Redis** et **Celery** sans modifier ni dégrader la baseline existante.

Le projet source reste :

```text
191 - Ansible DevOps/Projet_Final/django-postgresql/
```

La nouvelle variante sera :

```text
191 - Ansible DevOps/Projet_Final/django-postgresql-redis-celery/
```

Le principe directeur est :

```text
baseline qualifiée
      ↓
copie contrôlée
      ↓
ajout Redis
      ↓
ajout Celery
      ↓
tâches de démonstration
      ↓
validation runtime
      ↓
qualification E2E mono-host dédiée
      ↓
idempotence
      ↓
package + SHA-256 + artifact
```

La copie ne doit pas hériter artificiellement du statut de qualification du projet source. La nouvelle variante sera considérée **implémentée mais non qualifiée** tant que son propre pipeline E2E n’aura pas produit un run GREEN.

---

## 2. Baseline de départ

La baseline source est le projet `django-postgresql`, actuellement qualifié en topologie mono-serveur :

```text
Nginx       :80
Gunicorn    127.0.0.1:8000
Django
PostgreSQL  127.0.0.1:5432
```

Le même hôte `server1` appartient aux groupes Ansible `app` et `database`.

Le projet source dispose déjà des éléments que l’on veut préserver :

- rôles `common`, `postgresql`, `django_app`, `nginx` ;
- Python standard `venv` sous `.venv` ;
- Gunicorn géré par systemd ;
- PostgreSQL localhost-only en mono-host ;
- endpoints `/`, `/health/`, `/health/database/`, `/api/info/` ;
- test applicatif Django → psycopg → PostgreSQL → `SELECT 1` ;
- validation runtime ;
- second `site.yml` avec `changed=0` ;
- packaging sécurisé ;
- SHA-256 ;
- qualification GitHub Actions mono-host.

Cette baseline est **une référence de conception**, pas une preuve directe pour la variante Redis/Celery.

---

## 3. Architecture cible

La nouvelle architecture mono-serveur devient :

```text
Internet / GitHub Actions runner
              │
              │ HTTP :80
              ▼
┌──────────────────────────────────────────────┐
│ server1 — Ubuntu 24.04 + systemd             │
│                                              │
│ Nginx :80                                    │
│    │                                         │
│    ▼                                         │
│ Gunicorn 127.0.0.1:8000                      │
│    │                                         │
│    ▼                                         │
│ Django                                       │
│    │                     │                   │
│    │ SQL                 │ Celery task       │
│    ▼                     ▼                   │
│ PostgreSQL              Redis                │
│ 127.0.0.1:5432          127.0.0.1:6379       │
│                           │                  │
│                           ▼                  │
│                    Celery Worker             │
│                           │                  │
│                           ├── tâches Python  │
│                           └── Django/DB      │
└──────────────────────────────────────────────┘
```

Le contrat réseau attendu est :

```text
80    → exposé via Nginx
8000  → localhost-only
5432  → localhost-only
6379  → localhost-only
```

En future VPS, le même principe sera conservé avec `443` public et `80` redirigé vers HTTPS.

---

## 4. Périmètre fonctionnel

La première version Redis/Celery doit rester volontairement petite. L’objectif n’est pas de construire une plateforme de jobs complexe, mais de démontrer correctement le pattern asynchrone.

Les capacités minimales seront :

```text
Django publie une tâche
        ↓
Redis transporte le message
        ↓
Celery Worker consomme la tâche
        ↓
la tâche produit un résultat
        ↓
le résultat peut être interrogé
```

Trois tâches de démonstration sont prévues :

```text
add(x, y)
uppercase(value)
database_probe()
```

### `add(x, y)`

Tâche pure permettant de vérifier le round-trip Celery :

```text
21 + 21 → 42
```

### `uppercase(value)`

Tâche pure permettant de vérifier le transport d’une chaîne et la sérialisation JSON :

```text
"datascientest" → "DATASCIENTEST"
```

### `database_probe()`

Tâche plus importante pour l’E2E : le worker Celery doit charger Django, accéder à PostgreSQL et exécuter une requête réelle, par exemple `SELECT 1`.

Le chemin qualifié devient alors :

```text
Celery Worker
     ↓
Django connection
     ↓
psycopg
     ↓
PostgreSQL
     ↓
SELECT 1
```

---

## 5. Endpoints applicatifs cibles

Les endpoints existants sont conservés :

```text
GET /                         
GET /health/
GET /health/database/
GET /api/info/
```

Les endpoints suivants seront ajoutés :

```text
GET  /health/redis/
GET  /health/celery/
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

### Exemple attendu

Soumission :

```http
POST /api/tasks/add/
Content-Type: application/json

{
  "x": 21,
  "y": 21
}
```

Réponse :

```json
{
  "task_id": "...",
  "status": "PENDING"
}
```

Puis :

```http
GET /api/tasks/<task_id>/
```

jusqu’à obtenir :

```json
{
  "task_id": "...",
  "status": "SUCCESS",
  "result": 42
}
```

La CI devra réellement effectuer cette séquence.

---

## 6. Dépendances Python

Le fichier `django-app/requirements.txt` sera étendu avec des versions bornées de :

```text
celery
redis
```

Le projet continuera à utiliser :

```text
Django
Gunicorn
psycopg[binary]
```

Aucune dépendance `virtualenv` ne sera introduite. Le runtime Python reste basé sur :

```text
python3 -m venv /opt/datascientest-django/.venv
```

---

## 7. Structure applicative cible

La copie devra évoluer vers une structure proche de :

```text
django-app/
├── manage.py
├── requirements.txt
├── config/
│   ├── __init__.py
│   ├── celery.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── health/
│   ├── apps.py
│   ├── urls.py
│   └── views.py
└── tasks_demo/
    ├── __init__.py
    ├── apps.py
    ├── tasks.py
    ├── urls.py
    ├── views.py
    └── tests/
```

`config/celery.py` portera l’initialisation de l’application Celery.

`config/__init__.py` exposera l’application Celery selon le pattern Django/Celery standard.

---

## 8. Configuration Celery

Les paramètres devront provenir de variables d’environnement et non être codés en dur dans le code Django.

Variables cibles :

```text
CELERY_BROKER_URL
CELERY_RESULT_BACKEND
```

Pour la topologie mono-host :

```text
Redis → 127.0.0.1:6379
```

Le broker et le result backend pourront utiliser deux bases Redis logiques distinctes, par exemple :

```text
broker  → /0
result  → /1
```

Le mot de passe Redis sera injecté depuis Ansible Vault.

---

## 9. Nouveau secret Vault

La nouvelle variante ajoute :

```yaml
vault_redis_password: ...
```

Les secrets deviennent donc :

```yaml
vault_postgresql_password: ...
vault_django_secret_key: ...
vault_redis_password: ...
```

Les mêmes règles que la baseline s’appliquent :

- jamais de secret réel dans Git ;
- jamais de `.vault_pass` versionné ;
- jamais de mot de passe imprimé dans les logs ;
- `no_log: true` sur les tâches Ansible manipulant les secrets ;
- secrets éphémères générés pendant la qualification GitHub Actions.

---

## 10. Rôles Ansible cibles

La nouvelle variante disposera de six rôles :

```text
roles/
├── common/
├── postgresql/
├── redis/
├── django_app/
├── celery/
└── nginx/
```

Les quatre rôles existants seront copiés depuis la baseline puis adaptés uniquement lorsque nécessaire.

### Rôle `redis`

Responsabilités :

```text
installation redis-server
configuration localhost-only
authentification
protected-mode
service systemd
validation locale PING
handlers restart/reload
```

Contrat de sécurité :

```text
bind 127.0.0.1
port 6379
protected-mode yes
```

Le rôle doit rester idempotent.

### Rôle `celery`

Responsabilités :

```text
validation des prérequis
installation du service systemd
WorkingDirectory Django
EnvironmentFile Django
ExecStart depuis .venv
worker Celery
enable/start
handler restart
```

Le worker utilisera le même utilisateur système que Django sauf besoin contraire démontré.

Le service attendu sera par exemple :

```text
datascientest-celery.service
```

Le lancement sera conceptuellement :

```text
/opt/datascientest-django/.venv/bin/celery \
  -A config worker \
  --loglevel=INFO
```

La concurrence restera faible pour le laboratoire afin de rester compatible avec les runners CI et petites VPS.

---

## 11. Ordre d’orchestration

Le `site.yml` cible devient :

```text
common
  ↓
postgresql
  ↓
redis
  ↓
django_app
  ↓
celery
  ↓
nginx
```

Cet ordre permet d’avoir les dépendances prêtes avant le démarrage de l’application et du worker.

Redis doit être actif avant Celery.

PostgreSQL doit être actif avant Django et avant les tâches Celery nécessitant la DB.

Django et ses dépendances Python doivent être installés avant que systemd ne démarre le worker Celery.

---

## 12. Validation runtime

`playbooks/validate.yml` sera étendu pour vérifier :

```text
PostgreSQL active
Redis active
Gunicorn active
Celery active
Nginx active
```

La validation Redis devra faire plus qu’un `systemctl is-active`.

Elle devra effectuer un vrai :

```text
PING → PONG
```

avec authentification si le mot de passe est activé.

La validation Celery devra combiner :

```text
service systemd actif
        +
round-trip de tâche réel
```

Le simple fait que le processus worker soit actif ne suffit pas à qualifier la chaîne asynchrone.

---

## 13. Qualification fonctionnelle Celery

Le scénario E2E canonique sera :

```text
POST /api/tasks/add/ avec 21 et 21
             ↓
HTTP 202 ou réponse équivalente
             ↓
task_id
             ↓
poll GET /api/tasks/<task_id>/
             ↓
SUCCESS
             ↓
result = 42
```

Puis :

```text
POST /api/tasks/database-probe/
             ↓
Redis
             ↓
Celery worker
             ↓
Django
             ↓
PostgreSQL
             ↓
SELECT 1
             ↓
result = 1 / healthy
```

Cette deuxième tâche devient la preuve la plus complète de la stack.

---

## 14. Contrat réseau

La qualification mono-host devra exiger :

```text
server1:80    reachable=true
server1:8000  reachable=false
server1:5432  reachable=false
server1:6379  reachable=false
```

Cela signifie :

```text
Nginx       public-facing
Gunicorn    localhost-only
PostgreSQL  localhost-only
Redis       localhost-only
```

Redis ne devra jamais être rendu accessible depuis l’extérieur du host dans cette architecture.

---

## 15. Idempotence

Le même `site.yml` sera exécuté deux fois sur la même cible.

Le second passage devra produire :

```text
server1 changed=0
```

Les nouveaux rôles seront donc soumis au même niveau d’exigence que la baseline.

Points d’attention :

```text
redis.conf
systemd Celery unit
handlers Redis/Celery
requirements Python
configuration Django
collectstatic
migrations
```

Aucune tâche ne devra redémarrer inutilement Redis, Celery, Gunicorn ou Nginx au second passage.

---

## 16. GitHub Actions

Un workflow séparé sera créé pour ne pas casser ni remplacer les qualifications existantes :

```text
.github/workflows/
└── ansible-django-postgresql-redis-celery-monohost.yml
```

Le harness cible sera :

```text
ansible-project/tests/e2e/
└── run_monohost_redis_celery_qualification.sh
```

La qualification devra suivre :

```text
static checks
      ↓
provision server1 Ubuntu 24.04 + systemd
      ↓
génération inventaire éphémère
      ↓
génération Vault éphémère
      ↓
site.yml #1
      ↓
validate.yml
      ↓
HTTP health checks
      ↓
Redis PING
      ↓
Celery add(21,21) → 42
      ↓
Celery database_probe() → SELECT 1
      ↓
contrat réseau 80/8000/5432/6379
      ↓
site.yml #2
      ↓
server1 changed=0
      ↓
validate.yml post-idempotence
      ↓
ZIP
      ↓
SHA-256
      ↓
package safety gate
      ↓
GitHub Actions artifact
```

---

## 17. Copie de la baseline

La copie initiale doit être contrôlée.

À copier :

```text
application Django
ansible-project/
rôles existants
playbooks
scripts
tests statiques
structure evidence
README / architecture / guides utiles
```

À ne pas considérer comme preuve pour le nouveau projet :

```text
anciens logs E2E
anciens fichiers runtime générés
anciens packages
ancien SHA-256
ancien artifact ID
ancien statut GREEN
```

Le nouveau dossier pourra conserver certains documents historiques comme référence, mais son README devra immédiatement indiquer :

```text
BASELINE COPIED          ✅
REDIS IMPLEMENTATION     ⏳
CELERY IMPLEMENTATION    ⏳
E2E QUALIFICATION        ⏳
IDEMPOTENCE              ⏳
```

L’ancien `evidence/` sera réinitialisé avec uniquement les fichiers structurels (`README.md`, `.gitkeep`) avant la première qualification de la variante.

---

## 18. Static checks

La suite de contrôle statique devra être étendue pour vérifier notamment :

```text
rôle redis présent
rôle celery présent
config/celery.py présent
tasks_demo/tasks.py présent
Redis localhost-only
pas de 0.0.0.0:6379
service Celery basé sur .venv
pas de secrets Redis suivis par Git
syntax-check Ansible
syntaxe Bash
syntaxe Python
syntaxe YAML
```

Elle ne devra pas considérer un service Redis/Celery comme runtime-validé : les static checks restent une barrière de structure et de configuration.

---

## 19. Packaging

Le mécanisme existant de packaging sécurisé sera conservé et étendu.

Le package final devra inclure :

```text
rôle redis
rôle celery
configuration Celery Django
tâches de test
playbooks
scripts
static checks
qualification docs
evidence CI pertinente
```

Et continuer à exclure :

```text
vault.yml réel
.vault_pass
inventaire runtime réel
host vars réelles
*.pem
*.key
credentials
archives précédentes
```

Un `package_safety_check.sh` devra également détecter des traces de secrets Redis si nécessaire.

---

## 20. Lots d’implémentation

### RC-00 — Fork contrôlé de la baseline

- créer le dossier `django-postgresql-redis-celery/` ;
- copier la baseline qualifiée ;
- réinitialiser les preuves runtime ;
- adapter README et noms ;
- statut : non qualifié.

### RC-01 — Architecture et contrats

- `ARCHITECTURE.md` ;
- variables Redis/Celery ;
- contrats réseau ;
- inventaire mono-host ;
- stratégie Vault.

### RC-02 — Dépendances Python

- ajouter `celery` ;
- ajouter client `redis` ;
- conserver `.venv` ;
- tests de chargement Django.

### RC-03 — Intégration Celery Django

- `config/celery.py` ;
- initialisation Celery ;
- settings broker/result backend ;
- variables d’environnement.

### RC-04 — Tâches et API de démonstration

- `add` ;
- `uppercase` ;
- `database_probe` ;
- submit endpoint ;
- status endpoint ;
- tests applicatifs.

### RC-05 — Rôle Ansible Redis

- installation ;
- localhost-only ;
- auth ;
- systemd ;
- PING ;
- handlers ;
- documentation.

### RC-06 — Rôle Ansible Celery

- service systemd ;
- `.venv` ;
- env file ;
- worker ;
- handlers ;
- documentation.

### RC-07 — Orchestration

Faire évoluer :

```text
common → postgresql → redis → django_app → celery → nginx
```

### RC-08 — Runtime validation

Étendre `validate.yml` aux services Redis/Celery et aux endpoints correspondants.

### RC-09 — Static gate

Étendre la suite statique avec les nouveaux invariants.

### RC-10 — Première qualification E2E

Premier vrai run mono-host Redis/Celery.

### RC-11 — Idempotence stricte

Deuxième `site.yml` avec :

```text
server1 changed=0
```

### RC-12 — Packaging et artifact

- ZIP ;
- SHA-256 ;
- package safety ;
- GitHub Actions artifact.

### RC-13 — Rapport final

Créer le rapport de qualification spécifique Redis/Celery avec preuves réelles.

---

## 21. Definition of Done

La variante ne sera considérée terminée que lorsque tous les critères suivants seront prouvés :

```text
[ ] copie indépendante du projet source
[ ] Redis installé et actif
[ ] Redis uniquement sur 127.0.0.1:6379
[ ] Celery worker actif sous systemd
[ ] Celery utilise le .venv Django
[ ] Django peut publier une tâche
[ ] Redis transporte la tâche
[ ] Celery exécute add(21,21)
[ ] résultat réel = 42
[ ] Celery database_probe atteint PostgreSQL
[ ] PostgreSQL retourne SELECT 1
[ ] /health/ GREEN
[ ] /health/database/ GREEN
[ ] /health/redis/ GREEN
[ ] services runtime GREEN
[ ] :80 exposé
[ ] :8000 non exposé
[ ] :5432 non exposé
[ ] :6379 non exposé
[ ] aucun secret dans Git
[ ] second site.yml → server1 changed=0
[ ] package ZIP produit
[ ] SHA-256 vérifié
[ ] package safety PASS
[ ] artifact GitHub Actions produit
[ ] rapport E2E final rédigé
```

---

## 22. Non-objectifs de cette première version

Ne sont pas nécessaires pour la première qualification :

```text
Celery Beat
Flower
Redis Sentinel
Redis Cluster
RabbitMQ
multi-worker autoscaling
HA PostgreSQL
HA Redis
Kubernetes
TLS Redis
monitoring Prometheus dédié Celery
```

Ces sujets pourront former une version suivante une fois la chaîne de base correctement qualifiée.

Celery Beat ne devra être ajouté que si un vrai besoin de tâches périodiques apparaît ; il ne doit pas être introduit uniquement pour complexifier le laboratoire.

---

## 23. Principes de conception à préserver

1. **Ne pas modifier la baseline qualifiée `django-postgresql`.**
2. **Redis et Celery restent deux rôles Ansible distincts.**
3. **Redis, PostgreSQL et Gunicorn restent localhost-only.**
4. **Les secrets restent dans Ansible Vault.**
5. **Celery utilise le même code Django et le même `.venv`.**
6. **Un service actif n’est pas une preuve suffisante : les tâches doivent réellement s’exécuter.**
7. **Le round-trip Celery et l’accès DB depuis le worker sont obligatoires en E2E.**
8. **La deuxième exécution Ansible doit rester `changed=0`.**
9. **Aucun résultat runtime ne sera documenté avant observation réelle.**
10. **La qualification CI/container sera clairement distinguée d’une future qualification VPS/SSH.**

---

## 24. Prochaine action

Une fois ce plan validé, la première implémentation sera **RC-00 — Fork contrôlé de la baseline** :

```text
django-postgresql/
        ↓ copie contrôlée

django-postgresql-redis-celery/
```

Le premier commit d’implémentation devra uniquement créer une copie propre et cohérente, remettre le statut de qualification à zéro pour la nouvelle variante, réinitialiser `evidence/`, et préparer la structure avant tout ajout Redis/Celery.
