# DC-16 — Rapport final de qualification et Matrice 12-Factor

## Statut final

**PROJET QUALIFIÉ ET HOMOLOGUÉ ✅**

La variante **Docker Engine + Docker Compose avec Ansible comme plan de contrôle**, dérivée du projet initial et de la baseline native `django-postgresql-redis-celery/`, est désormais **intégralement qualifiée, validée et fermée** sur l'ensemble de ses jalons (DC-00 à DC-16).

La pile qualifiée réunit :

```text
Django 5 / Django REST Framework
PostgreSQL (backing service relationnel)
Redis avec authentification (broker Celery & result backend)
Celery Worker (exécution asynchrone)
django-celery-beat (scheduler périodique DatabaseScheduler persistant)
Nginx (reverse proxy frontal et terminaison HTTP)
Docker Engine 28 & Docker Compose v2
Ansible core 2.20+ (orchestration, durcissement et déploiement idempotent)
```

---

## 1. Synthèse des qualifications canoniques observées (CI)

Chaque jalon clé a fait l'objet d'une qualification réelle, automatisée et observée dans GitHub Actions :

| Jalon | Intitulé | Workflow / Gate | Run ID | Commit | Verdict |
|---|---|---|---|---|---|
| **DC-11** | Gate Statique & Validation Compose | `Static Checks` | 34149470178 | `ec4be91` | **SUCCESS ✅** |
| **DC-12** | DEV Full E2E Qualification | `Compose DEV E2E` | 34149470187 | `ec4be91` | **DC12_DEV_FULL_E2E_PASS ✅** |
| **DC-13** | STG-like E2E & Anti-SQLite | `Compose STG E2E` | 34149470152 | `ec4be91` | **DC13_STG_LIKE_E2E_PASS ✅** |
| **DC-14** | Strict Idempotence Ansible | `Compose Idempotence` | 34166358818 | `109d47d` | **DC14_STRICT_IDEMPOTENCE_PASS ✅** |
| **DC-15** | Package, SHA-256 & Artifact | `Compose Package` | 34166857587 | `6a8e7cf` | **PACKAGE_CHECKSUM_PASS ✅** |
| **DC-16** | Rapport Final & Matrice 12-Factor | Clôture documentaire | — | HEAD | **QUALIFIED & CLOSED ✅** |

---

## 2. Architecture cible qualifiée

