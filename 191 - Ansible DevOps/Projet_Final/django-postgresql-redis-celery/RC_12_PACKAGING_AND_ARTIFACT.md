# RC-12 — Packaging qualifié + Artifact GitHub Actions

## Statut

**GREEN ✅ — GITHUB ACTIONS QUALIFIÉ**

RC-12 transforme la stack qualifiée en un livrable portable et contrôlé : archive ZIP, checksum SHA-256, contrôle de sûreté du contenu et artifact GitHub Actions.

## Run canonique

```text
workflow : Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
run      : #4
run ID   : 34099796947
job ID   : 101671354038
commit   : a7efa47d66a9b564bd36753f1dbdccbcb5cb7977
status   : success
runner   : Ubuntu 24.04.4
Python   : 3.12.14
Ansible  : ansible-core 2.20.8
```

Le run a rejoué RC-10 et RC-11 avant de construire le package. Le second `site.yml` est resté strictement idempotent :

```text
server1 : ok=73 changed=0 unreachable=0 failed=0 skipped=3
IDEMPOTENCE PASS: server1 changed=0
```

La validation post-idempotence est également restée GREEN :

```text
server1 : ok=37 changed=0 unreachable=0 failed=0
```

## Livrable produit

```text
django-postgresql-redis-celery-ansible-20260907-082219.zip
```

SHA-256 du ZIP projet :

```text
558ef15ee8de57bf9d4ea09edcbdc586ff5a01c423c538de79119fb85df8ab8f
```

La CI a exécuté :

```text
sha256sum -c  → OK
PACKAGE SAFETY PASS
```

## Sécurité du package

Le package exclut les éléments runtime ou sensibles connus :

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

Les exemples nécessaires au réemploi restent inclus :

```text
hosts.example.yml
host_vars/server1.example.yml
group_vars/vault.example.yml
```

Le gate exige également la présence des rôles Redis, Celery Worker et Celery Beat, du harness E2E et des playbooks `site.yml` / `validate.yml`.

## Artifact GitHub Actions

```text
name       : ansible-django-postgresql-redis-celery-qualified-34099796947
artifact ID: 10010158233
size       : 114672 bytes
created    : 2026-09-07T08:22:19Z
expires    : 2026-09-21T08:22:19Z
```

Digest de l'enveloppe GitHub Artifact :

```text
sha256:e70b25c19c0bbd5d0d69a5a20213398a6dd4b0ba157f3198b8e9febaf020f07c
```

Téléchargement de l'artifact :

```text
https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34099796947/artifacts/10010158233
```

Attention : les deux empreintes ne représentent pas le même objet :

```text
558ef15e...ab8f → ZIP projet qualifié
e70b25c1...f07c → enveloppe ZIP de l'artifact GitHub Actions
```

## Manifest CI RC-12

Le manifest final enregistre :

```text
topology=single-server
inventory_host=server1
roles=common,postgresql,redis,django_app,celery,celery_beat,nginx
postgresql=127.0.0.1:5432
redis=127.0.0.1:6379
gunicorn=127.0.0.1:8000
nginx=0.0.0.0:80
celery_worker=datascientest-celery
celery_beat=datascientest-celery-beat
async_add=21+21->42
async_database_probe=SELECT 1
beat_schedule=datascientest-demo-heartbeat
network_contract=80:true,8000:false,5432:false,6379:false
idempotence_server1=changed=0
post_idempotence_runtime=green
package_safety=pass
rc10=green
rc11=green
rc12=green
```

## Definition of Done RC-12

```text
nom d'archive spécifique à la variante          ✅
ZIP généré après qualification E2E               ✅
SHA-256 généré                                   ✅
sha256sum -c                                      ✅
package safety check                             ✅
runtime inventory / Vault exclus                 ✅
artifact GitHub Actions                          ✅
run RC-12 GREEN                                  ✅
ZIP final + SHA observés                         ✅
artifact ID / digest observés                    ✅
```

RC-12 est fermé. Le dernier jalon est RC-13 — rapport final de qualification et clôture de la variante Django + PostgreSQL + Redis + Celery + Beat.
