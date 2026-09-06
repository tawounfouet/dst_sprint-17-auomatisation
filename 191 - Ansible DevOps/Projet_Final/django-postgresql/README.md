# Projet Ansible — Django + PostgreSQL

Second projet applicatif complet du module 191. Il complète le projet PrestaShop/MySQL avec une stack Python moderne : **Nginx → Gunicorn → Django → PostgreSQL**.

## Statut

```text
IMPLEMENTATION           ✅
STATIC GATE              ✅
E2E TWO-HOST             ✅ GREEN
E2E MONO-HOST            ✅ GREEN
IDEMPOTENCE TWO-HOST     ✅ app1 changed=0 / db1 changed=0
IDEMPOTENCE MONO-HOST    ✅ server1 changed=0
PACKAGE                  ✅ ZIP + SHA-256
ARTIFACTS                ✅ GitHub Actions
FINAL REPORTS            ✅
```

### Qualification historique à deux hôtes

```text
Workflow : Ansible Django PostgreSQL E2E Final
Run      : #8 / 34052400653
Commit   : 2855c8f4daad1b8d962a576279ed7fd1c32dcb46
Artifact : 9994995760
```

Rapport : [`E2E_QUALIFICATION_REPORT.md`](./E2E_QUALIFICATION_REPORT.md).

### Qualification mono-serveur

```text
Workflow : Ansible Django PostgreSQL Mono-Host Qualification
Run      : #1 / 34057563053
Commit   : de3aa3ef4cf1843271722b65d27691fba78392ae
Artifact : 9996481488
```

Rapport : [`MONOHOST_E2E_QUALIFICATION_REPORT.md`](./MONOHOST_E2E_QUALIFICATION_REPORT.md).

> Les deux qualifications utilisent des cibles Ubuntu 24.04 isolées dans GitHub Actions, pilotées via `community.docker.docker`. Elles ne doivent pas être présentées comme une qualification de production publique via SSH.

## Architectures qualifiées

### Deux hôtes

```text
Client ──HTTP :80──► app1
                    Nginx
                      ↓
                    Gunicorn 127.0.0.1:8000
                      ↓
                    Django
                      │
                      │ psycopg / TCP 5432
                      ▼
                    db1
                    PostgreSQL
```

### Mono-serveur

```text
Internet / client
       │
       ▼
┌─────────────────────────────────┐
│ server1                         │
│                                 │
│ Nginx            :80            │
│      ↓                          │
│ Gunicorn         127.0.0.1:8000 │
│      ↓                          │
│ Django                          │
│      ↓                          │
│ PostgreSQL       127.0.0.1:5432 │
└─────────────────────────────────┘
```

La topologie mono-serveur correspond à la cible prévue pour une future VPS unique : Nginx exposé, Gunicorn et PostgreSQL strictement internes à la machine.

## Rôles

- `common` : socle système ;
- `postgresql` : serveur DB, base et utilisateur applicatif ;
- `django_app` : utilisateur système, code, **Python `venv` nommé `.venv`**, migrations, collectstatic et Gunicorn/systemd ;
- `nginx` : reverse proxy et fichiers statiques.

Les mêmes quatre rôles sont réutilisés dans les deux topologies.

## Contrats fonctionnels

L'application expose notamment :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

`/health/database/` exécute un vrai `SELECT 1` via Django et psycopg afin de qualifier la chaîne applicative jusqu'à PostgreSQL.

## Qualification réseau mono-host

La CI mono-serveur vérifie explicitement depuis le runner :

```text
server1:80   reachable=true
server1:8000 reachable=false
server1:5432 reachable=false
```

Le contrat cible est donc :

```text
Nginx       public/exposé
Gunicorn    localhost-only
PostgreSQL  localhost-only
```

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

Pour reproduire la qualification mono-host dans l'environnement CI prévu :

```bash
bash ansible-project/tests/e2e/run_monohost_qualification.sh
```

## Package mono-host qualifié

Archive du run mono-host de référence :

```text
django-postgresql-ansible-20260906-202147.zip
```

SHA-256 du ZIP projet :

```text
9ad407e6e1b1a6cd892c62a302a20d0907f60625ecc3240446fc65821624bc11
```

L'étape suivante pour une qualification réellement production-like est l'exécution sur **une VPS Ubuntu 24.04 distante via SSH**, avec firewall réel, DNS, HTTPS/Let's Encrypt, reboot/restart et sauvegarde/restauration PostgreSQL.