```text
Internet / Client / Runner
       │
       │ HTTP (:80 / :8080 / :8081)
       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Hôte Docker (Ubuntu 24.04 LTS + Docker Engine 28 + Compose v2)         │
│                                                                        │
│ ┌────────────────────────── Réseau frontend ─────────────────────────┐ │
│ │                                                                    │ │
│ │  nginx (Reverse Proxy, proxy_pass, static files)                   │ │
│ │   │                                                                │ │
│ └───┼────────────────────────────────────────────────────────────────┘ │
│     │                                                                  │
│ ┌───┼────────────────────── Réseau backend ──────────────────────────┐ │
│ │   ▼                                                                │ │
│ │  web (Gunicorn + Django/DRF — 0.0.0.0:8000, non publié hôte)       │ │
│ │   │                                                                │ │
│ │   ├──────────────────────────────► db                              │ │
│ │   │                                 PostgreSQL (:5432)             │ │
│ │   │                                 Volume: postgres_data          │ │
│ │   │                                                                │ │
│ │   └──────────────────────────────► redis                           │ │
│ │                                     Redis avec auth (:6379)        │ │
│ │                                     Volume: redis_data             │ │
│ │                                        ▲                           │ │
│ │                                        │                           │ │
│ │                                  worker                            │ │
│ │                                    Celery Worker                   │ │
│ │                                    Même image Docker non-root      │ │
│ │                                        ▲                           │ │
│ │                                        │                           │ │
│ │   db ◄─────────────────────────── beat                             │ │
│ │                                    django-celery-beat              │ │
│ │                                    DatabaseScheduler               │ │
│ └────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

### Contrat des services et isolation réseau

| Service | Rôle | Image | Port conteneur | Port hôte exposé | Isolation réseau |
|---|---|---|---|---|---|
| `nginx` | Reverse Proxy frontal | `nginx:1.27-alpine` | 80 | 80 (ou 8080/8081) | `frontend`, `backend` |
| `web` | API REST Django / Gunicorn | Image app immutable | 8000 | **Aucun** (`published=false`) | `backend` |
| `db` | Base relationnelle PostgreSQL | `postgres:16-alpine` | 5432 | **Aucun** (`published=false`) | `backend` |
| `redis` | Broker Celery & Result Backend | `redis:7.4-alpine` | 6379 | **Aucun** (`published=false`) | `backend` |
| `worker` | Exécuteur de tâches Celery | Image app immutable | Aucun | **Aucun** | `backend` |
| `beat` | Planificateur périodique | Image app immutable | Aucun | **Aucun** | `backend` |

Le contrôle rigoureux via l'API Docker (`HostConfig.PortBindings`) prouve qu'aucun port de données interne (8000, 5432, 6379) n'est exposé sur l'interface hôte.

---

## 3. Matrice de conformité 12-Factor App

Le projet a été pensé, implémenté et audité conformément aux 12 principes directeurs de l'ingénierie cloud-native (*The Twelve-Factor App*) :

| # | Facteur | Exigence 12-Factor | Implémentation dans le projet | Preuve observée & Vérification |
|---|---|---|---|---|
| **I** | **Codebase**<br>*(Base de code)* | Un seul dépôt suivi sous contrôle de version, plusieurs déploiements. | Dépôt Git unique (`dst_sprint-17-auomatisation`). Séparation des déploiements par inventaires Ansible (`dev`, `stg`, `prod`) et overlays Compose. | Traçabilité Git intégrale de DC-00 à DC-16. Pas de divergence de code source entre environnements. |
| **II** | **Dependencies**<br>*(Dépendances)* | Déclarer explicitement et isoler les dépendances. Aucun `pip install` au runtime conteneur. | Dépendances Python épinglées dans `requirements/base.txt`, `dev.txt`, `prod.txt`. Dockerfile multi-stage (`builder` installant dans `/install`, image `runtime` épurée). | `Dockerfile` validé par DC-11. Zéro outil de build (`gcc`, etc.) et zéro exécution de `pip` au démarrage des conteneurs. |
| **III** | **Config**<br>*(Configuration)* | Stocker la configuration dans l'environnement d'exécution, séparée du code. | Utilisation de `django-environ`. Fichier injecté `.env.runtime` (permissions root:root `0600`). Gestion des secrets sensibles chiffrés par Ansible Vault. | `DC-13` : Rejet prouvé au démarrage si variables obligatoires absentes (`DATABASE_URL`, `APPLICATION_ENV`, `DJANGO_SETTINGS_MODULE`). |
| **IV** | **Backing Services**<br>*(Services d'appui)* | Traiter les services d'appui (BDD, cache, broker) comme des ressources attachées. | PostgreSQL et Redis traités via URLs normalisées (`DATABASE_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND_URL`) sans couplage local. | Connexion dynamique validée avec auth Redis et SCRAM PostgreSQL via résolution DNS interne Docker (`db`, `redis`). |
| **V** | **Build, Release, Run**<br>*(Assembler, livrer, exécuter)* | Séparer strictement les étapes d'assemblage, de livraison et d'exécution. | **Build** : Image Docker construite hors Compose (`sha256`).<br>**Release** : Tâches one-off `migrate`, `collectstatic`, initialisation Beat.<br>**Run** : Conteneurs démarrés avec `--no-build --pull never`. | `DC-13` : Image référencée par son digest SHA-256 immutable (`sha256:f1fe85...`). Zéro rebuild et zéro pull au runtime. |
| **VI** | **Processes**<br>*(Processus)* | Exécuter l'application sous forme de processus sans état (stateless) et sans partage. | Les conteneurs `web`, `worker` et `beat` sont entièrement stateless et jetables. Tout état durable réside dans PostgreSQL ou Redis. | Volumes Docker nommés réservés aux données d'appui (`postgres_data`, `redis_data`) et aux statiques compilés (`django_static`). |
| **VII** | **Port Binding**<br>*(Association de ports)* | Exporter les services via une liaison de port autonome. | Gunicorn écoute de façon autonome sur `0.0.0.0:8000`. Nginx écoute sur le port d'entrée (`80`). Aucun serveur applicatif n'est injecté dans le système hôte. | Le conteneur `web` expose directement son service HTTP sur le réseau Docker interne sans dépendre du serveur Web de l'hôte. |
| **VIII** | **Concurrency**<br>*(Concurrence)* | Échelonner les traitements via le modèle de processus. | Séparation physique des typologies de charge : `web` (requêtes synchrones I/O), `worker` (charges asynchrones Celery), `beat` (planificateur temporel). | Chaque composant dispose de son conteneur dédié, permettant un dimensionnement (*scaling*) horizontal indépendant de `web` et `worker`. |
| **IX** | **Disposability**<br>*(Jetabilité)* | Maximiser la robustesse avec un démarrage rapide et un arrêt propre. | Gestion propre des signaux `SIGTERM` / `SIGINT`. Utilisation de `init: true` (tini) dans Compose pour éliminer les processus zombies. Timeouts d'arrêt gracieux configurés. | Validé en DC-14 : redémarrage et convergence sans corruption de données ni blocage de processus orphelins. |
| **X** | **Dev/Prod Parity**<br>*(Parité dev/prod)* | Garder le développement, le staging et la production aussi proches que possible. | Même image applicative partagée entre tous les environnements. Même moteur Compose. Politique anti-SQLite stricte interdisant SQLite en STG/PROD. | `DC-13` : Preuve d'échec immédiat (`exit code != 0`) si SQLite ou `DEBUG=true` est injecté en staging ou production. |
| **XI** | **Logs**<br>*(Journaux)* | Traiter les journaux comme des flux d'événements continus. | Aucune écriture de log dans des fichiers internes aux conteneurs. Tous les logs applicatifs sont émis vers `stdout` / `stderr`. | Docker daemon et Compose configurés avec le driver `json-file` (rotation `max-size: 10m`, `max-file: 3`). Logs centralisés via `docker logs`. |
| **XII** | **Admin Processes**<br>*(Processus d'administration)* | Exécuter les tâches d'administration ponctuelle comme des processus one-off. | Les migrations (`manage.py migrate`), la collecte statique (`collectstatic`) et l'enregistrement Beat s'exécutent en conteneurs éphémères de release. | Exécuté dans l'exact même environnement applicatif (même image, même config) avant le basculement du trafic. |

---

## 4. Orchestration Ansible qualifiée et Idempotence stricte

Le plan de contrôle Ansible a été restructuré pour piloter l'infrastructure Docker Compose sans dérive :

```text
site.yml
  │
  ├── 1. common                   (base système, paquets requis, python3-docker)
  ├── 2. docker_engine            (installation Docker CE officiel, plugin compose v2)
  ├── 3. docker_runtime_hardening (daemon.json, live-restore, iptables, log rotation)
  └── 4. compose_stack            (déploiement .env.runtime, release one-off, stack up)
