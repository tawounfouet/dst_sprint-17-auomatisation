# Rapport de qualification E2E — Topologie mono-serveur

## Verdict

**GREEN ✅**

La stack **Nginx → Gunicorn → Django → PostgreSQL** a été qualifiée dans GitHub Actions sur **une seule cible Ubuntu 24.04 isolée avec systemd**, pilotée par Ansible via `community.docker.docker`.

Cette qualification complète la qualification historique à deux cibles `app1 + db1` sans la remplacer.

## Workflow canonique

- Workflow : `Ansible Django PostgreSQL Mono-Host Qualification`
- Run : `#1`
- Run ID : `34057563053`
- Job : `monohost-e2e`
- Job ID : `101552133343`
- Commit runtime qualifié : `de3aa3ef4cf1843271722b65d27691fba78392ae`
- Runner : Ubuntu 24.04
- Résultat : `success`

## Architecture qualifiée

```text
GitHub Actions runner
        │
        │ Ansible / community.docker.docker
        ▼
┌─────────────────────────────────┐
│ server1 — Ubuntu 24.04 + systemd│
│                                 │
│ Nginx            :80            │
│      │                          │
│      ▼                          │
│ Gunicorn         127.0.0.1:8000 │
│      │                          │
│      ▼                          │
│ Django                          │
│      │                          │
│      ▼                          │
│ PostgreSQL       127.0.0.1:5432 │
└─────────────────────────────────┘
```

Le même hôte d'inventaire `server1` appartient simultanément aux groupes `app` et `database`.

## Déploiement initial

Le premier `site.yml` a terminé avec :

```text
localhost : ok=1  changed=0  unreachable=0 failed=0
server1   : ok=52 changed=33 unreachable=0 failed=0
```

Les quatre rôles ont été appliqués sur la même cible :

```text
common
  ↓
postgresql
  ↓
django_app
  ↓
nginx
```

## Validation runtime

Après le premier déploiement :

```text
localhost : ok=1  changed=0 unreachable=0 failed=0
server1   : ok=19 changed=0 unreachable=0 failed=0
```

Les services ont été observés actifs :

```text
server1 nginx=active
server1 gunicorn=active
server1 postgresql=active
```

Les endpoints suivants ont été validés via Nginx :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

`/health/database/` a prouvé le chemin applicatif complet Django → psycopg → PostgreSQL → `SELECT 1`.

## Contrat réseau mono-host

La qualification a testé la joignabilité depuis le namespace réseau du runner vers l'adresse de `server1` :

```text
server1:80   reachable=true
server1:8000 reachable=false
server1:5432 reachable=false
```

Le contrat validé est donc :

```text
Nginx       :80            exposé à l'extérieur du conteneur
Gunicorn    127.0.0.1:8000 localhost-only
PostgreSQL  127.0.0.1:5432 localhost-only
```

Cela correspond à la cible prévue pour une future VPS mono-serveur : seuls les ports HTTP/HTTPS doivent être exposés publiquement ; Gunicorn et PostgreSQL restent internes à la machine.

## Idempotence stricte

Le même `site.yml` a été rejoué sur la même cible, sans reprovisionnement :

```text
localhost : ok=1  changed=0 unreachable=0 failed=0 skipped=0
server1   : ok=47 changed=0 unreachable=0 failed=0 skipped=1
```

Gate explicite :

```text
IDEMPOTENCE PASS: server1 changed=0
```

La validation runtime a ensuite été rejouée avec succès :

```text
server1 : ok=19 changed=0 unreachable=0 failed=0
```

Le contrat réseau a également été revérifié après le deuxième passage.

## Packaging et intégrité

Archive produite :

```text
django-postgresql-ansible-20260906-202147.zip
```

SHA-256 du package projet :

```text
9ad407e6e1b1a6cd892c62a302a20d0907f60625ecc3240446fc65821624bc11
```

Vérifications :

```text
sha256sum -c : PASS
PACKAGE SAFETY PASS
```

## Artefact GitHub Actions

- Nom : `ansible-django-postgresql-monohost-qualified-34057563053`
- Artifact ID : `9996481488`
- Taille : `80415` octets
- Rétention : 14 jours
- Expiration : `2026-09-20T20:21:47Z`
- Digest de l'enveloppe GitHub Actions :

```text
sha256:9dacbea9cf6497411a6815977ce08a9d67f71360ce4313f4f550fdfb80f18b3e
```

Le SHA-256 ci-dessus est celui de l'artefact GitHub Actions englobant les preuves et le package ; il est distinct du SHA-256 du ZIP projet qualifié.

## Portée de la preuve

Cette qualification démontre réellement :

- installation sur une cible Ubuntu 24.04 avec systemd ;
- application des rôles `common`, `postgresql`, `django_app`, `nginx` sur le même hôte ;
- PostgreSQL accessible localement par Django ;
- Gunicorn accessible localement par Nginx ;
- Nginx accessible depuis le runner ;
- santé Django et PostgreSQL ;
- `SELECT 1` applicatif ;
- non-exposition réseau de `8000` et `5432` ;
- idempotence stricte `server1 changed=0` ;
- packaging sécurisé et intégrité SHA-256.

## Limite

Cette qualification reste une qualification **CI/container mono-host**, et non encore une qualification d'une VPS publique réelle via SSH.

Elle ne prouve donc pas encore :

- SSH sur une VPS distante ;
- firewall VPS/cloud réel ;
- DNS public ;
- TLS/Let's Encrypt ;
- renouvellement de certificat ;
- sauvegarde/restauration PostgreSQL sur stockage persistant externe ;
- résilience après reboot d'une vraie VPS.

Ces points constituent la future qualification production-like sur VPS.
