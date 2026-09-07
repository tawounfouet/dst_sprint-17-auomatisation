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
PACKAGE / ARTIFACT       ✅ GREEN
FINAL REPORT             ✅ CLOSED
```

La qualification GREEN du projet source n'a pas été héritée : cette variante dispose de ses propres preuves RC-10, RC-11 et RC-12.

## Architecture qualifiée

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

Contrat réseau observé :

```text
80    reachable=true
8000  reachable=false
5432  reachable=false
6379  reachable=false
```

## Orchestration

Le `site.yml` orchestre les sept rôles :

```text
common → postgresql → redis → django_app → celery → celery_beat → nginx
```

La topologie canonique est mono-host : le même `server1` appartient aux groupes `app` et `database`.

## Qualification E2E

Le workflow canonique est :

```text
Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
```

Le run final qualifié est :

```text
run      : #4
run ID   : 34099796947
job ID   : 101671354038
commit   : a7efa47d66a9b564bd36753f1dbdccbcb5cb7977
conclusion: success
```

La qualification valide réellement :

```text
PostgreSQL + DB + role
Redis + PING authentifié
Gunicorn
Celery Worker + control ping
Django Celery Beat + PeriodicTask déclenchée
Nginx + nginx -t
GET /health/
GET /health/database/
GET /health/redis/
GET /health/celery/
add(21,21) → 42
database_probe() → SELECT 1
```

## Idempotence stricte

Le second `site.yml` du run final produit :

```text
server1 : ok=73 changed=0 unreachable=0 failed=0 skipped=3
IDEMPOTENCE PASS: server1 changed=0
```

La validation runtime complète et le contrat réseau sont ensuite rejoués avec succès.

## Packaging final

Archive qualifiée :

```text
django-postgresql-redis-celery-ansible-20260907-082219.zip
```

SHA-256 du ZIP projet :

```text
558ef15ee8de57bf9d4ea09edcbdc586ff5a01c423c538de79119fb85df8ab8f
```

Contrôles :

```text
sha256sum -c   ✅ OK
PACKAGE SAFETY ✅ PASS
```

Artifact GitHub Actions :

```text
name       : ansible-django-postgresql-redis-celery-qualified-34099796947
artifact ID: 10010158233
size       : 114672 bytes
expires    : 2026-09-21T08:22:19Z
digest     : sha256:e70b25c19c0bbd5d0d69a5a20213398a6dd4b0ba157f3198b8e9febaf020f07c
```

Téléchargement :

```text
https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34099796947/artifacts/10010158233
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
periodic_heartbeat()        → heartbeat via Celery Beat
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

## Limite de la preuve

Le projet est qualifié en CI sur un unique Ubuntu 24.04 avec systemd et transport `community.docker.docker`. Ce statut ne prouve pas encore un déploiement SSH sur VPS public, DNS, TLS/Let's Encrypt, UFW, backup/restore ou haute disponibilité.

## Roadmap finale

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
RC-12   packaging + artifact               ✅ GREEN
RC-13   rapport final                      ✅ CLOSED
```

## Documentation finale

Le rapport de clôture est :

```text
RC_13_FINAL_QUALIFICATION_REPORT.md
```

Les autres jalons restent documentés dans `IMPLEMENTATION_PLAN.md`, `ARCHITECTURE.md` et les fichiers `RC_*.md` du dossier.
