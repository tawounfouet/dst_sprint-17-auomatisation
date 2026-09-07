# DC-11 — Unit Tests + Static Gate + Compose Validation

## Statut

```text
IMPLEMENTATION                  ✅
DJANGO UNIT TEST GATE           ✅ GREEN
DRF API TEST GATE               ✅ GREEN
SECRET HYGIENE GATE             ✅ GREEN
ANSIBLE SYNTAX GATE             ✅ GREEN
COMPOSE CONFIG DEV              ✅ GREEN
COMPOSE CONFIG STG              ✅ GREEN
COMPOSE CONFIG PROD             ✅ GREEN
DOCKERFILE / HARDENING CHECKS   ✅ GREEN
CI GREEN                        ✅
RUNTIME E2E                     ✅ MOVED TO DC-12 / GREEN DEV FULL
```

DC-11 transforme les contrats architecturaux et de sécurité des jalons précédents en une barrière statique exécutable.

## Qualification canonique

```text
Workflow : Ansible Django PostgreSQL Redis Celery Compose Static Gate
Run      : #7
Run ID   : 34133167102
Job ID   : 101777908524
HEAD     : 4c1a7f2a567739724794653d356ac17cc77312fb
Result   : SUCCESS

Runner   : Ubuntu 24.04.4
Python   : 3.12.14
Ansible  : ansible-core 2.20.8
Docker   : 28.0.4
Compose  : v2.38.2
```

Le gate a ensuite été rejoué avec succès sur le HEAD qualifié DC-12 :

```text
Run ID : 34135447373
Job ID : 101785201716
HEAD   : f479e84b9152e3d9d1fab385b5256233a551f123
Result : SUCCESS
```

## Gate canonique

Depuis `ansible-project/` :

```bash
./tests/static_checks.sh
```

Le script termine par :

```text
DC11_STATIC_GATE_PASS
```

uniquement lorsque tous les contrôles obligatoires passent.

## Django / DRF

Le gate exécute le runner Django avec :

```text
APPLICATION_ENV=dev
DJANGO_SETTINGS_MODULE=config.settings.dev
DATABASE_URL absente
```

Le run canonique a exécuté 39 tests et obtenu :

```text
Ran 39 tests
OK
System check identified no issues (0 silenced)
```

Les suites couvrent notamment les health endpoints, les mocks Redis/Celery, les tâches `add`, `uppercase`, `database_probe`, la validation DRF, les statuts `SUCCESS`/`FAILURE`, l'absence de fuite d'exception et le heartbeat périodique.

`tests/test_settings_runtime_policy.py` verrouille :

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

## Static source checks

Le gate contrôle notamment :

```text
django-environ + DRF
settings/base.py + database.py + dev/stg/prod
pas de fallback silencieux PostgreSQL → SQLite
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
daemon live-restore + iptables/ip6tables
```

Le contrôle anti-fallback de `database.py` utilise l'AST Python plutôt qu'une recherche textuelle fragile.

## Secret hygiene

DC-11 exécute :

```bash
python3 scripts/secret_hygiene.py repo
```

Les canaris sont explicitement marqués `STATIC_CHECK_ONLY` et les Vaults temporaires sont supprimés par `trap`.

## Ansible syntax

Le gate vérifie :

```text
site.yml avec inventory DEV
site.yml avec inventory STG
site.yml avec inventory PROD
docker_engine.yml
runtime_hardening.yml
```

Le run canonique a validé les cinq syntax-checks. `community.docker` est obligatoire.

## Compose config multi-environnement

Pour DEV, STG et PROD, le gate exécute :

```bash
docker compose \
  --env-file <canary> \
  -f docker/compose.yml \
  -f docker/compose.<env>.yml \
  config --quiet
```

puis valide le Compose rendu avec :

```bash
python3 tests/validate_compose_config.py <env> rendered.yml
```

Preuves observées :

```text
COMPOSE_CONFIG_PASS: dev
COMPOSE_CONFIG_PASS: stg
COMPOSE_CONFIG_PASS: prod
STATIC_GATE_PASS: Compose config DEV/STG/PROD
```

Le validateur impose notamment les six services, l'image commune `web/worker/beat`, l'absence de build STG/PROD, le digest d'image STG/PROD, la segmentation réseau, les ports, `read_only`, capabilities, resource/PID limits, logging, healthchecks, l'absence de `privileged`, host network/PID, docker.sock et bind mount `/app` en STG/PROD.

## Docker daemon validation

Lorsque `dockerd` est disponible :

```bash
dockerd --validate --config-file <temporary-daemon.json>
```

Le premier contrat avec `firewall-backend` a révélé une incompatibilité réelle avec Docker Engine 28.0.4. Il a été corrigé vers le contrat portable :

```text
live-restore=true
iptables=true
ip6tables=true
json-file + rotation
```

Le run canonique obtient :

```text
configuration OK
STATIC_GATE_PASS: dockerd --validate
```

La politique `DOCKER-USER` reste gérée séparément par le rôle et son template firewall.

## Frontière de DC-11

DC-11 prouve les contrats statiques, les tests Django/DRF, Ansible syntax-check, Compose rendering et Docker daemon config. Il ne constituait pas à lui seul une preuve de services réellement démarrés.

Cette frontière a été franchie par DC-12, désormais GREEN en DEV Full.

## Verdict

```text
DC11_STATIC_GATE_PASS
```

**DC-11 est GREEN.**

## Prochain jalon actuel

```text
DC-13 — STG-like E2E + anti-SQLite Runtime Qualification
```
