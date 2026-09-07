# RC-10 — Première qualification E2E Redis / Celery / Beat

## Statut

**RUN #1 OBSERVÉ ❌ — CORRECTIF DE SYNCHRONISATION BEAT APPLIQUÉ — NOUVEAU RUN À QUALIFIER**

RC-10 introduit la première qualification GitHub Actions dédiée à la variante mono-serveur Django + PostgreSQL + Redis + Celery Worker + Django Celery Beat + Nginx.

## Harness

Le harness dédié est :

```text
ansible-project/tests/e2e/run_monohost_redis_celery_qualification.sh
```

Il provisionne une seule cible Ubuntu 24.04 avec systemd et place `server1` dans les groupes Ansible `app` et `database`.

## Workflow

```text
.github/workflows/ansible-django-postgresql-redis-celery-monohost.yml
```

Le workflow s'exécute sur Ubuntu 24.04 et publie les preuves de qualification ou les diagnostics de panne. RC-12 restera responsable du ZIP final, du SHA-256 et du package safety gate.

## Run #1

```text
workflow : Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
run      : #1
run ID   : 34097304269
head SHA : dc06ac0607bb9e2dddaffbb1168efdcd8dab5972
conclusion: failure
```

Le run a prouvé avec succès avant l'échec final :

```text
static gate PASS
inventaire mono-host server1 PASS
site.yml #1 PASS
PostgreSQL actif
Redis actif + PING authentifié
Gunicorn actif
Celery Worker actif + control ping
Celery Beat actif
Nginx actif
add(21,21) → SUCCESS / 42
database_probe → SUCCESS / SELECT 1
```

La première installation Ansible s'est terminée sans erreur :

```text
server1 : ok=81 changed=43 unreachable=0 failed=0
```

## Cause du RED

La validation exigeait :

```text
django_celery_beat_periodictask.total_run_count >= 1
```

mais la requête lisait encore :

```text
total_run_count = 0
```

après la fenêtre de polling.

Les diagnostics montrent pourtant que Celery Beat avait réellement publié la tâche toutes les 30 secondes et que le worker l'avait exécutée :

```text
09:51:27 Scheduler: Sending due task datascientest-demo-heartbeat
09:51:27 tasks_demo.periodic_heartbeat succeeded

09:51:57 Scheduler: Sending due task datascientest-demo-heartbeat
09:51:57 tasks_demo.periodic_heartbeat succeeded

09:52:27 Scheduler: Sending due task datascientest-demo-heartbeat
09:52:27 tasks_demo.periodic_heartbeat succeeded
```

Le défaut portait donc sur la **persistance observable de l'état du DatabaseScheduler**, pas sur l'exécution de Beat ni sur le worker.

## Correctif

La configuration Django impose désormais :

```python
CELERY_BEAT_SYNC_EVERY = int(os.getenv("CELERY_BEAT_SYNC_EVERY", "1"))
```

Le DatabaseScheduler doit ainsi synchroniser son état persistant après chaque tâche publiée, ce qui rend `total_run_count` observable de façon déterministe dans la fenêtre E2E.

## Vault éphémère

Le harness génère trois secrets aléatoires uniquement pour le run CI :

```text
vault_postgresql_password
vault_django_secret_key
vault_redis_password
```

Le Vault est chiffré avant le déploiement et les fichiers runtime (`hosts.yml`, `vault.yml`, `.vault_pass`) sont supprimés au cleanup.

## Contrat réseau

Le runner doit observer :

```text
server1:80    reachable=true
server1:8000  reachable=false
server1:5432  reachable=false
server1:6379  reachable=false
```

## Hors périmètre RC-10

La preuve stricte du deuxième `site.yml` :

```text
server1 changed=0
```

reste RC-11.

Le ZIP final, le SHA-256, le package safety gate et l'artifact de livraison restent RC-12.

## Critères de sortie

```text
harness Redis/Celery/Beat dédié                     ✅
workflow GitHub Actions dédié                       ✅
static gate réellement exécuté                      ✅ run #1
premier déploiement complet                          ✅ run #1
round-trip add(21,21) réel                          ✅ run #1
round-trip database_probe réel                      ✅ run #1
Beat publie periodic_heartbeat                      ✅ diagnostics run #1
worker exécute periodic_heartbeat                   ✅ diagnostics run #1
persistance DatabaseScheduler déterministe           ✅ correctif appliqué
contrat réseau vérifié                               ⏳ run GREEN attendu
run GitHub Actions final GREEN                       ⏳
```

RC-10 ne sera déclaré **GREEN** qu'après observation d'un nouveau run GitHub Actions réussi de bout en bout.
