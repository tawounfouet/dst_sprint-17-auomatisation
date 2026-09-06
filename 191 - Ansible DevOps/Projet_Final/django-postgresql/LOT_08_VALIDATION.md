# LOT 08 — Scripts d'exploitation et preuves

## Objectif

Industrialiser les opérations répétables du projet sans fabriquer de preuve d'exécution.

## Livrables

```text
ansible-project/scripts/
├── preflight.sh
├── deploy.sh
├── validate_runtime.sh
├── package.sh
└── README.md

evidence/
├── README.md
├── logs/
├── validation/
└── screenshots/
```

## Contrats

| ID | Contrôle | Statut code |
|---|---|---|
| OPS-01 | inventory graph | ✅ implémenté |
| OPS-02 | ping `app` + `database` | ✅ implémenté |
| OPS-03 | syntax-check `site.yml` | ✅ implémenté |
| OPS-04 | syntax-check `validate.yml` | ✅ implémenté |
| OPS-05 | déploiement journalisé | ✅ implémenté |
| OPS-06 | validation runtime journalisée | ✅ implémenté |
| OPS-07 | ZIP horodaté | ✅ implémenté |
| OPS-08 | SHA-256 | ✅ implémenté |
| OPS-09 | exclusion Vault / `.vault_pass` / clés / inventaire réel | ✅ implémenté |
| OPS-10 | preuves runtime réelles | ⏳ à exécuter |

## Sécurité du packaging

Le script exclut notamment :

```text
inventories/prod/hosts.yml
inventories/prod/host_vars/*.yml
inventories/prod/group_vars/vault.yml
.vault_pass*
.env*
.venv/
venv/
.ssh/
id_rsa*
id_ed25519*
*.pem
*.key
*.zip
```

Le ZIP n'est donc pas destiné à capturer des secrets ou des données d'infrastructure privées.

## Preuve runtime

Aucun fichier de log factice n'est créé dans ce lot. Les répertoires `evidence/` sont préparés avec `.gitkeep`; les preuves seront produites lors des exécutions réelles des lots de qualification.
