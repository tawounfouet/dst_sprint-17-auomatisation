# Projet Ansible — Django + PostgreSQL

Second projet applicatif complet du module 191. Il complète le projet PrestaShop/MySQL avec une stack Python moderne : **Nginx → Gunicorn → Django → PostgreSQL**.

## Statut

```text
IMPLEMENTATION      ✅
STATIC GATE         ✅
E2E                 ✅ GREEN
IDEMPOTENCE         ✅ app1 changed=0 / db1 changed=0
PACKAGE             ✅ ZIP + SHA-256
ARTIFACT            ✅ GitHub Actions
FINAL REPORT        ✅
```

Référence finale :

```text
Workflow : Ansible Django PostgreSQL E2E Final
Run      : #8 / 34052400653
Commit   : 2855c8f4daad1b8d962a576279ed7fd1c32dcb46
Artifact : 9994995760
```

Le rapport canonique est [`E2E_QUALIFICATION_REPORT.md`](./E2E_QUALIFICATION_REPORT.md).

> La qualification E2E concerne le harness CI documenté : deux cibles Ubuntu 24.04 isolées pilotées par Ansible via `community.docker.docker`. Elle ne doit pas être présentée comme une qualification de production publique par SSH.

## Architecture

```text
Client ──HTTP :80──► Nginx ──► Gunicorn 127.0.0.1:8000 ──► Django
                                                              │
                                                              │ psycopg
                                                              ▼
                                                       PostgreSQL :5432
```

Deux hôtes sont ciblés : `app1` pour Nginx/Gunicorn/Django et `db1` pour PostgreSQL.

## Rôles

- `common` : socle système ;
- `postgresql` : serveur DB, base et utilisateur applicatif ;
- `django_app` : utilisateur système, code, **Python `venv` nommé `.venv`**, migrations, collectstatic et Gunicorn/systemd ;
- `nginx` : reverse proxy et fichiers statiques.

## Contrats fonctionnels

L'application expose notamment :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

`/health/database/` exécute un vrai `SELECT 1` via Django et psycopg afin de qualifier la chaîne applicative jusqu'à PostgreSQL.

## Quick start

```bash
cd ansible-project
ansible-galaxy collection install -r requirements.yml
cp inventories/prod/hosts.example.yml inventories/prod/hosts.yml
cp inventories/prod/host_vars/app1.example.yml inventories/prod/host_vars/app1.yml
cp inventories/prod/host_vars/db1.example.yml inventories/prod/host_vars/db1.yml
cp inventories/prod/group_vars/vault.example.yml inventories/prod/group_vars/vault.yml
ansible-vault encrypt inventories/prod/group_vars/vault.yml
./tests/static_checks.sh
./scripts/preflight.sh
./scripts/deploy.sh
./scripts/validate_runtime.sh
./scripts/package.sh
```

## Qualification finale

La chaîne de qualification est :

```text
static checks
      ↓
first site.yml
      ↓
runtime + HTTP + Django → PostgreSQL
      ↓
second site.yml
      ↓
changed=0 sur app1 et db1
      ↓
runtime post-idempotence
      ↓
ZIP
      ↓
SHA-256
      ↓
package safety gate
      ↓
GitHub Actions artifact
```

Archive projet du run final :

```text
django-postgresql-ansible-20260906-184304.zip
```

SHA-256 :

```text
022740bacb16ebdd0bd9edbf04fe568fddd550079db9e5a9f5c08edfe378c664
```
