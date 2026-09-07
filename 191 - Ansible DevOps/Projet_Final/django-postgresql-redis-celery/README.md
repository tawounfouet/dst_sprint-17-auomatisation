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
GLOBAL ORCHESTRATION     ✅ IMPLEMENTED
RUNTIME VALIDATION       ⏳
E2E QUALIFICATION        ⏳
IDEMPOTENCE              ⏳
PACKAGE / ARTIFACT       ⏳
```

> La qualification GREEN du projet source n'est pas héritée. Cette variante devra produire son propre run E2E GREEN.

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

## Orchestration — RC-07

Le `site.yml` orchestre désormais réellement les sept rôles dans cet ordre :

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
celery_beat
  ↓
nginx
```

La topologie prod d'exemple est désormais explicitement mono-host : le même `server1` appartient aux groupes `app` et `database`, et `site.yml` refuse une topologie où les deux groupes pointent vers des hôtes différents.

Les overrides mono-host imposent :

```text
PostgreSQL → 127.0.0.1:5432
Redis      → 127.0.0.1:6379
Gunicorn   → 127.0.0.1:8000
```

Les trois secrets attendus restent fournis par Ansible Vault :

```text
vault_postgresql_password
vault_django_secret_key
vault_redis_password
```

## Composants applicatifs

Dépendances Python :

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
django-celery-beat>=2.9,<3
```

Tâches de démonstration :

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

Services systemd cibles :

```text
postgresql
redis-server
datascientest-django
datascientest-celery
datascientest-celery-beat
nginx
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
RC-07   orchestration globale              ✅ IMPLEMENTED
RC-08   runtime validation                 ⏭ NEXT
RC-09   static gate                        ⏳
RC-10   qualification E2E                  ⏳
RC-11   idempotence                        ⏳
RC-12   packaging + artifact               ⏳
RC-13   rapport final                      ⏳
```

## Documentation

Les jalons sont décrits dans `IMPLEMENTATION_PLAN.md`, `ARCHITECTURE.md` et les fichiers `RC_*.md` du dossier.
