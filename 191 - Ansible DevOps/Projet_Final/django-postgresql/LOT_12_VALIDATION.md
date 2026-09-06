# LOT 12 — Pipeline GitHub Actions E2E final

## Objectif

Transformer les qualifications GREEN des LOT 10 et LOT 11 en une barrière CI finale reproductible.

Le pipeline final prouve, dans un seul run GitHub Actions :

```text
static gate
   ↓
provision app1 + db1 Ubuntu 24.04
   ↓
first site.yml
   ↓
runtime validation + HTTP
   ↓
second site.yml
   ↓
app1 changed=0 / db1 changed=0
   ↓
runtime validation post-idempotence
   ↓
package projet
   ↓
SHA-256 verify
   ↓
package safety gate
   ↓
artifact final
```

## Gates

| ID | Contrôle | Résultat final |
|---|---|---|
| CI-01 | static checks | ✅ PASS |
| CI-02 | premier déploiement | ✅ `failed=0`, `unreachable=0` |
| CI-03 | runtime | ✅ PostgreSQL, Gunicorn et Nginx actifs |
| CI-04 | HTTP | ✅ `/`, `/health/`, `/health/database/`, `/api/info/` |
| CI-05 | SQL applicatif | ✅ `query=1` via Django |
| CI-06 | deuxième déploiement | ✅ exit code 0 |
| CI-07 | idempotence app1 | ✅ `changed=0` |
| CI-08 | idempotence db1 | ✅ `changed=0` |
| CI-09 | packaging | ✅ ZIP produit |
| CI-10 | intégrité | ✅ `sha256sum -c` PASS |
| CI-11 | sécurité artefact | ✅ package safety PASS |
| CI-12 | artefact final | ✅ upload GitHub Actions réussi |

## Hardening inclus

Le LOT 12 supprime également les avertissements Ansible/PostgreSQL observés pendant LOT 10/11 :

- utilisation de `ansible_facts[...]` au lieu des facts injectés historiques ;
- utilisation de `login_db` au lieu de l'alias PostgreSQL `db` déprécié.

Ces changements ont été requalifiés dans le run final complet.

## Packaging

`scripts/package.sh` accepte `PACKAGE_OUTPUT_DIR` pour permettre à la CI de produire le ZIP dans un répertoire éphémère contrôlé. Les fichiers `*.example.yml` restent inclus, tandis que les fichiers runtime réels restent exclus.

`tests/package_safety_check.sh` inspecte le contenu du ZIP, vérifie les fichiers indispensables et refuse notamment :

```text
.vault_pass*
inventories/prod/hosts.yml
inventories/prod/group_vars/vault.yml
inventories/prod/host_vars/app1.yml
inventories/prod/host_vars/db1.yml
id_rsa*
id_ed25519*
*.pem
*.key
.env*
.venv/
venv/
```

## Qualification finale observée

Workflow :

```text
Ansible Django PostgreSQL E2E Final
```

Run GitHub Actions :

```text
run number : #8
run ID     : 34052400653
commit     : 2855c8f4daad1b8d962a576279ed7fd1c32dcb46
runner     : Ubuntu 24.04.4 LTS
Ansible    : ansible-core 2.20.8
PostgreSQL collection : community.postgresql 4.2.0
Docker collection     : community.docker 4.8.8
status     : success
```

### Premier déploiement

```text
app1      : ok=37 changed=24 unreachable=0 failed=0
 db1      : ok=23 changed=13 unreachable=0 failed=0
localhost : ok=1  changed=0  unreachable=0 failed=0
```

### Validation runtime

```text
app1      : ok=13 changed=0 unreachable=0 failed=0
 db1      : ok=6  changed=0 unreachable=0 failed=0
localhost : ok=1  changed=0 unreachable=0 failed=0
```

### Deuxième déploiement — idempotence stricte

```text
app1      : ok=34 changed=0 unreachable=0 failed=0 skipped=1
 db1      : ok=21 changed=0 unreachable=0 failed=0
localhost : ok=1  changed=0  unreachable=0 failed=0
```

Le harness a explicitement produit :

```text
IDEMPOTENCE PASS: app1 changed=0
IDEMPOTENCE PASS: db1 changed=0
LOT 11 strict idempotence qualification passed.
```

La validation runtime post-idempotence est également restée GREEN.

## ZIP qualifié

Archive interne du projet :

```text
django-postgresql-ansible-20260906-184304.zip
```

SHA-256 du ZIP projet :

```text
022740bacb16ebdd0bd9edbf04fe568fddd550079db9e5a9f5c08edfe378c664
```

La CI a exécuté :

```text
<archive>: OK
PACKAGE SAFETY PASS
```

## Artefact GitHub Actions final

```text
name        : ansible-django-postgresql-qualified-34052400653
artifact ID : 9994995760
size        : 69139 bytes
expires     : 2026-09-20T18:43:04Z
```

Digest SHA-256 de l'artefact GitHub Actions :

```text
06b6712b71e35d7df6443655423cfba177dcd94605b04efba284758d31bd80d0
```

Le digest de l'artefact GitHub Actions est distinct du SHA-256 du ZIP projet, car l'action `upload-artifact` encapsule le ZIP projet, son fichier `.sha256`, le manifest et les preuves de qualification dans son propre artefact ZIP.

## Limites de la preuve

Cette qualification est une preuve d'intégration/E2E sur deux cibles Ubuntu 24.04 systemd isolées dans Docker, pilotées via `community.docker.docker`. Elle ne constitue pas une qualification d'un déploiement public via SSH ni d'une infrastructure de production exposée sur Internet.

## Statut

**LOT 12 GREEN ✅**

Le pipeline CI final prouve désormais le déploiement, la validation fonctionnelle, l'idempotence stricte, le packaging, l'intégrité SHA-256 et la sécurité minimale de l'artefact.
