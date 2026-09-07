# Projet Ansible — Django + PostgreSQL + Redis + Celery + Beat

Variante dérivée du projet `django-postgresql/` afin d'ajouter Redis, un worker Celery et `django-celery-beat` sur une topologie mono-serveur Ubuntu 24.04.

## Statut

```text
BASELINE COPIED          ✅
ARCHITECTURE / CONTRACTS ✅
PYTHON DEPENDENCIES      ✅
DJANGO / CELERY CONFIG   ✅
ASYNC TASK API           ✅ IMPLEMENTED
REDIS ROLE               ✅ IMPLEMENTED
CELERY WORKER            ✅ IMPLEMENTED
DJANGO CELERY BEAT       ✅ IMPLEMENTED
GLOBAL ORCHESTRATION     ⏳
RUNTIME VALIDATION       ⏳
E2E QUALIFICATION        ⏳
IDEMPOTENCE              ⏳
PACKAGE / ARTIFACT       ⏳
```

> La qualification GREEN du projet source n'est pas héritée. Cette variante devra produire son propre run E2E GREEN.

## Baseline

```text
Source dossier : 191 - Ansible DevOps/Projet_Final/django-postgresql/
Source snapshot : 22feae813b4e85df891304b596cfb07b8940081b
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
          ▲              ▲
          │              │
   Celery Worker   Celery Beat
                         │
                         └── DatabaseScheduler
                              ↓
                           PostgreSQL
```

Contrat réseau :

```text
80    → exposé via Nginx
8000  → localhost-only
5432  → localhost-only
6379  → localhost-only
```

## Dépendances Python

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
django-celery-beat>=2.9,<3
```

Le runtime conserve Python standard `venv` sous `.venv`.

## Tâches de démonstration

```text
add(21, 21)                 → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe()            → PostgreSQL → SELECT 1
periodic_heartbeat()        → heartbeat horodaté via Celery Beat
```

API immédiate :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

## Redis — RC-05

Le rôle `redis` installe et configure `redis-server` en localhost-only avec `protected-mode yes`, authentification Vault et validation `PING → PONG`.

## Celery Worker — RC-06

Le rôle `celery` installe une unité systemd séparée :

```text
datascientest-celery.service
```

Le worker charge le même `EnvironmentFile` que Django et exécute :

```text
celery -A config worker --loglevel=INFO --concurrency=2
```

Il est redémarré lorsque le code Django, les dépendances, l'environnement ou l'unité systemd changent.

## Django Celery Beat — RC-06B

`django-celery-beat` est maintenant intégré avec :

```text
INSTALLED_APPS += django_celery_beat
CELERY_BEAT_SCHEDULER = django_celery_beat.schedulers:DatabaseScheduler
```

Le rôle `celery_beat` installe :

```text
datascientest-celery-beat.service
```

Un management command idempotent enregistre la tâche périodique de laboratoire :

```text
python manage.py ensure_demo_periodic_task --seconds 30
```

nommée `datascientest-demo-heartbeat` et pointant vers `tasks_demo.periodic_heartbeat`.

Le worker et Beat restent deux services distincts ; le projet n'utilise pas `celery worker -B`.

## Rôles

```text
common
postgresql
redis
django_app
celery
celery_beat
nginx
```

Ordre cible :

```text
common → postgresql → redis → django_app → celery → celery_beat → nginx
```

## Roadmap

```text
RC-00   Fork contrôlé de la baseline       ✅
RC-01   Architecture et contrats           ✅
RC-02   Dépendances Python                 ✅
RC-03   Intégration Celery dans Django     ✅
RC-04   Tâches + API asynchrone            ✅
RC-05   rôle Redis                         ✅ IMPLEMENTED
RC-06   rôle Celery Worker                 ✅ IMPLEMENTED
RC-06B  Django Celery Beat                 ✅ IMPLEMENTED
RC-07   orchestration globale              ⏭ NEXT
RC-08   runtime validation                 ⏳
RC-09   static gate                        ⏳
RC-10   qualification E2E                  ⏳
RC-11   idempotence                        ⏳
RC-12   packaging + artifact               ⏳
RC-13   rapport final                      ⏳
```

## Documentation

Les jalons sont décrits dans `IMPLEMENTATION_PLAN.md`, `ARCHITECTURE.md` et les fichiers `RC_*.md` du dossier.
