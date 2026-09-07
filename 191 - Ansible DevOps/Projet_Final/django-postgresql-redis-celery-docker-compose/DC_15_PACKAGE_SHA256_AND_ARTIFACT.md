# DC-15 — Package + SHA-256 + Artifact

## Statut

```text
PACKAGE SCRIPT HARDENING           ✅ IMPLEMENTED
REPOSITORY SECRET SCAN             ✅ GREEN
ARCHIVE SECRET SCAN                ✅ GREEN
PORTABLE SHA-256 SIDECAR           ✅ GREEN
PACKAGE PROVENANCE MANIFEST        ✅ GREEN
GITHUB ACTIONS ARTIFACT WORKFLOW   ✅ IMPLEMENTED
PACKAGE RUN GREEN                  ✅
ARTIFACT UPLOAD GREEN              ✅
FINAL ZIP SHA-256                  ✅ VERIFIED
```

DC-15 transforme le projet qualifié DC-00 → DC-14 en un **livrable transportable, traçable et contrôlé contre les fuites de secrets**.

## Qualification canonique

```text
Workflow : Ansible Django PostgreSQL Redis Celery Compose Package
Run      : #2
Run ID   : 34166857587
Job ID   : 101879516829
Commit   : 6a8e7cfaf638bedbae2fe2412dafad2aac824ff6
Result   : SUCCESS
Runner   : GitHub-hosted Ubuntu 24.04.4 LTS
Python   : 3.12.14
Zip      : Info-ZIP 3.0
sha256sum: GNU coreutils 9.4
```

Le premier run DC-15 avait déjà construit et contrôlé le ZIP avec succès, mais l'upload échouait parce que le staging directory `.dc15-artifact` était masqué et `actions/upload-artifact@v4` n'inclut pas les fichiers cachés par défaut. La correction utilise le répertoire visible `dc15-artifact`, sans élargir les règles d'upload aux fichiers cachés.

## Package canonique

```text
Archive : django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip
Size    : 260647 bytes
SHA-256 : bb4c2dfe6cb3bf16a290e4546ab432ac6d62b76113e07f0e18502816574c5298
```

Le checksum a été vérifié une première fois dans GitHub Actions :

```text
django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip: OK
PACKAGE_CHECKSUM_PASS
```

Puis le package téléchargé depuis l'artifact GitHub Actions a été extrait et le même fichier `.zip.sha256` a été revérifié localement avec succès. Le SHA-256 observé après téléchargement reste exactement :

```text
bb4c2dfe6cb3bf16a290e4546ab432ac6d62b76113e07f0e18502816574c5298
```

## Artifact GitHub Actions

```text
Artifact ID     : 10034425511
Artifact name   : dc15-django-postgresql-redis-celery-docker-compose-6a8e7cfaf638bedbae2fe2412dafad2aac824ff6
Artifact size   : 262010 bytes
Created         : 2026-09-07T22:29:53Z
Expires         : 2026-09-21T22:29:53Z
Expired         : false
Artifact digest : sha256:389b62ca502247699ad1ee1a8172e2fb4dd4e99a308b38ec8c3a77f97b87dc25
```

Le digest `389b62...` correspond à **l'enveloppe ZIP GitHub Actions** générée par `upload-artifact`. Il ne doit pas être confondu avec le SHA-256 `bb4c2d...` du ZIP projet contenu dans cette enveloppe.

L'enveloppe GitHub Actions contient exactement trois fichiers :

```text
django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip
django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip.sha256
django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip.manifest.json
```

## Contrat de packaging

Le package canonique contient le projet :

```text
django-postgresql-redis-celery-docker-compose/
```

sans les matériaux runtime sensibles ou locaux.

Le pipeline réellement exécuté est :

```text
tracked repository
      ↓
secret_hygiene.py repo
      ↓
ZIP source avec zip -X
      ↓
secret_hygiene.py archive
      ↓
SHA-256 portable
      ↓
manifest de provenance
      ↓
scan des sidecars
      ↓
sha256sum -c
      ↓
second archive/tree scan dans le workflow
      ↓
actions/upload-artifact@v4
```

Le SHA-256 n'est donc émis **qu'après** passage du scan de l'archive.

## Preuves anti-secret observées

Le run canonique contient :

```text
SECRET_HYGIENE_PASS: repo
SECRET_HYGIENE_PASS: archive
SECRET_HYGIENE_PASS: tree
PACKAGE_SECRET_SCAN_PASS
```

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

DC-15 produit :

```text
<archive>.zip
<archive>.zip.sha256
<archive>.zip.manifest.json
```

Le fichier `.sha256` contient un chemin portable basé uniquement sur le nom du ZIP :

```text
bb4c2dfe6cb3bf16a290e4546ab432ac6d62b76113e07f0e18502816574c5298  django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip
```

Le manifest observé contient :

```json
{
  "archive": "django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip",
  "generated_at_utc": "2026-09-07T22:29:52Z",
  "project": "django-postgresql-redis-celery-docker-compose",
  "schema_version": 1,
  "sha256": "bb4c2dfe6cb3bf16a290e4546ab432ac6d62b76113e07f0e18502816574c5298",
  "size_bytes": 260647,
  "source_commit": "6a8e7cfaf638bedbae2fe2412dafad2aac824ff6",
  "source_ref": "feat/ansible-django-postgresql-redis-celery-docker-compose"
}
```

Le workflow valide explicitement la correspondance entre `source_commit`, `GITHUB_SHA`, le nom de l'archive, le SHA-256 et la taille positive :

```text
PACKAGE_MANIFEST_PASS
```

## Traçabilité

Le package est rattaché au commit Git exact qui l'a produit :

```text
6a8e7cfaf638bedbae2fe2412dafad2aac824ff6
```

Les trois identités restent séparées :

```text
Git source commit
→ 6a8e7cfaf638bedbae2fe2412dafad2aac824ff6

ZIP projet
→ sha256:bb4c2dfe6cb3bf16a290e4546ab432ac6d62b76113e07f0e18502816574c5298

GitHub Actions artifact envelope
→ ID 10034425511
→ sha256:389b62ca502247699ad1ee1a8172e2fb4dd4e99a308b38ec8c3a77f97b87dc25
```

## Reproductibilité

Le script utilise `zip -X` pour retirer les métadonnées ZIP supplémentaires. DC-15 garantit une **traçabilité cryptographique du package produit**, mais ne revendique pas une reproductibilité bit-à-bit entre deux exécutions distinctes : les timestamps de fichiers ZIP et le timestamp du manifest peuvent différer.

## Workflow

```text
.github/workflows/
└── ansible-django-postgresql-redis-celery-docker-compose-package.yml
```

Le run canonique a produit les marqueurs :

```text
PACKAGE_CHECKSUM_PASS
PACKAGE_SECRET_SCAN_PASS
PACKAGE_MANIFEST_PASS
DC15_PACKAGE_PASS
PACKAGE_ARTIFACT_UPLOAD_PASS
DC15_PACKAGE_ARTIFACT_PASS
```

## Périmètre de la preuve

DC-15 qualifie le **package source du projet** et son intégrité. Il ne signe pas encore le package avec une identité cryptographique (Sigstore/GPG), ne publie pas une release GitHub versionnée et ne fournit pas de SBOM ou d'attestation SLSA. Ces sujets relèvent d'un éventuel durcissement supply-chain ultérieur et ne sont pas nécessaires au périmètre du sprint Ansible actuel.

## Verdict

```text
DC-15 PACKAGE + SHA-256 + ARTIFACT = GREEN
```

## Prochain jalon

```text
DC-16 — Final Qualification Report + 12-Factor Matrix
```
