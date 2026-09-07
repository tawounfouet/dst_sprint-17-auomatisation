# Tests statiques — RC-09

`static_checks.sh` constitue la barrière de qualité avant la qualification E2E de la variante Django + PostgreSQL + Redis + Celery + Beat.

Il vérifie désormais :

```text
structure des rôles common/postgresql/redis/django_app/celery/celery_beat/nginx
scaffold Django, Celery, tasks_demo et django-celery-beat
versions bornées des dépendances Python
syntaxe Bash
syntaxe Python via ast.parse
syntaxe YAML lorsque PyYAML est disponible
inventaire mono-host server1
ordre common → postgresql → redis → django_app → celery → celery_beat → nginx
stdlib .venv et absence de virtualenv dans le runtime
PostgreSQL SCRAM et localhost-only
Redis localhost-only, protected-mode et requirepass
usage REDISCLI_AUTH au lieu de redis-cli -a
Gunicorn 127.0.0.1:8000
worker Celery depuis le .venv et sans worker -B
Beat séparé avec DatabaseScheduler
health endpoints Redis/Celery
contrats de validation add(21,21), database_probe et Beat
absence de fichiers runtime sensibles suivis par Git
```

Lorsque `ansible-playbook` est disponible, le script exécute également :

```text
ansible-playbook ... playbooks/site.yml --syntax-check
ansible-playbook ... playbooks/validate.yml --syntax-check
```

Si le Vault réel est absent, un fichier factice non secret est créé temporairement avec :

```text
vault_postgresql_password
vault_django_secret_key
vault_redis_password
```

puis supprimé automatiquement.

Si un Vault chiffré existe sans mot de passe disponible, le syntax-check nécessitant son déchiffrement est explicitement ignoré plutôt que de demander ou d'exposer un secret.

Exécution :

```bash
cd ansible-project
./tests/static_checks.sh
```

Ces contrôles ne prouvent pas le runtime. Les preuves de services actifs, round-trips Celery, exécution Beat, exposition réseau et idempotence sont apportées par les jalons E2E suivants.
