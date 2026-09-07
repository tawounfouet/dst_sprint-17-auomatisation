# Mini application Django — LOT 01

Cette application est volontairement minimale. Elle sert de charge applicative au projet Ansible Django/PostgreSQL et fournit quatre endpoints de qualification.

## Endpoints

| Endpoint | Dépend de PostgreSQL | Usage |
|---|---:|---|
| `/` | non | identité de l'application |
| `/health/` | non | liveness HTTP/Django |
| `/health/database/` | oui | requête réelle `SELECT 1` via la connexion Django |
| `/api/info/` | non | métadonnées runtime non sensibles |

`/health/database/` retourne HTTP 503 si PostgreSQL n'est pas joignable. L'exception n'est pas exposée au client.

## Configuration

L'application ne contient aucun secret en dur. Elle attend :

```text
DJANGO_SECRET_KEY
DJANGO_DEBUG
DJANGO_ALLOWED_HOSTS
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_HOST
POSTGRES_PORT
```

En production ces variables seront rendues par le rôle `django_app` à partir des variables publiques et d'Ansible Vault.

## Exécution de développement

Une base PostgreSQL accessible est nécessaire pour `/health/database/` et pour les migrations.

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
export DJANGO_SECRET_KEY='dev-only-change-me'
export DJANGO_DEBUG=true
export DJANGO_ALLOWED_HOSTS='127.0.0.1,localhost'
export POSTGRES_DB=django_app
export POSTGRES_USER=django_app
export POSTGRES_PASSWORD='<LOCAL_PASSWORD>'
export POSTGRES_HOST=127.0.0.1
export POSTGRES_PORT=5432
python manage.py check
python manage.py migrate
python manage.py runserver
```

Le mot de passe ci-dessus est un placeholder : aucun secret réel ne doit être commité.
