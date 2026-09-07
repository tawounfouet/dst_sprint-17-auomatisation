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
STATIC GATE              ✅ IMPLEMENTED
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

## Orchestration

Le `site.yml` orchestre les sept rôles :

```text
common → postgresql → redis → django_app → celery → celery_beat → nginx
```

La topologie canonique est mono-host : le même `server1` appartient aux groupes `app` et `database`.

## Runtime validation — RC-08

Le contrat de validation couvre :

```text
PostgreSQL service + DB + role
Redis service + PING authentifié
Gunicorn
Celery Worker + control ping
Celery Beat + PeriodicTask réellement déclenchée
Nginx + nginx -t
GET /health/
GET /health/database/
GET /health/redis/
GET /health/celery/
add(21,21) → 42
database_probe() → SELECT 1
```

RC-08 reste un contrat implémenté ; sa preuve runtime réelle sera produite par GitHub Actions.

## Static gate — RC-09

`ansible-project/tests/static_checks.sh` contrôle désormais :

```text
structure des 7 rôles
scaffold Django/Celery/Beat
dépendances Python
syntaxe Bash / Python / YAML
inventaire mono-host server1
ordre d'orchestration
stdlib .venv
PostgreSQL SCRAM + localhost-only
Redis localhost-only + protected-mode + auth
Celery Worker depuis .venv
Beat séparé avec DatabaseScheduler
endpoints health Redis/Celery
scénarios add/database_probe/Beat dans validate.yml
absence de fichiers runtime sensibles versionnés
ansible-playbook --syntax-check lorsque disponible
```

Le Vault factice utilisé uniquement pour le syntax-check statique contient maintenant les trois variables requises : PostgreSQL, Django et Redis.

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
RC-05   rôle Redis                         ✅
RC-06   rôle Celery Worker                 ✅
RC-06B  Django Celery Beat                 ✅
RC-07   orchestration globale              ✅
RC-08   runtime validation                 ✅
RC-09   static gate                        ✅ IMPLEMENTED
RC-10   qualification E2E                  ⏭ NEXT
RC-11   idempotence                        ⏳
RC-12   packaging + artifact               ⏳
RC-13   rapport final                      ⏳
```

## Documentation

Les jalons sont décrits dans `IMPLEMENTATION_PLAN.md`, `ARCHITECTURE.md` et les fichiers `RC_*.md` du dossier.
