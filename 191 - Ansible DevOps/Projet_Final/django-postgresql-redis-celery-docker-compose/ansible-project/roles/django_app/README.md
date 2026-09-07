# Role `django_app`

Déploie la mini-application Django du projet et configure son runtime Gunicorn.

## Choix Python : `venv` natif

Le rôle utilise explicitement le module standard Python `venv` :

```bash
python3 -m venv /opt/datascientest-django/.venv
```

Il n'installe ni n'utilise le paquet tiers `virtualenv`. L'environnement virtuel est systématiquement nommé `.venv`.

Ansible rend cette création idempotente grâce à :

```text
creates: /opt/datascientest-django/.venv/bin/python
```

Les dépendances sont ensuite installées via le `pip` contenu dans `.venv`.

## Pipeline

```text
packages Python
    ↓
system user django
    ↓
/opt/datascientest-django
    ↓
copy source
    ↓
python3 -m venv .venv
    ↓
.venv/bin/pip install -r requirements.txt
    ↓
/etc/datascientest-django/django.env
    ↓
manage.py check
    ↓
manage.py migrate
    ↓
manage.py collectstatic
    ↓
Gunicorn systemd
    ↓
127.0.0.1:8000
```

## Secrets

`DJANGO_SECRET_KEY` et `POSTGRES_PASSWORD` proviennent d'Ansible Vault. Le fichier d'environnement est rendu en `0640`, groupe `django`, et la tâche de template utilise `no_log: true`.

## Gunicorn

Le service est nommé `datascientest-django` par défaut et Gunicorn écoute uniquement sur `127.0.0.1:8000`. L'exposition HTTP externe sera assurée dans le LOT 05 par Nginx.
