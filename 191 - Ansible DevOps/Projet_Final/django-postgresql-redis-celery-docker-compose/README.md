# Projet Ansible — Django/DRF + PostgreSQL + Redis + Celery + Docker Compose

Variante dérivée du projet qualifié `django-postgresql-redis-celery/` afin de migrer l'exécution vers **Docker Engine + Docker Compose**, tout en conservant **Ansible comme plan de contrôle**.

## Source de la copie

```text
source folder : 191 - Ansible DevOps/Projet_Final/django-postgresql-redis-celery/
source branch : feat/ansible-django-postgresql-redis-celery
source HEAD   : 0b33d1ea230b47492720127b2dcf837899da851d
```

Les preuves RC-10 à RC-13 de la baseline restent historiques uniquement et ne qualifient pas cette variante Docker Compose.

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
ANSIBLE DOCKER ENGINE           ⏳
ANSIBLE COMPOSE DEPLOY          ⏳
SECRETS / ENV INJECTION         ⏳
HEALTHCHECKS / PERSISTENCE      🟡 BASE IMPLEMENTED
STATIC GATE                     ⏳
COMPOSE E2E                     ⏳
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Aucun statut runtime GREEN n'est hérité ou revendiqué tant que les futurs gates Docker/Compose/CI n'ont pas été réellement exécutés.

## Configuration Django

```text
django-app/config/settings/
├── __init__.py
├── base.py
├── database.py
├── dev.py
├── stg.py
└── prod.py
```

Sélection explicite :

```text
DJANGO_SETTINGS_MODULE=config.settings.dev
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_SETTINGS_MODULE=config.settings.prod
```

`django-environ` lit et caste la configuration. Ansible Vault restera la source des secrets pour les environnements gérés.

## Politique base de données

```text
DEV + DATABASE_URL absente      → SQLite ✅
DEV + PostgreSQL URL            → PostgreSQL ✅
DEV + SQLite URL explicite      → FAIL ❌
STG + DATABASE_URL absente      → FAIL ❌
STG + SQLite                    → FAIL ❌
PROD + DATABASE_URL absente     → FAIL ❌
PROD + SQLite                   → FAIL ❌
STG/PROD + PostgreSQL           → PostgreSQL ✅
```

Aucun fallback sur erreur de connexion PostgreSQL n'est autorisé.

Deux modes DEV sont prévus :

```text
DEV Lite  → Django local + SQLite
DEV Full  → Docker Compose + PostgreSQL + Redis + Celery + Beat + Nginx
```

## Django REST Framework

L'API asynchrone utilise réellement DRF :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

Les serializers conservent les validations métier historiques, les soumissions retournent HTTP 202 et les échecs Celery n'exposent pas les exceptions backend.

## Image applicative 12-Factor

```text
django-app/
├── Dockerfile
├── .dockerignore
└── docker/
    ├── entrypoint.sh
    └── gunicorn.conf.py
```

Le Dockerfile est multi-stage, installe les dépendances au build et exécute le runtime avec l'utilisateur non-root `app` UID/GID `10001`.

Une seule image est destinée aux trois process types :

```text
             APP IMAGE
           /     |     \
        web    worker   beat
     Gunicorn  Celery  Celery Beat
```

Les logs sont dirigés vers stdout/stderr, `SIGTERM` est le signal d'arrêt et les migrations/`collectstatic` restent des admin one-shot processes.

## Docker Compose multi-environnement

La stack est désormais structurée ainsi :

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
└── compose.prod.yml
```

`compose.yml` contient uniquement la topologie commune :

```text
nginx
web
db
redis
worker
beat
```

Il ne publie plus de port hôte et ne construit plus l'image applicative. Les overlays portent la politique de release.

### DEV Full

```text
compose.yml + compose.dev.yml
```

Contrat :

```text
APPLICATION_ENV=dev
DJANGO_SETTINGS_MODULE=config.settings.dev
DATABASE_URL obligatoire
PostgreSQL obligatoire
build local de l'image commune web/worker/beat
Nginx → 127.0.0.1:8080 par défaut
```

SQLite reste réservé au DEV Lite hors Compose.

### STG

```text
compose.yml + compose.stg.yml
```

Contrat :

```text
APPLICATION_ENV=stg
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_DEBUG=false
APP_IMAGE obligatoire
aucun build applicatif
aucun bind mount code
PostgreSQL strict
```

### PROD

```text
compose.yml + compose.prod.yml
```

Contrat :

```text
APPLICATION_ENV=prod
DJANGO_SETTINGS_MODULE=config.settings.prod
DJANGO_DEBUG=false
APP_IMAGE obligatoire
aucun build applicatif
aucun bind mount code
PostgreSQL strict
```

La cible de promotion est :

```text
CI build
   ↓
APP_IMAGE=registry/...@sha256:ABC
   ↓
STG qualifie sha256:ABC
   ↓
PROD réutilise sha256:ABC
```

La vérification stricte du format `@sha256:` sera ajoutée côté Ansible/static gate.

## Persistance et healthchecks

Volumes :

```text
postgres_data
redis_data
static_data
```

Healthchecks de base :

```text
db     → pg_isready
redis  → PING authentifié
web    → GET /health/
worker → celery inspect ping
beat   → process Celery Beat PID 1
nginx  → GET /health/ via proxy
```

La preuve fonctionnelle forte de Beat restera une exécution périodique réellement observée en E2E.

## Contrat réseau cible

Service discovery :

```text
nginx  → web:8000
web    → db:5432
web    → redis:6379
worker → db:5432
worker → redis:6379
beat   → db:5432
beat   → redis:6379
```

Côté hôte :

```text
DEV Full : Nginx uniquement, 127.0.0.1:8080 par défaut
STG/PROD: Nginx uniquement, :80 par défaut

8000    published=false
5432    published=false
6379    published=false
```

## Ansible reste le plan de contrôle

La cible active deviendra :

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

Les anciens rôles systemd restent dans la copie comme référence de migration mais ne devront pas être exécutés en parallèle avec la stack Compose finale.

## Roadmap canonique

```text
DC-00  Controlled baseline copy                                  ✅
DC-01  Docker/Compose architecture contracts                      ✅ DESIGN
DC-02  Django configuration foundation                            ✅ IMPLEMENTED
DC-03  Django REST Framework                                      ✅ IMPLEMENTED
DC-04  12-Factor Docker image                                     ✅ IMPLEMENTED
DC-05  Base Docker Compose stack                                  ✅ IMPLEMENTED
DC-06  Multi-environment Compose                                  ✅ IMPLEMENTED
DC-07  Ansible docker_engine                                      ⏭ NEXT
DC-08  Ansible compose_stack + inventories dev/stg/prod           ⏳
DC-09  Secure runtime configuration                               ⏳
DC-10  Runtime hardening                                          ⏳
DC-11  Unit tests + static gate                                   ⏳
DC-12  DEV Full E2E                                               ⏳
DC-13  STG-like E2E + anti-SQLite tests                           ⏳
DC-14  Strict idempotence                                         ⏳
DC-15  Package + SHA-256 + artifact                               ⏳
DC-16  Final qualification report + 12-Factor matrix              ⏳
```

Le plan canonique complet est `DOCKER_COMPOSE_IMPLEMENTATION_PLAN.md`. Les jalons réalisés sont documentés dans les fichiers `DC_*.md` correspondants.
