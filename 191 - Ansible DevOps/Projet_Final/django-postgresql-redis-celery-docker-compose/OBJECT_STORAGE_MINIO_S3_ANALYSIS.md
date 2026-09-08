# Analyse Architecturale — Gestion des Médias via Object Storage S3 (MinIO / Cloud S3)

## Contexte et Objectifs

Ce document formalise l'analyse architecturale et la stratégie d'implémentation pour étendre la pile **Django/DRF + PostgreSQL + Redis + Celery + Docker Compose + Ansible** avec un service de gestion des fichiers médias basé sur le stockage d'objets (*Object Storage*).

Le besoin exprimé est le suivant :
* **DEV Full & STAGING** : Fournir une émulation de stockage S3 locale, autonome et isolée via un conteneur **MinIO**, analogue à la gestion conteneurisée de PostgreSQL et Redis.
* **PRODUCTION** : S'appuyer sur un service managé d'**Object Storage S3-compatible cloud** (AWS S3, Scaleway Object Storage, Cloudflare R2, GCP Cloud Storage en mode interopérabilité S3, OVHcloud, etc.).
* **DEV Lite** (sans Docker / environnement local minimal) : Permettre un repli gracieux (*graceful fallback*) sur le système de fichiers local (`FileSystemStorage`) si MinIO/S3 n'est pas actif.

---

## 1. Alignement avec les Principes 12-Factor App

L'intégration de l'Object Storage renforce la conformité cloud-native de la pile sur plusieurs facteurs fondamentaux :

| Principe 12-Factor | Règle | Application à l'Object Storage |
|---|---|---|
| **Facteur III (Config)** | La configuration varie d'un environnement à l'autre mais le code reste identique. | L'application Django s'appuie sur `django-environ`. Aucune URL ni clé S3 en dur. |
| **Facteur IV (Backing Services)** | Les services d'appui sont traités comme des ressources attachées. | MinIO et AWS S3 utilisent le même protocole S3 via des URLs et identifiants injectés au runtime. |
| **Facteur VI (Processes)** | Les processus sont sans état (*stateless*) et ne partagent rien (*share-nothing*). | **Élimination totale des volumes partagés** (NFS, bind mounts partagés) entre les conteneurs `web` et `worker`. |
| **Facteur VII (Port Binding)** | Les services exportent leurs fonctionnalités via des liaisons de ports. | MinIO expose son API S3 sur le port interne `9000` au sein du réseau Docker `backend`. |
| **Facteur X (Dev/Prod Parity)** | Maintenir une parité maximale entre développement et production. | MinIO reproduit fidèlement la sémantique de l'API S3 d'AWS en DEV Full et STAGING. |

---

## 2. Schéma d'Architecture Cible

```text
                                             ┌──► [DEV Lite] (Offline)
                                             │    └──► FileSystemStorage local (mediafiles/)
                                             │
Django (Web / Gunicorn)                      ├──► [DEV Full] (Docker Compose local)
         │                                   │    ├──► MinIO API (:9000) (Réseau backend)
         │ django-storages (boto3)           │    ├──► MinIO Console (:9001) (127.0.0.1:9001)
         ▼                                   │    └──► Volume Docker: minio_data
API Standard S3 ─────────────────────────────┤
         ▲                                   ├──► [STAGING] (STG-like CI / Hôte dédié)
         │ django-storages (boto3)           │    ├──► MinIO API (:9000) (strictement interne)
         │                                   │    └──► Volume Docker: minio_data
Celery (Worker / Beat)                       │
(Traitement de fichiers asynchrone)          └──► [PRODUCTION] (Cloud managé)
                                                  ├──► Bucket Cloud managé (AWS S3, Scaleway...)
                                                  └──► Zéro conteneur MinIO sur le serveur
```

---

## 3. Matrice de Parité des Environnements

| Critère | DEV Lite | DEV Full | STAGING | PRODUCTION |
|---|---|---|---|---|
| **Moteur Storage** | `FileSystemStorage` | `MinIO` (Conteneur) | `MinIO` (Conteneur) | `Cloud S3 Managé` |
| **Variable `USE_S3_STORAGE`** | `false` (ou `true`) | `true` | `true` (obligatoire) | `true` (obligatoire) |
| **Endpoint S3** | N/A | `http://minio:9000` | `http://minio:9000` | Résolu par le provider cloud |
| **Console MinIO (Web)** | N/A | Exposée `127.0.0.1:9001` | Non publiée (`published=false`) | Aucun conteneur |
| **Ports S3 sur l'hôte** | N/A | `127.0.0.1:9000` (optionnel) | Strictement interne | Géré par le Cloud |
| **Conteneurs Compose** | Zéro | `minio` + `minio-create-bucket` | `minio` + `minio-create-bucket` | Aucun conteneur MinIO |
| **Gestion des Secrets** | `.env` local | `group_vars/dev/all.yml` | `vault.yml` STG | `vault.yml` PROD |

