# Projet Ansible — Django + PostgreSQL + Redis + Celery

Variante dérivée du projet `django-postgresql/` afin d'ajouter Redis et Celery sur une topologie mono-serveur Ubuntu 24.04.

## Statut

```text
BASELINE COPIED          ✅
ARCHITECTURE / CONTRACTS ✅
PYTHON DEPENDENCIES      ✅
DJANGO / CELERY CONFIG   ✅
ASYNC TASK API           ✅ IMPLEMENTED
REDIS ROLE               ✅ IMPLEMENTED
CELERY WORKER            ⏳
E2E QUALIFICATION        ⏳
IDEMPOTENCE              ⏳
PACKAGE / ARTIFACT       ⏳
```

> Important : la qualification GREEN du projet source n'est pas héritée. Cette variante devra produire sa propre qualification E2E avant d'être considérée qualifiée.

## Baseline source

```text
Source dossier : 191 - Ansible DevOps/Projet_Final/django-postgresql/
Source snapshot : 22feae813b4e85df891304b596cfb07b8940081b
Branche         : feat/ansible-django-postgresql-project
```

## Architecture cible

```text
Nginx :80
   ↓
Gunicorn 127.0.0.1:8000
   ↓
Django
   ├── PostgreSQL 127.0.0.1:5432
   └── Redis      127.0.0.1:6379
                       ↓
                  Celery Worker
```

Le contrat réseau est :

```text
80    → exposé
8000  → localhost-only
5432  → localhost-only
6379  → localhost-only
```

Redis est prévu comme broker Celery (`/0`) et result backend (`/1`) avec mot de passe fourni par Ansible Vault.

## Dépendances Python

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
```

Le runtime conserve Python standard `venv` sous `.venv` ; aucune dépendance `virtualenv` n'est introduite.

## Intégration Celery Django

`django-app/config/celery.py` initialise Celery et `config/__init__.py` expose l'application. Django charge `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND` et `CELERY_RESULT_EXPIRES` avec sérialisation JSON et timezone alignée sur Django.

## API de tâches

L'application `tasks_demo` fournit :

```text
add(21, 21)                → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe()           → PostgreSQL → SELECT 1
```

Endpoints :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

## Rôle Redis — RC-05

Le nouveau rôle `roles/redis/` implémente :

```text
redis-server + redis-tools
bind 127.0.0.1
protected-mode yes
port 6379
supervised systemd
requirepass via Vault
service enabled/started
PING authentifié → PONG
```

Le secret est transmis à `redis-cli` via `REDISCLI_AUTH` et les tâches qui manipulent le mot de passe utilisent `no_log: true`.

Le rôle est implémenté mais ne sera réellement exécuté par `site.yml` qu'au jalon d'orchestration ; sa preuve runtime complète viendra avec RC-07/RC-08 puis la qualification E2E.

## À propos de Django Celery Beat

`django-celery-beat` **n'est pas encore intégré** dans cette variante. La configuration actuelle couvre l'application Celery, le futur worker, Redis broker/result backend et l'API de tâches, mais pas encore un scheduler de tâches périodiques persistant en base Django.

Une extension dédiée pourra être ajoutée après le worker Celery afin de gérer proprement `django-celery-beat`, ses migrations et un service systemd `celery-beat`.

## Rôles cibles

```text
common
postgresql
redis
django_app
celery
nginx
```

Ordre prévu :

```text
common → postgresql → redis → django_app → celery → nginx
```

## Documentation

```text
IMPLEMENTATION_PLAN.md
ARCHITECTURE.md
RC_00_BASELINE_COPY.md
RC_01_ARCHITECTURE_AND_CONTRACTS.md
RC_02_PYTHON_DEPENDENCIES.md
RC_03_DJANGO_CELERY_INTEGRATION.md
RC_04_ASYNC_TASK_API.md
RC_05_REDIS_ROLE.md
```

Étapes réalisées :

```text
RC-00  Fork contrôlé de la baseline       ✅
RC-01  Architecture et contrats           ✅
RC-02  Dépendances Python                 ✅
RC-03  Intégration Celery dans Django     ✅
RC-04  Tâches + API asynchrone            ✅
RC-05  rôle Ansible Redis                 ✅ IMPLEMENTED
```

Le prochain jalon est **RC-06 — rôle Ansible Celery Worker**.
