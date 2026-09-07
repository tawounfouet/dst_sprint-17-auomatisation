# RC-11 — Idempotence stricte

## Statut

**HARNESS IMPLÉMENTÉ ✅ — RUN GITHUB ACTIONS À QUALIFIER**

RC-11 étend la qualification mono-host afin de prouver que le `site.yml` complet est strictement idempotent après un premier déploiement réussi.

## Principe

Sur le même `server1`, avec le même inventaire et le même Vault éphémère :

```text
site.yml #1
   ↓
runtime GREEN
   ↓
network contract GREEN
   ↓
site.yml #2
   ↓
server1 changed=0
   ↓
runtime GREEN à nouveau
   ↓
network contract GREEN à nouveau
```

Le second passage ne doit pas redémarrer inutilement PostgreSQL, Redis, Gunicorn, Celery Worker, Celery Beat ou Nginx.

## Gate d'idempotence

Le harness extrait le `PLAY RECAP` du deuxième `ansible-playbook` et exige exactement :

```text
server1 changed=0
```

L'absence de ligne de recap ou l'impossibilité de parser le compteur provoque également un échec explicite.

## Points sensibles

Les composants susceptibles de casser l'idempotence sont notamment :

```text
APT / timezone
postgresql.conf / pg_hba.conf
redis.conf
code Django copié
pip requirements
manage.py migrate
collectstatic
EnvironmentFile
systemd Gunicorn
systemd Celery Worker
commande ensure_demo_periodic_task
systemd Celery Beat
Nginx
handlers restart/reload
```

La tâche périodique continue naturellement à modifier ses données runtime (`last_run_at`, `total_run_count`). Ces changements métier ne doivent pas être confondus avec des changements de configuration Ansible : la commande `ensure_demo_periodic_task` ne gère que son contrat déclaratif et doit répondre `unchanged` lorsque celui-ci est déjà conforme.

## Validation post-idempotence

Après `changed=0`, le harness relance `validate_runtime.sh`. Il revalide donc :

```text
PostgreSQL + SELECT 1
Redis + PING
Gunicorn
Celery Worker + control ping
Celery Beat + PeriodicTask
Nginx
add(21,21) → 42
database_probe → SELECT 1
```

Puis il répète le contrat réseau :

```text
80    reachable=true
8000  reachable=false
5432  reachable=false
6379  reachable=false
```

## Workflow

Le workflow RC-10 existant est étendu plutôt que dupliqué :

```text
.github/workflows/ansible-django-postgresql-redis-celery-monohost.yml
```

L'artifact de succès RC-11 contiendra également le log d'idempotence.

## Definition of Done RC-11

```text
second site.yml réellement exécuté              ✅ harness
PLAY RECAP parsé                                 ✅ harness
server1 changed=0                                ⏳ preuve CI
runtime validation après second passage          ⏳ preuve CI
network contract après second passage            ⏳ preuve CI
workflow final RC-11 GREEN                       ⏳
```

Le jalon sera fermé uniquement après lecture d'un run GitHub Actions réussi.