```

### Preuve d'idempotence stricte (DC-14) :
Lors du run canonique `#6` (Job `101878054495`) :
* **Première convergence** : `localhost : ok=53 changed=8 unreachable=0 failed=0 skipped=3`
* **Seconde convergence immédiate** : `localhost : ok=53 changed=0 unreachable=0 failed=0 skipped=3`
* **Verdict d'intégrité** :
  - Identifiants des 6 conteneurs long-running : **inchangés** (`DC14_CONTAINER_PASS`).
  - Identifiants et digests des images Docker : **inchangés** (`DC14_ARTIFACT_PASS`).
  - Attachement et intégrité des volumes nommés (`postgres_data`, `redis_data`, `django_static`) : **inchangés** (`DC14_VOLUME_PASS`).
  - Marqueurs durables écrits en base et sur disque : **préservés à 100%** (`DC14_DATA_PASS`).
  - Checksums de configuration `.env.runtime` et `compose.yml` : **identiques** (`DC14_CONFIG_PASS`).

---

## 5. Qualification fonctionnelle de bout en bout

Les scénarios métier exécutés à travers Nginx confirment le bon fonctionnement de l'ensemble de la chaîne :

1. **Vérification de santé (Liveness & Readiness)** :
   * Requête HTTP `GET /health/` via le port frontal Nginx retournant `status: healthy` avec vérification effective de PostgreSQL et Redis.
2. **Calcul asynchrone (Celery + Redis Broker + Result Backend)** :
   * `POST /api/tasks/add/` avec payload `{"x": 21, "y": 21}`.
   * Suivi du polling sur `GET /api/tasks/<task_id>/` jusqu'à `SUCCESS` et résultat `42`.
3. **Traitement texte asynchrone** :
   * `POST /api/tasks/uppercase/` avec `{"text": "datascientest"}` → retour `DATASCIENTEST`.
4. **Sonde de base de données asynchrone (Worker → Django ORM → PostgreSQL)** :
   * `POST /api/tasks/database-probe/` exécutant un `SELECT 1` via l'ORM Django dans le contexte du Worker Celery.
