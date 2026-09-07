# RC-10 — Première qualification E2E Redis / Celery / Beat

## Statut

**GREEN ✅**

La première qualification E2E de la variante mono-serveur Django + PostgreSQL + Redis + Celery Worker + Django Celery Beat + Nginx a été obtenue sur GitHub Actions.

## Run canonique RC-10

```text
workflow   : Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
run        : #2
run ID     : 34097929297
job ID     : 101665586486
head SHA   : ee87a8e332ddbf90ce953cc26c0cc7c50241e25a
conclusion : success
runner     : Ubuntu 24.04.4
Python     : 3.12.14
ansible    : 2.20.8
```

Le run a démarré le `2026-09-07T07:55:54Z` et s'est terminé avec succès à `2026-09-07T07:59:37Z`.

## Static gate

```text
All available static checks passed.
```

## Topologie réellement utilisée

```text
@all:
  |--@ungrouped:
  |--@app:
  |  |--server1
  |--@database:
  |  |--server1
```

La cible était un conteneur Ubuntu 24.04 + systemd jetable. Son adresse `172.18.0.2` appartient uniquement au réseau CI de ce run et ne constitue pas une adresse de production.

## Premier déploiement

```text
localhost : ok=1  changed=0  unreachable=0 failed=0 skipped=0
server1   : ok=81 changed=43 unreachable=0 failed=0 skipped=0
```

## Runtime validation

```text
localhost : ok=1  changed=0 unreachable=0 failed=0 skipped=0
server1   : ok=37 changed=0 unreachable=0 failed=0 skipped=0
```

Services observés actifs :

```text
server1 postgresql=active
server1 redis=active
server1 gunicorn=active
server1 celery=active
server1 celery_beat=active
server1 nginx=active
```

## Preuves fonctionnelles

Le run a réellement validé :

```text
/health/             → healthy
/health/database/    → PostgreSQL connected + SELECT 1
/health/redis/       → Redis connected + PING
/health/celery/      → Celery connected + worker répond
```

Round-trip asynchrone :

```text
Django API
   ↓
add(21,21)
   ↓
Redis broker
   ↓
Celery Worker
   ↓
Redis result backend
   ↓
SUCCESS / 42
```

Accès DB depuis le worker :

```text
Django API
   ↓
database_probe
   ↓
Redis
   ↓
Celery Worker
   ↓
Django DB connection
   ↓
PostgreSQL
   ↓
SELECT 1
```

Django Celery Beat a également passé le contrat :

```text
PeriodicTask = datascientest-demo-heartbeat
task         = tasks_demo.periodic_heartbeat
enabled      = true
total_run_count >= 1
```

## Contrat réseau observé

```text
172.18.0.2:80   reachable=true  expected=true
172.18.0.2:8000 reachable=false expected=false
172.18.0.2:5432 reachable=false expected=false
172.18.0.2:6379 reachable=false expected=false
```

Le runner n'accède donc directement ni à Gunicorn, ni à PostgreSQL, ni à Redis.

## Incident du run #1

Le run #1 (`34097304269`) avait échoué uniquement parce que `django-celery-beat` n'avait pas encore synchronisé `total_run_count` vers PostgreSQL dans la fenêtre de validation. Les diagnostics prouvaient déjà que Beat publiait `periodic_heartbeat` et que le worker l'exécutait.

Le correctif appliqué est :

```python
CELERY_BEAT_SYNC_EVERY = 1
```

Le run #2 a ensuite validé le contrat complet.

## Artifact de preuves RC-10

```text
name      : ansible-django-postgresql-redis-celery-rc10-34097929297
artifact  : 10009418965
size      : 6624 bytes
digest    : sha256:7f6cbfb05178bc0f9f81f7146bf3843ebc440df9391ac82d13403df01e09db46
created   : 2026-09-07T07:59:33Z
expires   : 2026-09-21T07:59:32Z
```

URL de téléchargement GitHub Actions :

```text
https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34097929297/artifacts/10009418965
```

Cet artifact contient les preuves RC-10 ; il ne s'agit pas encore du package final de livraison RC-12.

## Limites de RC-10

RC-10 prouve l'intégration et le runtime sur une cible Ubuntu 24.04 jetable via `community.docker.docker`. Il ne prouve pas un déploiement SSH sur VPS public, TLS, DNS ou firewall cloud.

RC-10 ne prouve pas non plus encore l'idempotence stricte du `site.yml` complet. Cette preuve appartient à RC-11.

## Suite

**RC-11 — idempotence stricte** : réexécuter le même `site.yml` sur le même `server1`, exiger `changed=0`, puis refaire toute la validation runtime et le contrat réseau après ce second passage.
