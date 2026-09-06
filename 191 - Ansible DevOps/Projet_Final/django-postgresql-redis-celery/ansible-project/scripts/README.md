# Scripts d'exploitation

## `preflight.sh`

Vérifie l'inventaire, installe les collections déclarées, affiche le graphe, exécute le ping Ansible et les syntax checks de `site.yml` et `validate.yml`.

## `deploy.sh`

Exécute `site.yml` et conserve la sortie sous `evidence/logs/deploy-<timestamp>.txt`.

## `validate_runtime.sh`

Exécute `validate.yml` et conserve la sortie sous `evidence/validation/runtime-<timestamp>.txt`.

## `package.sh`

Produit un ZIP horodaté et son SHA-256 en excluant explicitement inventaire réel, Vault, mot de passe Vault, environnements Python, clés privées, fichiers `.env` et anciens ZIP.

Les scripts acceptent `ANSIBLE_INVENTORY` pour surcharger l'inventaire par défaut. `.vault_pass`, lorsqu'il existe localement, est utilisé par les commandes qui doivent déchiffrer le Vault ; il reste ignoré par Git et exclu du packaging.