---

## 4. Conception Applicative Django

### 4.1. Dépendance Python

Ajout dans `django-app/requirements/base.txt` :

```text
django-storages[boto3]>=1.14.4,<2.0.0
```

### 4.2. Configuration des `STORAGES` (`config/settings/`)

Dans `django-app/config/settings/base.py` (ou `storage.py`) :

```python
import environ

env = environ.Env()

USE_S3_STORAGE = env.bool("USE_S3_STORAGE", default=False)

if USE_S3_STORAGE:
    AWS_ACCESS_KEY_ID = env("AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY = env("AWS_SECRET_ACCESS_KEY")
    AWS_STORAGE_BUCKET_NAME = env("AWS_STORAGE_BUCKET_NAME")
    AWS_S3_REGION_NAME = env("AWS_S3_REGION_NAME", default="us-east-1")
    
    # Endpoint S3 explicite (requis pour MinIO, None pour AWS S3 par défaut)
    AWS_S3_ENDPOINT_URL = env("AWS_S3_ENDPOINT_URL", default=None)
    
    # MinIO exige le path-style addressing
    AWS_S3_ADDRESSING_STYLE = env("AWS_S3_ADDRESSING_STYLE", default="auto")
    
    AWS_S3_SIGNATURE_VERSION = "s3v4"
    AWS_DEFAULT_ACL = None  # Recommandé (bucket ownership controls)
    AWS_QUERYSTRING_AUTH = env.bool("AWS_QUERYSTRING_AUTH", default=True)
    AWS_S3_FILE_OVERWRITE = False

    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "location": "media",
            },
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }
else:
    # Mode repli local DEV Lite
    STORAGES = {
        "default": {
            "BACKEND": "django.core.files.storage.FileSystemStorage",
            "OPTIONS": {
                "location": BASE_DIR / "mediafiles",
            },
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }

MEDIA_URL = env("MEDIA_URL", default="/media/")
```

---

## 5. Intégration Docker Compose

### 5.1. Stack de Base (`compose.yml`)

Ajout des services MinIO et du conteneur d'initialisation automatique du bucket :

```yaml
services:
  # ... (web, worker, beat, db, redis, nginx)

  minio:
    image: minio/minio:RELEASE.2024-11-07T00-52-28Z
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 5s
      timeout: 5s
      retries: 5

  minio-create-bucket:
    image: minio/mc:RELEASE.2024-11-05T11-41-28Z
    depends_on:
      minio:
        condition: service_healthy
    networks:
      - backend
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 $${MINIO_ROOT_USER} $${MINIO_ROOT_PASSWORD};
      mc mb local/$${AWS_STORAGE_BUCKET_NAME} --ignore-existing;
      exit 0;
      "

volumes:
  # ...
  minio_data:
    name: ${COMPOSE_PROJECT_NAME}_minio_data
```

### 5.2. Overlays Compose par Environnement

* **`compose.dev.yml`** :
  ```yaml
  services:
    minio:
      ports:
        - "127.0.0.1:9000:9000"  # API S3 accessible pour debug local
        - "127.0.0.1:9001:9001"  # Console MinIO Web pour inspection UI
  ```

* **`compose.stg.yml`** :
  ```yaml
  services:
    minio:
      # Aucun port publié sur l'hôte : isolation backend stricte
      restart: unless-stopped
  ```

* **`compose.prod.yml`** :
  ```yaml
  services:
    minio:
      profiles: ["storage-local"] # Désactivé par défaut en production
    minio-create-bucket:
      profiles: ["storage-local"] # Désactivé par défaut en production
  ```

---

## 6. Distribution et Sécurité des Fichiers Médias

Deux modes d'accès sont possibles selon la sensibilité des fichiers :

### 6.1. Médias Privés / Sécurisés (Recommandé par défaut)
* **Cas d'usage** : Rapports générés par Celery, pièces jointes confidentielles, exports CSV/PDF.
* **Mécanisme** : `AWS_QUERYSTRING_AUTH = True`.
* **Fonctionnement** : Django génère des URLs pré-signées avec jeton cryptographique et durée d'expiration (ex: 15 minutes). Le client télécharge directement depuis MinIO ou S3 sans solliciter le serveur Django.

