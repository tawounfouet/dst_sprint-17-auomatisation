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
RUNTIME VALIDATION       ✅ GREEN
STATIC GATE              ✅ GREEN
E2E RC-10                ✅ GREEN
IDEMPOTENCE RC-11        ⏭ IN PROGRESS
PACKAGE / ARTIFACT RC-12 ⏳
FINAL REPORT RC-13       ⏳
```

> La qualification GREEN du projet source n'a pas été héritée : la variante possède désormais son propre run E2E GREEN. Le package final reste cependant à produire en RC-12.

## Architecture qualifiée RC-10

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

Contrat réseau observé sur le run RC-10 canonique :

```text
80    → reachable=true
8000  → reachable=false
5432  → reachable=false
6379  → reachable=false
```

## Orchestration

```text
common → postgresql → redis → django_app → celery → celery_beat → nginx
```

La topologie canonique est mono-host : `server1` appartient aux groupes `app` et `database`.

## RC-10 — qualification E2E GREEN

Run canonique :

```text
workflow : Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
run      : #2
run ID   : 34097929297
job ID   : 101665586486
head SHA : ee87a8e332ddbf90ce953cc26c0cc7c50241e25a
result   : SUCCESS
```

Premier déploiement :

```text
localhost : ok=1  changed=0  unreachable=0 failed=0
server1   : ok=81 changed=43 unreachable=0 failed=0
```

Validation runtime :

```text
localhost : ok=1  changed=0 unreachable=0 failed=0
server1   : ok=37 changed=0 unreachable=0 failed=0
```

Services :

```text
postgresql      active
redis-server    active
gunicorn        active
celery worker   active
celery beat     active
nginx           active
```

Preuves fonctionnelles réelles :

```text
/health/database/ → PostgreSQL SELECT 1
/health/redis/    → Redis PING
/health/celery/   → worker control ping
add(21,21)        → 42 via Redis/Celery
 database_probe   → PostgreSQL SELECT 1 depuis le worker
Celery Beat       → datascientest-demo-heartbeat déclenchée
```

Artifact de preuves RC-10 :

```text
ID      : 10009418965
digest  : sha256:7f6cbfb05178bc0f9f81f7146bf3843ebc440df9391ac82d13403df01e09db46
expires : 2026-09-21T07:59:32Z
```

Cet artifact est une preuve CI et non le ZIP final de livraison.

## RC-11 — idempotence stricte

Le harness est maintenant étendu pour réexécuter le même `site.yml` sur la même cible et exiger :

```text
server1 changed=0
```

Après ce gate, toute la validation runtime et le contrat réseau sont rejoués. Le statut RC-11 restera en cours jusqu'à observation d'un run GitHub Actions GREEN correspondant.

## Dépendances Python

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
django-celery-beat>=2.9,<3
```

## Tâches de démonstration

```text
add(21, 21)                 → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe()            → PostgreSQL → SELECT 1
periodic_heartbeat()        → heartbeat horodaté via Celery Beat
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
RC-11   idempotence stricte                ⏭ NEXT / IN PROGRESS
RC-12   packaging + artifact final         ⏳
RC-13   rapport final                      ⏳
```

## Limite de la qualification

La qualification utilise une cible Ubuntu 24.04 jetable et le transport `community.docker.docker`. Elle prouve l'intégration applicative et Ansible en CI, pas encore un déploiement SSH sur VPS public, DNS, TLS ou firewall cloud.
