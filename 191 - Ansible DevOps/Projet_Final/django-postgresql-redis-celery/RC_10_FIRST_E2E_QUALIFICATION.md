# RC-10 — Première qualification E2E Redis / Celery / Beat

## Statut

**HARNESS + WORKFLOW PRÉPARÉS ✅ — RUN GITHUB ACTIONS À OBSERVER**

RC-10 introduit la première qualification GitHub Actions dédiée à la variante mono-serveur Django + PostgreSQL + Redis + Celery Worker + Django Celery Beat + Nginx.

## Harness

Le nouveau harness est :

```text
ansible-project/tests/e2e/run_monohost_redis_celery_qualification.sh
```

Il provisionne une seule cible Ubuntu 24.04 avec systemd et place `server1` dans les groupes Ansible `app` et `database`.

## Vault éphémère

Le harness génère trois secrets aléatoires uniquement pour le run CI :

```text
vault_postgresql_password
vault_django_secret_key
vault_redis_password
```

Le fichier Vault est chiffré avant le déploiement et les fichiers runtime (`hosts.yml`, `vault.yml`, `.vault_pass`) sont supprimés au cleanup.

## Scénario RC-10

```text
static gate
   ↓
Ubuntu 24.04 server1
   ↓
preflight
   ↓
site.yml #1
   ↓
validate.yml
   ↓
PostgreSQL active + SELECT 1
Redis active + PING/PONG
Gunicorn active
Celery Worker active + control ping
Celery Beat active + PeriodicTask déclenchée
Nginx active + nginx -t
   ↓
add(21,21) → Redis → Worker → Redis result → 42
   ↓
database_probe → Redis → Worker → PostgreSQL → SELECT 1
   ↓
HTTP health depuis le runner
   ↓
network contract
```

## Contrat réseau

Le runner doit observer :

```text
server1:80    reachable=true
server1:8000  reachable=false
server1:5432  reachable=false
server1:6379  reachable=false
```

Ainsi Nginx reste le seul service exposé dans la topologie de laboratoire.

## Services attendus

```text
postgresql
redis-server
datascientest-django
datascientest-celery
datascientest-celery-beat
nginx
```

## Workflow

Le workflow dédié est :

```text
.github/workflows/ansible-django-postgresql-redis-celery-monohost.yml
```

Il s'exécute sur Ubuntu 24.04, installe Ansible et les collections nécessaires, lance le harness puis publie les preuves RC-10. Il ne produit pas encore le package final : cela reste le périmètre RC-12.

## Correctifs de préparation RC-10

`validate_runtime.sh` et `preflight.sh` transmettent maintenant le mot de passe Vault lorsque `.vault_pass` est présent. Ce correctif est nécessaire depuis que `validate.yml` charge `vault_redis_password` pour le PING Redis authentifié.

## Hors périmètre RC-10

RC-10 ne qualifie pas encore l'idempotence stricte du second `site.yml`. La preuve :

```text
server1 changed=0
```

reste explicitement le périmètre RC-11.

Le ZIP final, le SHA-256, le package safety gate et l'artifact de livraison restent RC-12.

## Critères de sortie

```text
harness Redis/Celery/Beat dédié                     ✅
workflow GitHub Actions dédié                       ✅
Vault éphémère avec 3 secrets                       ✅
Redis externe :6379 interdit                        ✅ contrat
Gunicorn externe :8000 interdit                     ✅ contrat
PostgreSQL externe :5432 interdit                   ✅ contrat
Nginx :80 accessible                                ✅ contrat
round-trip add(21,21) réel                          ✅ scénario
round-trip database_probe réel                      ✅ scénario
Beat PeriodicTask déclenchée                        ✅ scénario
run GitHub Actions GREEN                            ⏳
```

Le statut RC-10 ne passera à **GREEN** qu'après observation d'un run GitHub Actions réussi et lecture de ses preuves.
