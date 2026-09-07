# Scripts d'exploitation

## `secret_hygiene.py`

Scanner de sécurité réutilisable par le repository, les logs et les ZIP.

Modes :

```bash
python3 scripts/secret_hygiene.py repo
python3 scripts/secret_hygiene.py tree ../evidence/logs
python3 scripts/secret_hygiene.py archive /tmp/package.zip
```

Le scanner refuse notamment les vrais `vault.yml`, `.env.runtime`, `.vault_pass`, clés privées et plusieurs formats de tokens à forte confiance. Il ne réaffiche jamais la valeur détectée.

Pour les qualifications CI, un fichier local protégé contenant des valeurs canaris/secrets éphémères pourra être passé sans les mettre en ligne de commande :

```bash
python3 scripts/secret_hygiene.py tree /path/to/logs \
  --secret-values-file /protected/path/secret-values.txt
```

Le fichier de valeurs est ignoré par Git et ne doit jamais être archivé.

## `preflight.sh`

Utilise `DEPLOYMENT_ENV=dev|stg|prod`, vérifie l'inventaire et le Vault correspondants, lance le scan repository, installe les collections, affiche le graphe, exécute le ping Ansible et les syntax checks.

## `deploy.sh`

Exécute `site.yml`, conserve la sortie sous `evidence/logs/`, puis scanne le log même lorsque le playbook échoue. `SECRET_VALUES_FILE` peut renforcer la détection par comparaison exacte avec des secrets/canaris locaux sans les afficher.

## `validate_runtime.sh`

Même principe pour `validate.yml` et `evidence/validation/`. La validation Compose complète sera refondue dans DC-10 ; le scan anti-fuite est déjà branché.

## `package.sh`

Avant packaging : scan du repository. Après création : scan du ZIP. Le package exclut les inventories réels des trois environnements, Vault, `.vault_pass`, `.env.runtime`, clés privées et fichiers de valeurs de scan. Le SHA-256 n'est généré qu'après validation du contenu de l'archive.

## Variables communes

```text
DEPLOYMENT_ENV     dev | stg | prod
ANSIBLE_INVENTORY  surcharge facultative de l'inventory
SECRET_VALUES_FILE fichier local facultatif pour recherche exacte dans logs
```

`.vault_pass`, les vrais Vaults, les inventories privés et les fichiers de valeurs restent hors Git.
