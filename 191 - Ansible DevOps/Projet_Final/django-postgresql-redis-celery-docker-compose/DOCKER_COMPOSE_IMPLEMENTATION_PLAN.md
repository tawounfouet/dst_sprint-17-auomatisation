# Plan d'implémentation — Docker + Docker Compose

## 1. Objectif

Faire évoluer la baseline qualifiée Django/PostgreSQL/Redis/Celery vers une variante où les runtimes applicatifs sont exécutés par **Docker Compose**, tout en conservant **Ansible** comme outil de préparation, configuration et convergence de l'hôte.

La cible fonctionnelle est :

```text
Django + Django REST Framework
Gunicorn
PostgreSQL
Redis + authentification
Celery Worker
Celery Beat + django-celery-beat
Nginx
Docker Engine
Docker Compose v2
Ansible
```

## 2. Principe de séparation des responsabilités

```text
Ansible
  ├── prépare Ubuntu
  ├── installe/configure Docker Engine
  ├── déploie les fichiers de stack
  ├── injecte les variables/secrets
  ├── appelle Docker Compose
  └── valide le runtime

Docker Compose
  ├── construit/lance web
  ├── lance PostgreSQL
  ├── lance Redis
  ├── lance Celery Worker
  ├── lance Celery Beat
  └── lance Nginx
```

Ansible ne doit pas provisionner PostgreSQL/Redis/Nginx sur l'hôte en même temps que Compose fournit ces mêmes composants.

## 3. Services Compose

```text
nginx
web
 db
redis
worker
beat
```

`web`, `worker` et `beat` réutilisent la même image applicative afin d'éviter trois builds divergents.

Commandes conceptuelles :

```text
web    → gunicorn config.wsgi:application --bind 0.0.0.0:8000
worker → celery -A config worker --loglevel=INFO
beat   → celery -A config beat --scheduler django_celery_beat.schedulers:DatabaseScheduler --loglevel=INFO
```

## 4. Image applicative

Le Dockerfile devra :

```text
partir d'une image Python 3.12 adaptée
installer uniquement les dépendances nécessaires
copier requirements.txt avant le code pour exploiter le cache
installer les packages avec pip
copier l'application
créer/utiliser un utilisateur non-root
préparer les répertoires static/media nécessaires
ne contenir aucun secret
```

La baseline continue d'utiliser un `.venv` pour le déploiement natif historique. Dans l'image Docker, un venv interne supplémentaire n'est pas nécessaire : l'isolation du conteneur joue ce rôle. Cette différence sera explicitement documentée et limitée à la variante Docker.

## 5. Django REST Framework

Ajouter une dépendance bornée `djangorestframework` puis migrer au minimum l'API de tâches asynchrones vers DRF.

Cible :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

Les endpoints de health peuvent rester simples s'ils ne bénéficient pas de DRF, mais la présence de DRF doit être réelle, testée et visible dans `INSTALLED_APPS`.

## 6. Configuration de l'application en réseau Compose

Les variables d'environnement cibles deviennent :

```text
POSTGRES_HOST=db
POSTGRES_PORT=5432
REDIS_HOST=redis
REDIS_PORT=6379
CELERY_BROKER_URL=redis://:<secret>@redis:6379/0
CELERY_RESULT_BACKEND=redis://:<secret>@redis:6379/1
```

Les valeurs de secrets ne doivent pas être versionnées.

## 7. Réseau

Compose devra utiliser au minimum un réseau applicatif privé.

Publication hôte :

```text
nginx : 80:80
```

Pas de `ports:` pour :

```text
web:8000
 db:5432
redis:6379
worker
beat
```

`expose:` peut être utilisé pour documenter les ports inter-services, mais n'est pas un mécanisme de sécurité. L'absence de publication hôte est le contrat essentiel.

## 8. Persistance

Volumes nommés minimum :

```text
postgres_data
static_data
```

Selon le comportement retenu pour Redis :

```text
redis_data
```

peut être ajouté si la persistance AOF/RDB est activée et justifiée. Le broker/result backend de laboratoire peut aussi rester éphémère ; cette décision devra être explicite.

## 9. Healthchecks

La stack devra fournir des healthchecks utiles :

