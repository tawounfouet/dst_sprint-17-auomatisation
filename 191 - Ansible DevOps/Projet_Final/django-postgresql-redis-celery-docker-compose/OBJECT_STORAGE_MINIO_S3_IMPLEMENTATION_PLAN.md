# Plan d'implémentation — Object Storage S3 & MinIO (DC-17 à DC-21)

## Statut

```text
STATUT              : PROPOSÉ (DESIGN & PLANNING)
JALONS COUVERTS     : DC-17 ➔ DC-21
BASE QUALIFIÉE      : DC-00 ➔ DC-16 (PROJET DOCKER COMPOSE BASELINE FERMÉ)
APPROCHE TECHNIQUE  : 12-FACTOR BACKING SERVICE S3 UNIFIÉ
```

Ce document définit la feuille de route technique pour ajouter la gestion des médias via **Object Storage S3-compatible** à la stack qualifiée `django-postgresql-redis-celery-docker-compose`.

---

## 1. Objectifs et Décisions Fondamentales

1. **Uniformité de l'API S3** :
   L'application Django et Celery utilisent une seule et même librairie standard (`django-storages` avec le SDK `boto3`). Aucune logique de branchement « MinIO vs AWS » n'existe dans le code source Python.
2. **Parité DEV Full / STAGING sous MinIO** :
   * En **DEV Full** et **STAGING**, MinIO s'exécute dans un conteneur dédié rattaché au réseau interne `backend`.
   * Un conteneur éphémère d'initialisation (`minio/mc`) crée automatiquement le bucket applicatif au premier démarrage.
3. **PRODUCTION sur Cloud S3 Managé** :
   * En **PRODUCTION**, aucun conteneur MinIO ne tourne sur le serveur hôte.
   * La configuration pointe sur un bucket managé (AWS S3, Scaleway, Cloudflare R2, GCP) avec des identifiants chiffrés par Ansible Vault.
4. **Repli Gracieux en DEV Lite (Offline / Local)** :
   * Si `USE_S3_STORAGE=false` (défaut en DEV Lite), Django bascule de manière transparente sur `FileSystemStorage` dans un dossier local `mediafiles/`, permettant de développer sans dépendance Docker.
5. **Élimination des Volumes Partagés entre Web et Worker** :
   * Les conteneurs `web` et `worker` deviennent strictement **stateless**. Les tâches asynchrones Celery lisent et écrivent directement sur le bucket via l'API S3.

---

## 2. Matrice des Contrats de Service

| Composant | Image / Rôle | Environnement | Port Conteneur | Port Hôte Exposé | Volume de Données |
|---|---|---|---|---|---|
| `minio` | `minio/minio` (API & Console) | DEV Full | `9000` (API), `9001` (Web) | `127.0.0.1:9000`, `127.0.0.1:9001` | `minio_data` (nommé) |
| `minio` | `minio/minio` (API S3) | STAGING | `9000` (API), `9001` (Web) | **Aucun** (`published=false`) | `minio_data` (nommé) |
| `minio` | *Désactivé / absent* | PRODUCTION | N/A | N/A | N/A (Stockage Cloud) |
| `minio-create-bucket` | `minio/mc` (One-off) | DEV Full / STG | Éphémère (création bucket) | Aucun | Aucun |

---

## 3. Découpage en Jalons Incrémentaux (Roadmap)

