# Projet Ansible — Django/DRF + PostgreSQL + Redis + Celery + Docker Compose

Variante dérivée du projet qualifié `django-postgresql-redis-celery/` pour migrer l'exécution vers **Docker Engine + Docker Compose**, avec **Ansible comme plan de contrôle**.

## Statut

```text
BASELINE COPIED                 ✅
TARGET ARCHITECTURE             ✅ DESIGN
DJANGO CONFIG FOUNDATION        ✅ IMPLEMENTED
DJANGO-ENVIRON                  ✅ IMPLEMENTED
MULTI-ENV DEV/STG/PROD          ✅ IMPLEMENTED
SQLITE DEV-ONLY POLICY          ✅ IMPLEMENTED
DJANGO REST FRAMEWORK           ✅ IMPLEMENTED
12-FACTOR DOCKER IMAGE          ✅ IMPLEMENTED
BASE DOCKER COMPOSE STACK       ✅ IMPLEMENTED
MULTI-ENV COMPOSE               ✅ IMPLEMENTED
ANSIBLE DOCKER ENGINE           ✅ IMPLEMENTED
ANSIBLE COMPOSE DEPLOY          ✅ IMPLEMENTED
INVENTORIES DEV/STG/PROD        ✅ IMPLEMENTED
SECURE RUNTIME CONFIGURATION    ✅ IMPLEMENTED
RUNTIME HARDENING               ⏳
STATIC GATE                     ⏳
COMPOSE E2E                     ⏳
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Aucun statut runtime GREEN n'est revendiqué tant que les futurs gates Ansible/Docker/Compose/CI n'ont pas été réellement exécutés.

## Django / DRF / configuration

```text
django-app/config/settings/
├── base.py
├── database.py
├── dev.py
├── stg.py
└── prod.py
```

Politique DB :

```text
DEV Lite + DATABASE_URL absente → SQLite autorisé
DEV Full Compose                → PostgreSQL obligatoire
STG/PROD                        → PostgreSQL obligatoire, SQLite interdit
```

Django utilise `django-environ`. En STG/PROD, `SECRET_KEY` doit désormais être une valeur non-placeholder d'au moins 50 caractères et les URLs Celery doivent utiliser Redis.

## Image 12-Factor

Une seule image applicative non-root sert à :

```text
             APP_IMAGE
           /     |     \
        web    worker   beat
     Gunicorn  Celery  Celery Beat
```

Dépendances au build, logs stdout/stderr, SIGTERM, pas de migration automatique au boot.

## Docker Compose multi-environnement

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
└── compose.prod.yml
```

Services : `nginx`, `web`, `db`, `redis`, `worker`, `beat`.

DEV Full construit localement l'image commune. STG/PROD exigent une `APP_IMAGE` déjà construite et référencée par digest.

## Orchestration Ansible active

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

Les anciens rôles natifs `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx` restent comme référence historique mais ne sont plus appelés par `playbooks/site.yml`.

## Secure Runtime Configuration — DC-09

Le chemin de configuration est maintenant :

```text
Vault DEV/STG/PROD
       ↓
validation environment + génération + qualité
       ↓
urlencode des credentials dérivés
       ↓
compose_stack_runtime_environment
       ↓
.env.runtime root:root 0600
       ↓
Docker Compose
```

Chaque Vault réel doit être lié à son environnement avec :

```text
vault_environment
vault_secret_generation
vault_django_secret_key
vault_postgresql_password
vault_redis_password
```

Le preflight refuse : mauvais environnement, génération absente, secrets trop courts, placeholders ou réutilisation de la même valeur entre Django/PostgreSQL/Redis.

Le rôle `compose_stack` vérifie aussi les URLs :

```text
DATABASE_URL          → postgresql://...@db:5432/...
CELERY_BROKER_URL     → redis://...@redis:6379/...
CELERY_RESULT_BACKEND → redis://...@redis:6379/...
SQLite Compose        → interdit
```

Le seul fichier runtime attendu est :

```text
/opt/datascientest-compose/docker/.env.runtime
owner=root group=root mode=0600
```

Les anciens `.env`, `.env.dev`, `.env.stg`, `.env.prod` distants sont supprimés avant rendu. Les tâches sensibles utilisent `no_log: true`.

## Anti-secret hygiene

Le scanner :

```text
ansible-project/scripts/secret_hygiene.py
```

supporte :

```text
repo     → Git tracked files
tree     → logs / fichiers / répertoires
archive  → ZIP
```

`preflight.sh` l'exécute sur le repository, `deploy.sh`/`validate_runtime.sh` sur leurs logs et `package.sh` avant puis après création du ZIP. Un fichier local `SECRET_VALUES_FILE` permet plus tard de rechercher exactement des valeurs canaris sans les afficher.

La politique de rotation est dans :

```text
SECURITY_SECRET_ROTATION_POLICY.md
```

Les secrets ne sont jamais promus entre environnements ; seule l'image Docker l'est. La rotation PostgreSQL nécessite une opération SQL coordonnée sur une base déjà initialisée : changer `POSTGRES_PASSWORD` seul ne suffit pas.

## Contrat réseau cible

```text
DEV Full : Nginx seulement sur 127.0.0.1:8080 par défaut
STG/PROD: Nginx seulement sur :80 par défaut

8000 Gunicorn   published=false
5432 PostgreSQL published=false
6379 Redis      published=false
```

## Roadmap

```text
DC-00  Controlled baseline copy                                  ✅
DC-01  Docker/Compose architecture contracts                      ✅ DESIGN
DC-02  Django configuration foundation                            ✅ IMPLEMENTED
DC-03  Django REST Framework                                      ✅ IMPLEMENTED
DC-04  12-Factor Docker image                                     ✅ IMPLEMENTED
DC-05  Base Docker Compose stack                                  ✅ IMPLEMENTED
DC-06  Multi-environment Compose                                  ✅ IMPLEMENTED
DC-07  Ansible docker_engine                                      ✅ IMPLEMENTED
DC-08  Ansible compose_stack + inventories dev/stg/prod           ✅ IMPLEMENTED
DC-09  Secure runtime configuration                               ✅ IMPLEMENTED
DC-10  Runtime hardening                                          ⏭ NEXT
DC-11  Unit tests + static gate                                   ⏳
DC-12  DEV Full E2E                                               ⏳
DC-13  STG-like E2E + anti-SQLite tests                           ⏳
DC-14  Strict idempotence                                         ⏳
DC-15  Package + SHA-256 + artifact                               ⏳
DC-16  Final qualification report + 12-Factor matrix              ⏳
```

Les preuves historiques de la baseline native ne qualifient pas cette variante Docker Compose.