```text
db     → pg_isready
redis  → redis-cli AUTH/PING sans exposer le secret dans les logs
web    → endpoint /health/
nginx  → requête HTTP locale
```

Worker et Beat seront validés par des tests fonctionnels, car un simple healthcheck process ne prouve pas le traitement de tâches.

## 10. Secrets

Sources : Ansible Vault en production/lab Ansible et secrets éphémères dans GitHub Actions.

Aucun secret réel dans :

```text
Dockerfile
docker-compose.yml
.env.example
Git
artifacts publics
logs
```

Le rôle `compose_stack` devra rendre un fichier d'environnement runtime avec permissions restrictives ou utiliser une autre méthode Compose compatible avec le lab, puis le nettoyer des packages de qualification.

## 11. Rôles Ansible

Les rôles actifs cibles deviennent :

```text
roles/
├── common/
├── docker_engine/
└── compose_stack/
```

### `docker_engine`

Responsabilités :

```text
installer Docker Engine
installer le plugin Compose v2
activer/démarrer docker
valider docker info
docker compose version
```

### `compose_stack`

Responsabilités :

```text
créer le répertoire de déploiement
copier Dockerfile / compose / Nginx config / application
rendre le fichier d'environnement depuis Vault
construire les images
converger la stack avec community.docker.docker_compose_v2
attendre les healthchecks
```

## 12. Orchestration cible

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

Les rôles natifs historiques restent dans la copie comme référence jusqu'à stabilisation, mais ne font plus partie du `site.yml` final Docker Compose.

## 13. Qualification E2E

Le scénario canonique devra prouver réellement :

```text
Docker daemon actif
Docker Compose v2 disponible
6 services Compose attendus
PostgreSQL healthy
Redis authentifié PING → PONG
Django/DRF accessible via Nginx
add(21,21) → 42 via Celery
uppercase("datascientest") → "DATASCIENTEST"
database_probe() → SELECT 1
Celery Beat déclenche la tâche périodique
80 publié sur l'hôte
8000 non publié
5432 non publié
6379 non publié
```

La qualification doit interroger l'application **via Nginx**, pas contourner le proxy depuis le runner.

## 14. Idempotence

Deux niveaux seront contrôlés :

```text
Ansible site.yml #2 → server1 changed=0
Docker Compose      → pas de recréation inutile lorsque rien n'a changé
```

Un changement d'image ou de configuration doit, lui, provoquer une recréation ciblée et explicable.

## 15. GitHub Actions

Un workflow distinct sera créé pour ne pas altérer les qualifications précédentes :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose.yml
```

Pipeline cible :

```text
static checks
  ↓
provision Ubuntu 24.04 target
  ↓
Ansible installe Docker + Compose
  ↓
Ansible déploie stack
  ↓
docker compose ps / health
  ↓
HTTP/DRF + DB + Redis + Celery + Beat
  ↓
network publication contract
  ↓
site.yml #2 changed=0
  ↓
post-idempotence validation
  ↓
package + SHA-256
  ↓
package safety
  ↓
artifact
```

## 16. Roadmap

```text
DC-00  Controlled baseline copy                       ✅
DC-01  Docker/Compose architecture and contracts       ✅ DESIGN
DC-02  Dockerfile + .dockerignore + non-root image     ⏳
DC-03  Compose stack                                    ⏳
DC-04  Django REST Framework                            ⏳
DC-05  Ansible docker_engine                            ⏳
DC-06  Ansible compose_stack                            ⏳
DC-07  Vault/env secret injection                       ⏳
DC-08  Healthchecks, persistence, network isolation     ⏳
DC-09  Static gate                                      ⏳
DC-10  First Compose E2E qualification                  ⏳
DC-11  Strict idempotence                               ⏳
DC-12  Qualified package, SHA-256, artifact             ⏳
DC-13  Final qualification report                       ⏳
```

## 17. Limite de la future preuve CI

Même une qualification Compose GREEN sur GitHub Actions ne prouvera pas automatiquement :

```text
SSH vers un VPS public
DNS
TLS / Let's Encrypt
UFW/cloud firewall
backup/restore production
haute disponibilité
registry privé
rolling update multi-host
```

Ces sujets appartiendront à une phase PROD-LIKE ultérieure.