```text
DC-17  Socle Django Storage + django-storages + Fallback local
       ├── dépendance django-storages[boto3]
       ├── configuration settings/storage.py conditionnelle
       ├── politique DEV Lite (FileSystemStorage) vs DEV Full/STG/PROD (S3)
       └── tests unitaires avec mock S3 (moto)

DC-18  Intégration Docker Compose MinIO
       ├── service minio dans compose.yml
       ├── conteneur one-off minio-create-bucket (minio/mc)
       ├── overlays compose.dev.yml, compose.stg.yml, compose.prod.yml
       ├── healthcheck minio (mc ready local)
       └── volume nommé minio_data et isolation réseau backend

DC-19  API DRF d'Upload de Médias & Traitement Asynchrone Celery
       ├── endpoint DRF POST /api/tasks/media-upload/
       ├── tâche Celery media_processing (lecture, transformation, sauvegarde sur S3)
       ├── endpoint de consultation GET /api/tasks/media/<task_id>/
       └── preuve de bout en bout Web ➔ S3 ➔ Worker ➔ S3

DC-20  Orchestration Ansible & Durcissement Sécurité
       ├── variables inventories/dev, inventories/stg, inventories/prod
       ├── secrets Ansible Vault (vault_minio_*, vault_aws_*)
       ├── injection sécurisée dans .env.runtime (0600 root:root)
       ├── durcissement firewall DOCKER-USER pour MinIO
       └── secret_hygiene.py mis à jour pour les clés d'accès S3

DC-21  Qualifications CI, Idempotence Stricte & Package Final
       ├── workflow CI dev-e2e avec test MinIO
       ├── workflow CI stg-e2e (--no-build, digest-pinned, MinIO interne)
       ├── preuve d'idempotence stricte (changed=0, volume minio_data préservé)
       ├── packaging ZIP + SHA-256 + artifact mis à jour
       └── rapport de clôture DC-21
```

---

## 4. Détail des Fichiers Impactés et Tâches Techniques

### 4.1. Composant Django (`django-app/`)

#### [MODIFY] `django-app/requirements/base.txt`
* Ajouter `django-storages[boto3]>=1.14.4,<2.0.0`.

#### [MODIFY] `django-app/requirements/dev.txt`
* Ajouter `moto[s3]>=5.0.0` (pour les tests unitaires sans service MinIO actif).

#### [NEW] `django-app/config/settings/storage.py`
* Définir la configuration `STORAGES` pilotée par `USE_S3_STORAGE`.
* Gérer les variables : `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_STORAGE_BUCKET_NAME`, `AWS_S3_ENDPOINT_URL`, `AWS_S3_REGION_NAME`, `AWS_S3_ADDRESSING_STYLE`, `AWS_QUERYSTRING_AUTH`.

#### [MODIFY] `django-app/config/settings/base.py`
* Importer et intégrer la configuration issue de `storage.py`.

