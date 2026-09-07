# Projet Ansible — Django + PostgreSQL + Redis + Celery + Beat

Variante dérivée du projet `django-postgresql/` afin d'ajouter Redis, un worker Celery et `django-celery-beat` sur une topologie mono-serveur Ubuntu 24.04.

## Statut

```text
BASELINE COPIED          ✅
ARCHITECTURE / CONTRACTS ✅
PYTHON DEPENDENCIES      ✅
DJANGO / CELERY CONFIG   ✅
ASYNC TASK API           ✅
REDIS ROLE               ✅
CELERY WORKER            ✅
DJANGO CELERY BEAT       ✅
GLOBAL ORCHESTRATION     ✅
RUNTIME VALIDATION       ✅
STATIC GATE              ✅ GREEN
E2E QUALIFICATION        ✅ GREEN
IDEMPOTENCE              ✅ server1 changed=0
PACKAGE / ARTIFACT       ✅ IMPLEMENTED / CI ⏳
FINAL REPORT             ⏳
```

La qualification GREEN du projet source n'a pas été héritée : cette variante possède désormais ses propres preuves RC-10 et RC-11.

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

## Qualification E2E — RC-10

Le run canonique RC-10 a validé réellement :

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

Le contrat réseau observé reste :

```text
80    reachable=true
8000  reachable=false
5432  reachable=false
6379  reachable=false
```

## Idempotence stricte — RC-11

Le run #3 du workflow mono-host a exécuté un second `site.yml` sur le même `server1` :

```text
server1 : ok=73 changed=0 unreachable=0 failed=0 skipped=3
IDEMPOTENCE PASS: server1 changed=0
```

La validation runtime complète et le contrat réseau ont ensuite été rejoués avec succès.

## Static gate — RC-09

`ansible-project/tests/static_checks.sh` contrôle notamment :

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

## Packaging — RC-12

Le pipeline prépare désormais un livrable spécifique :

```text
django-postgresql-redis-celery-ansible-<timestamp>.zip
*.zip.sha256
```

avec :

```text
sha256sum -c
package_safety_check.sh
exclusion hosts.yml / server1.yml / vault.yml / .vault_pass / clés privées / .env / .venv
artifact GitHub Actions final
```

La qualification RC-12 sera fermée uniquement après observation du prochain run GREEN et des métadonnées réelles du ZIP/artifact.

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
RC-09   static gate                        ✅ GREEN
RC-10   qualification E2E                  ✅ GREEN
RC-11   idempotence stricte                ✅ GREEN
RC-12   packaging + artifact               ⏭ QUALIFICATION CI
RC-13   rapport final                      ⏳
```

## Documentation

Les jalons sont décrits dans `IMPLEMENTATION_PLAN.md`, `ARCHITECTURE.md` et les fichiers `RC_*.md` du dossier.
