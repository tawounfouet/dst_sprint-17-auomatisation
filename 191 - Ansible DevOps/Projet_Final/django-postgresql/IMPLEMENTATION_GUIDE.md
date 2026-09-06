# Guide d'implémentation

Le playbook applique successivement `common` à tous les hôtes, `postgresql` au groupe `database`, puis `django_app` et `nginx` au groupe `app`.

Les secrets `vault_postgresql_password` et `vault_django_secret_key` résident dans un fichier Vault local non versionné.

## Runtime Python

Pour le runtime Python du projet Django, le choix retenu est **le module standard `venv`**, et non le paquet tiers `virtualenv`.

L'environnement virtuel est créé sous :

```text
/opt/datascientest-django/.venv
```

avec :

```bash
python3 -m venv /opt/datascientest-django/.venv
```

Les dépendances sont ensuite installées avec le `pip` embarqué dans `.venv`.

## Frontend HTTP

Nginx constitue le seul point d'entrée HTTP public de l'application :

```text
Client
  ↓ :80
Nginx
  ↓
Gunicorn 127.0.0.1:8000
  ↓
Django
  ↓
PostgreSQL
```

Le rôle `nginx` vérifie d'abord que `collectstatic` a produit le répertoire statique et que Gunicorn répond sur son port local. Il génère ensuite le vhost, désactive le site par défaut, valide la configuration avec `nginx -t`, puis recharge Nginx via handler.

Les fichiers statiques sont servis directement depuis :

```text
/opt/datascientest-django/staticfiles/
```

alors que toutes les autres requêtes sont proxifiées vers Gunicorn.

## Qualification attendue

La validation attend `/`, `/health/` et `/health/database/` en HTTP 200 via Nginx, puis une seconde exécution Ansible sans changement résiduel.
