# Tests — DC-11 Static Gate

`tests/static_checks.sh` est la barrière statique canonique de la variante Docker Compose.

Il transforme les contrats DC-02 à DC-10 en contrôles exécutables avant toute qualification E2E.

## Contrôles réalisés

```text
structure projet / rôles actifs
versions bornées Django / DRF / django-environ / Celery
syntaxe Bash
syntaxe Python via ast.parse
syntaxe YAML via PyYAML
secret_hygiene.py repo
settings multi-environnement
SQLite DEV-only / PostgreSQL STG-PROD
DRF serializers + API views
Dockerfile multi-stage / non-root / SIGTERM
six services Compose
web/worker/beat même image
read_only / no-new-privileges / cap_drop
healthchecks / resource limits / logging rotation
frontend/backend + backend internal
absence de ports publiés 8000/5432/6379
worker séparé de Beat
DatabaseScheduler
site.yml : common → docker_engine → docker_runtime_hardening → compose_stack
anciens rôles natifs non actifs
DOCKER-USER + conntrack original destination port
Django unit/API tests
Ansible syntax-check
Docker Compose config DEV/STG/PROD
validation structurelle du Compose rendu
dockerd --validate lorsque dockerd est disponible
```

## Validation Compose

`tests/validate_compose_config.py` reçoit la sortie de :

```bash
docker compose ... config
```

et contrôle le modèle **rendu**, pas uniquement les fichiers YAML sources.

Les trois environnements utilisent des valeurs canaris non secrètes. Pour STG et PROD, le gate fournit une image fictive mais syntaxiquement immuable :

```text
registry.example.invalid/datascientest-django@sha256:<64 hex>
```

Aucune image n'est tirée ou exécutée en DC-11.

## Ansible syntax-check

Si les vrais `vault.yml` sont absents, le gate génère temporairement des Vaults plaintext canaris conformes au contrat puis les supprime via `trap`.

Si un Vault chiffré réel existe sans mot de passe disponible, le syntax-check `site.yml` de cet environnement est explicitement ignoré plutôt que de demander ou d'exposer un secret.

## Django tests

Le gate exécute :

```bash
python manage.py test tests tasks_demo.tests
```

avec `config.settings.dev` et sans `DATABASE_URL`, afin de qualifier le mode DEV Lite SQLite. Des sous-processus dédiés vérifient ensuite les scénarios STG/PROD fail-fast sans connexion réelle à PostgreSQL.

## Exécution

Depuis `ansible-project/` :

```bash
ansible-galaxy collection install -r requirements.yml
./tests/static_checks.sh
```

Le workflow dédié est :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-static.yml
```

## Limite

DC-11 ne démarre pas les six containers. Il ne prouve donc pas encore : services healthy réels, round-trip Celery, exécution Beat, network reachability runtime, firewall réel ou idempotence. Ces preuves appartiennent à DC-12 et suivants.
