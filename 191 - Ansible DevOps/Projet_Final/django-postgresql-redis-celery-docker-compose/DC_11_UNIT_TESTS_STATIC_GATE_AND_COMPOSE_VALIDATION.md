# DC-11 — Unit Tests + Static Gate + Compose Validation

## Statut

```text
IMPLEMENTATION                 ✅
DJANGO UNIT TEST GATE          ✅ IMPLEMENTED
DRF API TEST GATE              ✅ IMPLEMENTED
SECRET HYGIENE GATE            ✅ IMPLEMENTED
ANSIBLE SYNTAX GATE            ✅ IMPLEMENTED
COMPOSE CONFIG DEV             ✅ IMPLEMENTED
COMPOSE CONFIG STG             ✅ IMPLEMENTED
COMPOSE CONFIG PROD            ✅ IMPLEMENTED
DOCKERFILE / HARDENING CHECKS   ✅ IMPLEMENTED
CI GREEN                       ⏳
RUNTIME E2E                    ⏳
```

DC-11 transforme les contrats architecturaux et de sécurité des jalons précédents en une barrière statique exécutable.

Aucun statut GREEN n'est revendiqué tant que le workflow GitHub Actions dédié n'a pas été observé avec succès.

## Gate canonique

Depuis `ansible-project/` :

```bash
./tests/static_checks.sh
```

Le script échoue au premier invariant non respecté et termine par :

```text
DC11_STATIC_GATE_PASS
```

uniquement si l'ensemble des contrôles obligatoires disponibles passe.

## Django / DRF

Le gate exécute le runner Django avec :

```text
APPLICATION_ENV=dev
DJANGO_SETTINGS_MODULE=config.settings.dev
DATABASE_URL absente
```

Cela qualifie le contrat DEV Lite / SQLite sans démarrer PostgreSQL.

Les suites existantes couvrent :

```text
health endpoints
Redis health mock
Celery health mock
add / uppercase / database_probe
DRF validation
status SUCCESS / FAILURE
absence de fuite d'exception
Periodic heartbeat task
```

DC-11 ajoute `tests/test_settings_runtime_policy.py`, qui isole les imports de settings dans des sous-processus et verrouille notamment :

```text
DEV sans DATABASE_URL                → SQLite autorisé
APPLICATION_ENV != settings module   → FAIL
STG sans DATABASE_URL                → FAIL
STG avec SQLite                      → FAIL
PROD avec SQLite                     → FAIL
PROD secret court                    → FAIL
PROD Celery non-Redis                → FAIL
STG PostgreSQL valide + DEBUG=false  → OK
```

Ces tests ne nécessitent aucune connexion réelle à PostgreSQL ou Redis.

## Static source checks

Le gate contrôle notamment :

```text
django-environ + DRF
settings/base.py + database.py + dev/stg/prod
pas de fallback PostgreSQL-exception → SQLite
Dockerfile multi-stage
USER app
STOPSIGNAL SIGTERM
aucun secret baked dans Dockerfile
six services Compose exacts
frontend/backend + backend internal
read_only / cap_drop / no-new-privileges
healthchecks
worker != beat
DatabaseScheduler
rôles Ansible actifs exacts
anciens rôles natifs absents de site.yml
DOCKER-USER + conntrack --ctorigdstport
daemon live-restore + firewall-backend
```

## Secret hygiene

DC-11 exécute :

```bash
python3 scripts/secret_hygiene.py repo
```

avant les autres opérations susceptibles de produire des fichiers temporaires.

Les canaris utilisés ensuite sont explicitement marqués `STATIC_CHECK_ONLY` et les Vaults temporaires sont supprimés par `trap`.

## Ansible syntax

Le gate vérifie :

```text
site.yml avec inventory DEV
site.yml avec inventory STG
site.yml avec inventory PROD
docker_engine.yml
runtime_hardening.yml
```

`community.docker` est obligatoire.

Le syntax-check ne déploie rien et ne constitue pas une preuve de convergence runtime.

## Compose config multi-environnement

Pour chaque environnement, le gate produit un fichier canari temporaire puis exécute :

```bash
docker compose \
  --env-file <canary> \
  -f docker/compose.yml \
  -f docker/compose.<env>.yml \
  config --quiet
```

puis :

```bash
docker compose ... config > rendered.yml
python3 tests/validate_compose_config.py <env> rendered.yml
```

Le validateur du Compose rendu vérifie entre autres :

```text
services = nginx, web, db, redis, worker, beat
web/worker/beat même image
DEV build autorisé
STG/PROD aucun build
STG/PROD APP_IMAGE @sha256
Nginx seul port publié
DEV → 127.0.0.1:8080
STG/PROD → :80
8000/5432/6379 non publiés
backend internal
matrice réseau attendue
read_only pour app/Redis/Nginx
no-new-privileges
cap_drop ALL
resource limits
PID limits
json-file rotation
healthchecks
aucun container privileged
aucun host network / host PID
aucun docker.sock
pas de bind mount /app en STG/PROD
worker sans -B
Beat avec DatabaseScheduler
```

## Docker daemon validation

Lorsque `dockerd` est disponible, le gate exécute également :

```bash
dockerd --validate --config-file <temporary-daemon.json>
```

sur une configuration canari équivalente au contrat DC-10.

## Workflow GitHub Actions

Le workflow ajouté est :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-static.yml
```

Il installe :

```text
Python 3.12
requirements Django
ansible-core
PyYAML
collections Ansible
```

puis lance uniquement le gate statique. Il ne démarre pas la stack applicative.

## Ce que DC-11 ne prouve pas encore

```text
build réel de l'image applicative
six containers healthy
PostgreSQL/Redis réels
HTTP réel via Nginx
round-trip Celery
Beat périodique réellement exécuté
network reachability runtime
DOCKER-USER sur une cible de déploiement
reboot/recovery
idempotence Ansible/Compose
```

Ces preuves commencent avec DC-12.

## Prochain jalon

```text
DC-12 — DEV Full E2E Qualification
```

Il devra construire l'image une fois, converger les six services en DEV Full, valider les healthchecks, effectuer les round-trips fonctionnels Celery/Beat et prouver le contrat réseau depuis l'hôte.