#### [NEW] `django-app/tasks_demo/media_tasks.py`
* Définir la tâche Celery `process_uploaded_document` (par exemple : lecture d'un fichier uploadé, comptage de mots/métadonnées ou conversion, écriture du résultat dans un fichier dérivé sur S3).

#### [MODIFY] `django-app/tasks_demo/views.py` & `urls.py`
* Ajouter la vue DRF pour soumettre un fichier via `multipart/form-data` et déclencher la tâche asynchrone associée.

#### [NEW] `django-app/tasks_demo/tests/test_storage.py`
* Tests unitaires :
  1. Test du fallback `FileSystemStorage` quand `USE_S3_STORAGE=false`.
  2. Test du chargement `S3Storage` quand `USE_S3_STORAGE=true`.
  3. Test d'upload mocké avec `moto`.

---

### 4.2. Composant Docker & Compose (`docker/` et racine)

#### [MODIFY] `compose.yml`
* Ajouter le service `minio` avec healthcheck.
* Ajouter le service `minio-create-bucket` rattaché au réseau `backend`.
* Déclarer le volume persistant `minio_data`.

#### [MODIFY] `compose.dev.yml`
* Exposer le port API `127.0.0.1:9000:9000` et la console web `127.0.0.1:9001:9001`.

#### [MODIFY] `compose.stg.yml`
* Configurer MinIO sans aucun port exposé sur l'hôte (`published=false`).

#### [MODIFY] `compose.prod.yml`
* Désactiver MinIO via `profiles: ["storage-local"]` ou suppression des services sur la cible de production.

---

### 4.3. Composant Ansible (`ansible-project/`)

#### [MODIFY] `ansible-project/inventories/dev/group_vars/all.yml`
* Variables MinIO non secrètes pour dev (`use_s3_storage: true`, `aws_s3_endpoint_url: "http://minio:9000"`, etc.).

#### [MODIFY] `ansible-project/inventories/stg/group_vars/all.yml` & `vault.yml`
* Définir `vault_minio_root_user` et `vault_minio_root_password` chiffrés.

#### [MODIFY] `ansible-project/inventories/prod/group_vars/all.yml` & `vault.yml`
* Définir `vault_aws_access_key_id`, `vault_aws_secret_access_key`, `vault_aws_storage_bucket_name`, `vault_aws_s3_region_name`. Laisser `aws_s3_endpoint_url` à vide (ou URL provider cloud).

#### [MODIFY] `ansible-project/roles/compose_stack/templates/.env.runtime.j2`
* Générer les variables S3/MinIO dans le runtime sécurisé `0600 root:root`.

#### [MODIFY] `ansible-project/scripts/secret_hygiene.py`
* Mettre à jour les motifs d'exclusion et de détection de faux-positifs pour les clés d'accès S3 de test.

---

### 4.4. Composant Intégration Continue (`.github/workflows/`)

#### [MODIFY] Workflow DEV E2E
* Valider que `minio` et `minio-create-bucket` s'initialisent correctement.
* Exécuter le test fonctionnel d'upload et de traitement Celery sur MinIO.

#### [MODIFY] Workflow STG E2E
* Vérifier le démarrage sous `--no-build --pull never`.
* Vérifier que le port `9000` n'est pas exposé sur l'interface publique de l'hôte.

#### [MODIFY] Workflow Idempotence
* Vérifier que la seconde convergence Ansible produit `changed=0`.
* Vérifier que le volume `minio_data` et son contenu ne sont pas altérés entre deux runs.

---

## 5. Definition of Done (DoD) Finale

Le projet avec Object Storage ne sera considéré comme terminé et qualifié que si :

```text
[x] django-storages[boto3] est installé et verrouillé
[x] DEV Lite sans S3 fonctionne sur le système de fichiers local
[x] DEV Full démarre MinIO et crée automatiquement le bucket
[x] L'interface web MinIO (9001) est accessible uniquement en DEV Full
[x] STAGING démarre MinIO en conteneur strictement interne (backend)
[x] Aucun port 9000 ou 9001 n'est publié sur l'hôte en STAGING
[x] PROD n'instancie aucun conteneur MinIO
[x] L'API DRF permet l'upload d'un fichier vers le bucket S3
[x] Celery Worker lit le fichier depuis S3 et génère un résultat sur S3
[x] Idempotence Ansible stricte et isolation réseau backend respectées
[x] Suite de tests Django et static gate CI 100% au vert
[x] Aucun volume partagé n'existe entre web et worker
[x] Ansible Vault gère de façon étanche les identifiants MinIO et AWS S3
[x] .env.runtime contient les variables rendues avec permissions 0600 root:root
[x] secret_hygiene.py valide le repo et le package sans fuite de clés
[x] Une seconde convergence Ansible produit strictement changed=0
[x] Les conteneurs long-running et le volume minio_data restent inchangés
[x] Le ZIP final et son sidecar SHA-256 sont générés avec succès
```

---

## 6. Analyse des Risques et Stratégies d'Atténuation

| Risque identifié | Impact | Stratégie d'atténuation |
|---|---|---|
| **Délai de démarrage MinIO** | Échec du démarrage de Django ou du conteneur `minio-create-bucket`. | `depends_on` avec `condition: service_healthy` basé sur `mc ready local`. |
| **Fuite des credentials S3 dans Git** | Risque de sécurité critique. | Utilisation stricte d'Ansible Vault pour les credentials réels, scan systématique via `secret_hygiene.py`. |
| **Incompatibilité path-style vs virtual-host** | Échec des requêtes S3 selon le provider (MinIO vs AWS). | Variable `AWS_S3_ADDRESSING_STYLE=path` pour MinIO, `auto` ou `virtual` pour AWS Cloud. |
| **Volume MinIO recréé lors d'un redéploiement** | Perte des médias en staging. | Volume nommé explicite `${COMPOSE_PROJECT_NAME}_minio_data` managé par Docker, protégé par la politique d'idempotence DC-14. |
| **Taille excessive des uploads** | Dépassement mémoire conteneur Gunicorn / Nginx. | Directive Nginx `client_max_body_size` bornée (ex: `20M`), streaming direct des uploads. |
