# RC-11 — Idempotence stricte

## Statut

**GREEN ✅ — GITHUB ACTIONS QUALIFIÉ**

RC-11 étend la qualification mono-host afin de prouver que le `site.yml` complet est strictement idempotent après un premier déploiement réussi.

## Run canonique

```text
workflow : Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
run      : #3
run ID   : 34098706910
job ID   : 101667987578
commit   : dfe34108e62db95c7ec8e4e8ce13ee1ce37f363b
status   : success
```

## Preuve d'idempotence

Le second `site.yml`, exécuté sur le même `server1` avec le même inventaire et le même Vault éphémère, produit :

```text
localhost : ok=1  changed=0  unreachable=0 failed=0 skipped=0
server1   : ok=73 changed=0  unreachable=0 failed=0 skipped=3

IDEMPOTENCE PASS: server1 changed=0
```

Le gate parse explicitement le `PLAY RECAP` et échoue si la ligne `server1` est absente, non parsable ou si `changed != 0`.

## Validation post-idempotence

Après le second passage, `validate_runtime.sh` est relancé et reste GREEN :

```text
PostgreSQL + SELECT 1
Redis + PING authentifié
Gunicorn
Celery Worker + control ping
Django Celery Beat + PeriodicTask
Nginx
add(21,21) → 42
database_probe() → SELECT 1
```

Le second runtime recap est :

```text
localhost : ok=1  changed=0 unreachable=0 failed=0
server1   : ok=37 changed=0 unreachable=0 failed=0
```

## Contrat réseau post-idempotence

```text
80    reachable=true
8000  reachable=false
5432  reachable=false
6379  reachable=false
```

La stack reste donc fonctionnelle et conserve les mêmes frontières réseau après un second provisioning sans changement.

## Artifact RC-11

```text
artifact ID : 10009753750
name        : ansible-django-postgresql-redis-celery-rc11-34098706910
size        : 10447 bytes
digest      : sha256:130efea39fa93904d9e8f84ec4139ac61972ee387b098e18028f6dd206659522
retention   : 14 jours
expires     : 2026-09-21T08:10:07Z
```

## Definition of Done RC-11

```text
second site.yml réellement exécuté              ✅
PLAY RECAP parsé                                 ✅
server1 changed=0                                ✅
runtime validation après second passage          ✅
network contract après second passage            ✅
workflow final RC-11 GREEN                       ✅
```

RC-11 est fermé. Le prochain jalon est RC-12 — packaging qualifié, SHA-256, contrôle de sûreté et artifact GitHub Actions final.
