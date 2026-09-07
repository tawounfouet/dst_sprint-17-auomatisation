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
ANSIBLE DOCKER ENGINE           ✅ IMPLEMENTED
ANSIBLE COMPOSE DEPLOY          ⏳
SECRETS / ENV INJECTION         ⏳
HEALTHCHECKS / PERSISTENCE      🟡 BASE IMPLEMENTED
STATIC GATE                     ⏳
COMPOSE E2E                     ⏳
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Aucun statut runtime GREEN n'est revendiqué tant que les futurs gates Ansible/Docker/Compose/CI n'ont pas été réellement exécutés.

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

Sélection :

```text
DJANGO_SETTINGS_MODULE=config.settings.dev
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_SETTINGS_MODULE=config.settings.prod
```

`django-environ` lit et caste la configuration. Ansible Vault restera la source des secrets pour les environnements gérés.

Politique base de données :

```text
DEV + DATABASE_URL absente      → SQLite ✅
DEV + PostgreSQL URL            → PostgreSQL ✅
DEV + SQLite URL explicite      → FAIL ❌
STG/PROD + DATABASE_URL absente → FAIL ❌
STG/PROD + SQLite               → FAIL ❌
STG/PROD + PostgreSQL           → PostgreSQL ✅
```

Aucun fallback sur erreur de connexion PostgreSQL n'est autorisé.

## Django REST Framework

Endpoints asynchrones :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

Les serializers DRF conservent les validations métier historiques, HTTP 202 pour les soumissions et aucune fuite d'exception Celery.

## Image applicative 12-Factor

```text
django-app/
├── Dockerfile
├── .dockerignore
└── docker/
    ├── entrypoint.sh
    └── gunicorn.conf.py
```

Une seule image non-root alimente :

```text
             APP_IMAGE
           /     |     \
        web    worker   beat
     Gunicorn  Celery  Celery Beat
```

Les dépendances sont installées au build, les logs vont vers stdout/stderr, `SIGTERM` est propagé au process PID 1 et les migrations/`collectstatic` restent des admin one-shot processes.

## Docker Compose multi-environnement

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
└── compose.prod.yml
```

Topologie commune :

```text
nginx
  ↓
web
 ├── db
 └── redis
      ↑
 worker / beat
```

DEV Full construit localement l'image et exige PostgreSQL. STG/PROD exigent `APP_IMAGE`, ne buildent pas depuis le serveur et n'utilisent aucun bind mount du code.

Promotion cible :

```text
CI build
   ↓
APP_IMAGE=registry/...@sha256:ABC
   ↓
STG qualifie sha256:ABC
   ↓
PROD réutilise sha256:ABC
```

## Ansible Docker Engine — DC-07

Le nouveau rôle actif est :

```text
ansible-project/roles/docker_engine/
├── README.md
├── defaults/main.yml
├── tasks/main.yml
└── meta/main.yml
```

Playbook autonome :

```text
ansible-project/playbooks/docker_engine.yml
```

Le rôle cible Ubuntu 24.04/Noble et installe Docker depuis le dépôt APT officiel :

```text
/etc/apt/keyrings/docker.asc
/etc/apt/sources.list.d/docker.sources

docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

Le service `docker` est configuré `started + enabled` puis le rôle valide :

```text
docker info
docker compose version
docker buildx version
```

Aucun utilisateur n'est ajouté automatiquement au groupe `docker` et aucun conteneur applicatif n'est encore déployé par DC-07.

Les anciens rôles systemd `postgresql`, `redis`, `django_app`, `celery`, `celery_beat`, `nginx` restent temporairement présents comme référence de migration mais ne seront pas utilisés dans l'orchestration Compose finale.

## Persistance et healthchecks Compose

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

La preuve forte de Beat restera une tâche périodique réellement observée en E2E.

## Contrat réseau cible

```text
DEV Full : Nginx uniquement, 127.0.0.1:8080 par défaut
STG/PROD: Nginx uniquement, :80 par défaut

8000    published=false
5432    published=false
6379    published=false
```

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

## Cible Ansible finale

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

## Roadmap canonique

```text
DC-00  Controlled baseline copy                                  ✅
DC-01  Docker/Compose architecture contracts                      ✅ DESIGN
DC-02  Django configuration foundation                            ✅ IMPLEMENTED
DC-03  Django REST Framework                                      ✅ IMPLEMENTED
DC-04  12-Factor Docker image                                     ✅ IMPLEMENTED
DC-05  Base Docker Compose stack                                  ✅ IMPLEMENTED
DC-06  Multi-environment Compose                                  ✅ IMPLEMENTED
DC-07  Ansible docker_engine                                      ✅ IMPLEMENTED
DC-08  Ansible compose_stack + inventories dev/stg/prod           ⏭ NEXT
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
