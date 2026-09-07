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
RUNTIME VALIDATION       ✅ IMPLEMENTED
STATIC GATE              ⏳
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

Le `site.yml` orchestre les sept rôles :

```text
common → postgresql → redis → django_app → celery → celery_beat → nginx
```

La topologie canonique est mono-host : le même `server1` appartient aux groupes `app` et `database`.

## Runtime validation — RC-08

Le contrat de validation couvre désormais les services :

```text
postgresql
redis-server
datascientest-django
datascientest-celery
datascientest-celery-beat
nginx
```

et ne s'arrête pas à `systemctl is-active`.

Les contrôles prévus incluent :

```text
PostgreSQL 127.0.0.1:5432 + DB/role
Redis 127.0.0.1:6379 + PING authentifié → PONG
Gunicorn 127.0.0.1:8000
nginx -t + HTTP :80
GET /health/
GET /health/database/   → SELECT 1
GET /health/redis/      → Redis PING réel
GET /health/celery/     → Celery control ping avec >= 1 worker
```

Deux vrais scénarios asynchrones sont définis dans `validate.yml` :

```text
POST /api/tasks/add/ {21,21}
→ Redis broker
→ Celery Worker
→ Redis result backend
→ SUCCESS / 42
```

et :

```text
POST /api/tasks/database-probe/
→ Redis
→ Celery Worker
→ Django
→ PostgreSQL
→ SELECT 1
→ SUCCESS
```

La validation attend aussi que `django-celery-beat` ait réellement déclenché la tâche `datascientest-demo-heartbeat` au moins une fois via :

```text
total_run_count >= 1
```

> RC-08 est implémenté mais pas encore qualifié sur le nouveau harness GitHub Actions. Aucun statut GREEN runtime n'est revendiqué à ce stade.

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

Endpoints :

```text
GET  /health/redis/
GET  /health/celery/
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
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
RC-08   runtime validation                 ✅ IMPLEMENTED
RC-09   static gate                        ⏭ NEXT
RC-10   qualification E2E                  ⏳
RC-11   idempotence                        ⏳
RC-12   packaging + artifact               ⏳
RC-13   rapport final                      ⏳
```

## Documentation

Les jalons sont décrits dans `IMPLEMENTATION_PLAN.md`, `ARCHITECTURE.md` et les fichiers `RC_*.md` du dossier.
