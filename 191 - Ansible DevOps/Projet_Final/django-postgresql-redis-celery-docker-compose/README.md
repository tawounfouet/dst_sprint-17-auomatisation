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
12-FACTOR DOCKER IMAGE          ⏳
DOCKER COMPOSE                  ⏳
ANSIBLE DOCKER ENGINE           ⏳
ANSIBLE COMPOSE DEPLOY          ⏳
SECRETS / ENV INJECTION         ⏳
HEALTHCHECKS / PERSISTENCE      ⏳
STATIC GATE                     ⏳
COMPOSE E2E                     ⏳
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

## Configuration Django

La configuration est structurée ainsi :

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

L'API asynchrone utilise maintenant réellement DRF :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

Composants principaux :

```text
tasks_demo/serializers.py
├── AddTaskSerializer
├── UppercaseTaskSerializer
├── TaskAcceptedSerializer
└── TaskStatusSerializer

tasks_demo/views.py
└── @api_view + Response
```

Les contrats existants sont conservés : validations strictes, HTTP 202 pour les soumissions, `invalid_json`, erreurs métier stables et absence de fuite d'exception Celery.

DEV active le `BrowsableAPIRenderer`; STG/PROD restent JSON-only.

## Architecture cible

```text
                    Nginx :80/:443
                         │
                         ▼
                 web — Django/DRF
                    Gunicorn :8000
                     ┌────┴────┐
                     ▼         ▼
                    db       redis
               PostgreSQL   Redis + auth
                     ▲         ▲
                     │         │
                   worker     beat
                   Celery   Celery Beat
```

Les services Compose cibles sont :

```text
nginx
web
db
redis
worker
beat
```

`web`, `worker` et `beat` utiliseront la même image applicative.

## Contrat réseau cible

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
80/443 published=true
8000   published=false
5432   published=false
6379   published=false
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
DC-04  12-Factor Docker image                                     ⏭ NEXT
DC-05  Base Docker Compose stack                                  ⏳
DC-06  Multi-environment Compose                                  ⏳
DC-07  Ansible docker_engine                                      ⏳
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

Le plan canonique complet est `DOCKER_COMPOSE_IMPLEMENTATION_PLAN.md`. Les jalons courants sont documentés dans `DC_02_DJANGO_CONFIGURATION_FOUNDATION.md` et `DC_03_DJANGO_REST_FRAMEWORK.md`.
