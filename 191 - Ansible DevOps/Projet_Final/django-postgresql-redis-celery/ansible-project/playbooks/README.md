# Playbooks — Django + PostgreSQL

## `site.yml`

`site.yml` est le point d'entrée d'orchestration du projet.

Ordre volontaire :

```text
Topology validation
        ↓
common          → app1 + db1
        ↓
postgresql      → db1
        ↓
django_app      → app1
        ↓
nginx           → app1
```

Le projet cible actuellement exactement deux hôtes logiques : un hôte `app` et un hôte `database`. Le premier play refuse une topologie différente afin d'éviter que les variables fondées sur `groups['app'][0]` et `groups['database'][0]` ne deviennent ambiguës.

## Vault explicite

Les plays PostgreSQL et Django chargent explicitement :

```text
../inventories/prod/group_vars/vault.yml
```

Ce fichier doit être créé localement à partir de `vault.example.yml`, chiffré avec `ansible-vault`, et ne doit jamais être commité.

Exemple :

```bash
cp inventories/prod/group_vars/vault.example.yml inventories/prod/group_vars/vault.yml
ansible-vault encrypt inventories/prod/group_vars/vault.yml
```

## Syntax check

Depuis `ansible-project/` :

```bash
ansible-playbook playbooks/site.yml --syntax-check --ask-vault-pass
ansible-playbook playbooks/validate.yml --syntax-check
```

ou avec un fichier de mot de passe Vault local et ignoré par Git :

```bash
ansible-playbook playbooks/site.yml \
  --syntax-check \
  --vault-password-file .vault_pass
```

## Déploiement complet

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## Validation runtime

Après un déploiement :

```bash
ansible-playbook playbooks/validate.yml
```

`validate.yml` ne modifie pas le système cible et ne recharge pas les secrets Vault. Il vérifie :

```text
PostgreSQL actif + :5432
base django_app
rôle django_app
Gunicorn actif + :8000
Nginx actif + nginx -t + :80
app1 → db1:5432
GET /
GET /health/
GET /health/database/
GET /api/info/
```

Le contrôle `/health/database/` est la preuve fonctionnelle principale du chemin Django → PostgreSQL et du `SELECT 1` réel exécuté par l'application.

## Exécution sélective

```bash
ansible-playbook playbooks/site.yml --tags common --ask-vault-pass
ansible-playbook playbooks/site.yml --tags postgresql --ask-vault-pass
ansible-playbook playbooks/site.yml --tags django --ask-vault-pass
ansible-playbook playbooks/site.yml --tags nginx --ask-vault-pass
ansible-playbook playbooks/validate.yml --tags database
ansible-playbook playbooks/validate.yml --tags app
```

Le tag `always` du play de validation de topologie garantit que le contrat d'inventaire reste contrôlé lors des exécutions partielles.
