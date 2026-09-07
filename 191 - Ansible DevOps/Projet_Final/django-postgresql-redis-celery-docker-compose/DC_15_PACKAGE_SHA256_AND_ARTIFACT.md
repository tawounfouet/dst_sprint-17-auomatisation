# DC-15 — Package + SHA-256 + Artifact

## Statut

```text
PACKAGE SCRIPT HARDENING           ✅ IMPLEMENTED
REPOSITORY SECRET SCAN             ✅ IMPLEMENTED
ARCHIVE SECRET SCAN                ✅ IMPLEMENTED
PORTABLE SHA-256 SIDECAR           ✅ IMPLEMENTED
PACKAGE PROVENANCE MANIFEST        ✅ IMPLEMENTED
GITHUB ACTIONS ARTIFACT WORKFLOW   ⏳
PACKAGE RUN GREEN                  ⏳
ARTIFACT UPLOAD GREEN              ⏳
FINAL ZIP SHA-256                  ⏳
```

DC-15 transforme le projet qualifié DC-00 → DC-14 en un **livrable transportable, traçable et contrôlé contre les fuites de secrets**.

## Contrat de packaging

Le package canonique doit contenir le projet :

```text
django-postgresql-redis-celery-docker-compose/
```

sans les matériaux runtime sensibles ou locaux.

Le pipeline applique :

```text
tracked repository
      ↓
secret_hygiene.py repo
      ↓
ZIP source
      ↓
secret_hygiene.py archive
      ↓
SHA-256 portable
      ↓
manifest de provenance
      ↓
scan des sidecars
      ↓
GitHub Actions artifact
```

Le SHA-256 n'est donc émis **qu'après** le passage du scan de l'archive.

## Exclusions de sécurité

Le package exclut explicitement notamment :

```text
inventories/*/hosts.yml
inventories/*/host_vars/server1.yml
inventories/*/group_vars/vault.yml
.vault_pass*
.env / .env.dev / .env.stg / .env.prod / .env.runtime
secret-values.*
clés SSH privées
*.pem / *.key
logs runtime
caches Python
.git / .ssh
anciens ZIP / checksums / manifests
artifacts, dist, build et evidence/logs
```

Les fichiers d'exemple versionnés restent autorisés lorsqu'ils ne contiennent que des placeholders contrôlés.

## Sidecars produits

Pour un package :

```text
django-postgresql-redis-celery-docker-compose-ansible-<id>.zip
```

DC-15 produit :

```text
<archive>.zip
<archive>.zip.sha256
<archive>.zip.manifest.json
```

Le fichier `.sha256` contient un chemin portable basé uniquement sur le nom du ZIP.

Le manifest JSON contient :

```text
schema_version
project
archive
sha256
size_bytes
source_commit
source_ref
generated_at_utc
```

Il ne contient aucun secret runtime.

## Traçabilité

Le package doit être rattaché au commit Git exact qui l'a produit. Le workflow GitHub Actions utilisera un nom d'archive dérivé du commit source afin d'éviter l'ambiguïté entre deux builds.

La validation finale consignera séparément :

```text
SHA-256 du ZIP projet             → intégrité du livrable utilisateur
GitHub artifact ID                → identité de l'enveloppe Actions
GitHub artifact digest éventuel   → intégrité de l'enveloppe Actions
```

Le digest de l'enveloppe GitHub Actions ne doit jamais être confondu avec le SHA-256 du ZIP projet inclus dans cette enveloppe.

## Reproductibilité

Le script utilise `zip -X` pour retirer les métadonnées ZIP supplémentaires. DC-15 garantit une **traçabilité cryptographique du package produit**, mais ne revendique pas encore une reproductibilité bit-à-bit entre deux exécutions distinctes : les timestamps de fichiers ZIP et le timestamp du manifest peuvent différer.

## Workflow cible

```text
.github/workflows/
└── ansible-django-postgresql-redis-celery-docker-compose-package.yml
```

Le workflow doit :

```text
checkout commit exact
→ exécuter package.sh
→ vérifier sha256sum -c
→ rescanner les fichiers de sortie
→ uploader ZIP + SHA-256 + manifest
→ échouer si un fichier manque
```

## Critères de clôture

DC-15 ne sera marqué GREEN qu'après observation d'un run GitHub Actions réussi avec :

```text
PACKAGE_SECRET_SCAN_PASS
PACKAGE_CHECKSUM_PASS
PACKAGE_MANIFEST_PASS
PACKAGE_ARTIFACT_UPLOAD_PASS
```

et récupération des métadonnées réelles de l'artifact.

## Prochain jalon

Après qualification réelle de DC-15 :

```text
DC-16 — Final Qualification Report + 12-Factor Matrix
```
