# Guide d'implémentation

Le playbook applique successivement `common` à tous les hôtes, `postgresql` au groupe `database`, puis `django_app` et `nginx` au groupe `app`.

Les secrets `vault_postgresql_password` et `vault_django_secret_key` résident dans un fichier Vault local non versionné.

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

La validation attend `/health/` et `/health/database/` en HTTP 200, puis une seconde exécution Ansible sans changement résiduel.
