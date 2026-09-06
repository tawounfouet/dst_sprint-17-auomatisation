# Guide d'implémentation

Le point d'entrée du déploiement est désormais :

```text
ansible-project/playbooks/site.yml
```

L'orchestration applique successivement :

```text
validation topologie
        ↓
common sur tous les hôtes
        ↓
postgresql sur le groupe database
        ↓
django_app sur le groupe app
        ↓
nginx sur le groupe app
```

Les secrets `vault_postgresql_password` et `vault_django_secret_key` résident dans un fichier Vault local non versionné :

```text
inventories/prod/group_vars/vault.yml
```

Les plays PostgreSQL et Django chargent ce fichier explicitement avec `vars_files`. Le fichier doit être créé à partir de `vault.example.yml`, puis chiffré avec `ansible-vault`.

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

## Exécution

Depuis `ansible-project/` :

```bash
ansible-playbook playbooks/site.yml --syntax-check --ask-vault-pass
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Les quatre rôles restent séparés afin que chaque tier conserve sa responsabilité propre.

La validation finale attend `/health/` et `/health/database/` en HTTP 200, puis une seconde exécution Ansible sans changement résiduel. Ces contrôles appartiennent aux lots de validation suivants et ne sont pas déclarés réussis à ce stade.
