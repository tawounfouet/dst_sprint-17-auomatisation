# RC-12 — Packaging qualifié + Artifact GitHub Actions

## Statut

**IMPLÉMENTÉ ✅ — QUALIFICATION GITHUB ACTIONS ⏳**

RC-12 transforme la stack qualifiée en livrable portable et contrôlé : archive ZIP, checksum SHA-256, contrôle de sûreté du contenu et artifact GitHub Actions.

## Objectif

À l'issue d'un run GREEN RC-10 + RC-11, le workflow doit produire :

```text
django-postgresql-redis-celery-ansible-<timestamp>.zip
django-postgresql-redis-celery-ansible-<timestamp>.zip.sha256
package.log
preuves E2E
manifest CI RC-12
```

## Script de packaging

Le script :

```text
ansible-project/scripts/package.sh
```

utilise `PACKAGE_OUTPUT_DIR` lorsqu'il est fourni par la CI et génère désormais une archive spécifique à cette variante :

```text
django-postgresql-redis-celery-ansible-YYYYMMDD-HHMMSS.zip
```

Les éléments runtime ou sensibles sont exclus :

```text
inventories/prod/hosts.yml
inventories/prod/host_vars/server1.yml
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
```

Les fichiers d'exemple (`hosts.example.yml`, `server1.example.yml`, `vault.example.yml`) restent livrés.

## Contrôle de sûreté

Le script :

```text
ansible-project/tests/package_safety_check.sh
```

vérifie d'abord l'intégrité ZIP, puis exige la présence des composants critiques :

```text
README.md
Django manage.py
site.yml
validate.yml
harness E2E Redis/Celery/Beat
inventaire d'exemple mono-host
Vault example
rôle Redis
rôle Celery Worker
rôle Celery Beat
```

Il refuse ensuite les fichiers runtime ou secrets connus.

Le gate attendu est :

```text
PACKAGE SAFETY PASS
```

## Pipeline RC-12

Le workflow :

```text
.github/workflows/ansible-django-postgresql-redis-celery-monohost.yml
```

enchaîne désormais :

```text
static gate
   ↓
first deployment
   ↓
runtime E2E
   ↓
second deployment changed=0
   ↓
post-idempotence E2E
   ↓
package.sh
   ↓
sha256sum -c
   ↓
package_safety_check.sh
   ↓
manifest RC-12
   ↓
GitHub Actions artifact
```

## Manifest CI

Le manifest final enregistre notamment :

```text
run_id
git_sha
topology
7 rôles
ports localhost-only
async_add=21+21->42
async_database_probe=SELECT 1
beat_schedule=datascientest-demo-heartbeat
idempotence_server1=changed=0
archive=<nom ZIP>
sha256=<digest projet>
package_safety=pass
rc10=green
rc11=green
rc12=green
```

## Definition of Done RC-12

```text
nom d'archive spécifique à la variante          ✅ implémenté
ZIP généré après qualification E2E               ✅ pipeline
SHA-256 généré                                   ✅ pipeline
sha256sum -c                                      ✅ pipeline
package safety check                             ✅ pipeline
runtime inventory / Vault exclus                 ✅ implémenté
artifact GitHub Actions                          ✅ pipeline
run RC-12 GREEN                                  ⏳ preuve CI
ZIP final + SHA observés                         ⏳ preuve CI
artifact ID / digest observés                    ⏳ preuve CI
```

Le jalon sera fermé uniquement après observation d'un run GitHub Actions GREEN et lecture des métadonnées de l'artifact produit.
