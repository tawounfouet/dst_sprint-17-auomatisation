# Projet Ansible — Django + PostgreSQL

Second projet applicatif complet du module 191. Il complète le projet PrestaShop/MySQL avec une stack Python moderne : **Nginx → Gunicorn → Django → PostgreSQL**.

## Architecture

```text
Client ──HTTP :80──► Nginx ──► Gunicorn :8000 ──► Django
                                                   │
                                                   │ psycopg
                                                   ▼
                                            PostgreSQL :5432
```

Deux hôtes sont ciblés : `app1` pour Nginx/Gunicorn/Django et `db1` pour PostgreSQL.

## Rôles

- `common` : socle système ;
- `postgresql` : serveur DB, base et utilisateur applicatif ;
- `django_app` : utilisateur système, code, virtualenv, migrations, collectstatic et Gunicorn/systemd ;
- `nginx` : reverse proxy et static files.

## Quick start

```bash
cd ansible-project
ansible-galaxy collection install -r requirements.yml
cp inventories/prod/hosts.example.yml inventories/prod/hosts.yml
cp inventories/prod/host_vars/app1.example.yml inventories/prod/host_vars/app1.yml
cp inventories/prod/host_vars/db1.example.yml inventories/prod/host_vars/db1.yml
cp inventories/prod/group_vars/vault.example.yml inventories/prod/group_vars/vault.yml
ansible-vault encrypt inventories/prod/group_vars/vault.yml
./scripts/preflight.sh
./scripts/deploy.sh
./scripts/validate_runtime.sh
```