5. **Ordonnancement persistant (django-celery-beat)** :
   * Tâche périodique `datascientest-demo-heartbeat` programmée dans PostgreSQL (`PeriodicTask`).
   * Déclenchement automatique par le conteneur `beat` et exécution constatée dans les logs du conteneur `worker` (`total_run_count >= 1`).

---

## 6. Packaging, Hygiène des secrets et Traçabilité

Le livrable final du projet a été produit et audité lors du jalon **DC-15** :

* **Archive livrable** : `django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip`
* **Taille** : 260 647 octets
* **Empreinte d'intégrité SHA-256** :
  ```text
  bb4c2dfe6cb3bf16a290e4546ab432ac6d62b76113e07f0e18502816574c5298
  ```
* **Contrôles de sécurité (`secret_hygiene.py`)** :
  - Scan du dépôt Git complet : **GREEN (zéro fuite)**.
  - Scan de l'archive ZIP générée : **GREEN (zéro secret, zéro clé privée, zéro .env local)**.
* **Manifeste d'artifact** : `django-postgresql-redis-celery-docker-compose-ansible-6a8e7cfaf638.zip.manifest.json`
* **Stockage de référence GitHub Actions** :
  - Artifact ID : `10034425511`
  - Run ID : `34166857587`

---

## 7. Périmètre qualifié vs Limites de l'environnement CI

Conformément à la rigueur méthodologique du projet, les frontières entre la qualification automatisée et un déploiement sur une infrastructure de production réelle sont clairement délimitées :

### Ce qui est formellement qualifié et garanti :
* Le code applicatif Django 5 / DRF et son exécution avec Celery, Redis et PostgreSQL.
* L'architecture multi-conteneurs Docker Compose et son isolation réseau/volumes.
* Les Dockerfiles multi-stage non-root et le respect strict des 12 facteurs.
* Les playbooks et rôles Ansible assurant un déploiement déterministe et idempotent (`changed=0`).
* La politique de configuration sécurisée, l'absence de régression et le packaging scellé.

### Ce qui reste à charge lors du déploiement sur un VPS / Cloud réel :
1. **Accès réseau et SSH** : Gestion des clés SSH hôtes, durcissement du service OpenSSH distant et configuration DNS du nom de domaine.
2. **Certificats TLS/HTTPS** : Mise en place de Let's Encrypt / Certbot sur Nginx ou terminaison SSL sur un répartiteur de charge (Load Balancer) amont.
3. **Registry d'entreprise** : Configuration d'un registre distant privé authentifié (GHCR, ECR, Docker Hub) pour la distribution des images signées.
4. **Stratégie de sauvegarde pérenne** : Automatisation des snapshots de volumes ou `pg_dump` réguliers vers un stockage objet immuable (AWS S3, GCP GCS).

---

## 8. Bilan et Clôture de la Roadmap

```text
DC-00  Controlled baseline copy                                  ✅
DC-01  Docker/Compose architecture contracts                      ✅ DESIGN
DC-02  Django configuration foundation                            ✅ IMPLEMENTED
DC-03  Django REST Framework                                      ✅ IMPLEMENTED
DC-04  12-Factor Docker image                                     ✅ IMPLEMENTED
DC-05  Base Docker Compose stack                                  ✅ IMPLEMENTED
DC-06  Multi-environment Compose                                  ✅ IMPLEMENTED
DC-07  Ansible docker_engine                                      ✅ IMPLEMENTED
DC-08  Ansible compose_stack + inventories dev/stg/prod           ✅ IMPLEMENTED
DC-09  Secure runtime configuration                               ✅ IMPLEMENTED
DC-10  Runtime hardening                                          ✅ IMPLEMENTED
DC-11  Unit tests + static gate + Compose validation              ✅ GREEN
DC-12  DEV Full E2E                                               ✅ GREEN
DC-13  STG-like E2E + anti-SQLite runtime                         ✅ GREEN
DC-14  Strict idempotence                                         ✅ GREEN
DC-15  Package + SHA-256 + artifact                               ✅ GREEN
DC-16  Final qualification report + 12-Factor matrix              ✅ QUALIFIED & CLOSED
```

**Le projet « Projet Ansible — Django/DRF + PostgreSQL + Redis + Celery + Docker Compose » est déclaré 100% qualifié et prêt pour son exploitation opérationnelle.**
