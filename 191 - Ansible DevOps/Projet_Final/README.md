# Projet final Ansible — PrestaShop + MySQL

Ce projet constitue l’implémentation de référence de l’évaluation finale du module **191 — Ansible DevOps**.

## Besoin couvert

Le sujet DataScientest demande d’automatiser le déploiement d’un site e-commerce avec **PrestaShop** pour le serveur web et **MySQL** pour la base de données, en utilisant **deux rôles distincts** et en prouvant que le serveur web peut communiquer avec la base.

```text
Ansible control node
        │
        ├──────── SSH ────────► web1
        │                        └── rôle prestashop
        │                              └── HTTP :80
        │
        └──────── SSH ────────► db1
                                 └── rôle mysql
                                       └── MySQL :3306

web1 ───────────────────────────────► db1:3306
        connexion applicative MySQL
```

## Statut de qualification

Le repository contient une implémentation complète, des scripts de vérification et un mécanisme de capture des logs. La **qualification statique** peut être exécutée sans infrastructure distante. La **qualification runtime** exige deux machines Linux SSH joignables et n’est pas simulée dans ce dépôt.

## Démarrage rapide

```bash
cd ansible-project
ansible-galaxy collection install -r requirements.yml
cp inventories/prod/hosts.example.yml inventories/prod/hosts.yml
cp inventories/prod/host_vars/web1.example.yml inventories/prod/host_vars/web1.yml
cp inventories/prod/host_vars/db1.example.yml inventories/prod/host_vars/db1.yml
cp inventories/prod/group_vars/vault.example.yml inventories/prod/group_vars/vault.yml
ansible-vault encrypt inventories/prod/group_vars/vault.yml
./scripts/preflight.sh
./scripts/run_exam.sh
./scripts/validate_runtime.sh
```

## Livrable ZIP

```bash
./scripts/package_exam.sh
```

Le ZIP exclut les fichiers locaux sensibles (`hosts.yml`, `vault.yml`, `.vault_pass`, clés privées).