### 6.2. Médias Publics (Avatars, Images de vitrine)
* **Cas d'usage** : Assets accessibles sans authentification.
* **En Dev / Staging** : Nginx peut agir comme reverse-proxy vers MinIO :
  ```nginx
  location /media/ {
      proxy_pass http://minio:9000/dst-media/;
      proxy_set_header Host $http_host;
      proxy_hide_header Set-Cookie;
  }
  ```
* **En Production** : Les requêtes médias pointent directement sur le CDN ou le nom de domaine personnalisé S3 (`AWS_S3_CUSTOM_DOMAIN`, ex: `media.mondomaine.com`).

---

## 7. Configuration Ansible et Ansible Vault

Les variables sont distribuées conformément aux contrats de sécurité du projet :

### `inventories/dev/group_vars/all.yml`
```yaml
use_s3_storage: true
aws_storage_bucket_name: dst-media-dev
aws_s3_endpoint_url: "http://minio:9000"
aws_s3_addressing_style: path
minio_root_user: minioadmin
minio_root_password: minioadmin_dev_password_12345
```

### `inventories/stg/group_vars/vault.yml` (Chiffré)
```yaml
vault_minio_root_user: stg_minio_operator
vault_minio_root_password: "{{ generated_stg_minio_password }}"
vault_aws_storage_bucket_name: dst-media-stg
```

### `inventories/prod/group_vars/vault.yml` (Chiffré)
```yaml
vault_aws_access_key_id: "<SET_IN_ENCRYPTED_VAULT_AWS_KEY>"
vault_aws_secret_access_key: "<SET_IN_ENCRYPTED_VAULT_AWS_SECRET>"
vault_aws_storage_bucket_name: "dst-production-media-assets"
vault_aws_s3_region_name: "eu-west-3"
# aws_s3_endpoint_url n'est pas défini ou pointe vers le provider cloud spécifique
```

### Injection dans `.env.runtime`
Le rôle Ansible `compose_stack` génère le fichier `.env.runtime` (permissions `0600 root:root`) contenant ces variables au moment du déploiement.

---

## 8. Découplage et Gains Majeurs pour Celery

L'adoption de l'Object Storage résout l'un des défis majeurs des architectures réparties avec Celery :

```text
SANS OBJECT STORAGE (Anti-pattern volume partagé) :
[Django Web] ──┐
               ├─► [Volume disque partagé NFS / Host Mount] ◄── [Celery Worker]
               │   (Risques: verrous, permissions UID/GID, I/O lents, SPOF)
               └────────────────────────────────────────────────────────────

AVEC OBJECT STORAGE (12-Factor Stateless) :
[Django Web]      ──► S3 API (PUT/GET) ──┐
                                         ├─► [Bucket S3 / MinIO]
[Celery Worker]   ──► S3 API (PUT/GET) ──┘
(Stateless, scalable horizontalement sur n'importe quel nœud, aucune dépendance disque locale)
```

---

## 9. Roadmap d'Implémentation Suggérée (Jalons DC-17 à DC-20)

Pour préserver la traçabilité et le contrôle qualité du projet :

| Jalon | Objectif technique | Critères d'acceptation |
|---|---|---|
| **DC-17** | Dépendance `django-storages` + Configuration multi-environnements | Tests unitaires passant en `FileSystemStorage` et avec mock S3 (`moto`). |
| **DC-18** | Intégration MinIO dans Docker Compose & Overlays | Service MinIO opérationnel, création automatique du bucket par `minio-create-bucket`. |
| **DC-19** | Qualification E2E Upload DRF & Traitement Celery | Endpoint DRF d'upload, déclenchement d'une tâche Celery qui lit le média et produit un résultat sur MinIO. |
| **DC-20** | Qualification Staging, Idempotence & Packaging | Déploiement sans build (`--no-build`), idempotence Ansible `changed=0` avec persistance du volume `minio_data`. |

---

## Conclusion

Cette approche garantit une transition fluide entre l'environnement local de développement et le cloud de production :
1. **Zéro dépendance propriétaire dans le code Django** : seul le SDK standard S3 est utilisé.
2. **Parité fonctionnelle totale** : le conteneur MinIO offre en local et staging le comportement exact du cloud.
3. **Stateless pur pour Celery et Django** : suppression définitive des volumes partagés.
4. **Cohérence avec la gouvernance du projet** : même politique de secrets Vault, de durcissement réseau et de qualification CI.
