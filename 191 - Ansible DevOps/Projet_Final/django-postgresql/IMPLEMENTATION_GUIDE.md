# Guide d'implémentation

Le playbook applique successivement `common` à tous les hôtes, `postgresql` au groupe `database`, puis `django_app` et `nginx` au groupe `app`.

Les secrets `vault_postgresql_password` et `vault_django_secret_key` résident dans un fichier Vault local non versionné.

La validation attend `/health/` et `/health/database/` en HTTP 200, puis une seconde exécution Ansible sans changement résiduel.
