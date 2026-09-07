# Projet Ansible — Django/DRF + PostgreSQL + Redis + Celery + Docker Compose

Nouvelle variante dérivée du projet qualifié `django-postgresql-redis-celery/` afin de migrer l'exécution applicative vers **Docker Engine + Docker Compose**, tout en conservant **Ansible comme plan de contrôle et d'automatisation du serveur**.

## Source de la copie

```text
source folder : 191 - Ansible DevOps/Projet_Final/django-postgresql-redis-celery/
source branch : feat/ansible-django-postgresql-redis-celery
source HEAD   : 0b33d1ea230b47492720127b2dcf837899da851d
```

Les preuves RC-10 à RC-13 copiées depuis la baseline sont **historiques uniquement**. Elles qualifient la variante systemd/native précédente, pas cette nouvelle variante Docker Compose.

## Statut

```text
BASELINE COPIED              ✅
TARGET ARCHITECTURE          ✅ DESIGN
DOCKERFILE                   ⏳
DOCKER COMPOSE               ⏳
DJANGO REST FRAMEWORK        ⏳
ANSIBLE DOCKER ENGINE        ⏳
ANSIBLE COMPOSE DEPLOY       ⏳
SECRETS / ENV INJECTION      ⏳
HEALTHCHECKS / PERSISTENCE   ⏳
STATIC GATE                  ⏳
COMPOSE E2E                  ⏳
STRICT IDEMPOTENCE           ⏳
PACKAGE + SHA-256            ⏳
FINAL REPORT                 ⏳
```

## Architecture cible

```text
Ansible control
      │
      │ SSH / CI transport
      ▼
┌─────────────────────────────────────────────────────────────┐
│ server1 — Ubuntu 24.04                                    │
│                                                            │
│ Docker Engine + Docker Compose                             │
│                                                            │
│  ┌─────────┐        ┌──────────────────────────────┐       │
│  │ nginx   │───────►│ web                          │       │
│  │ :80     │        │ Django/DRF + Gunicorn :8000 │       │
│  └─────────┘        └──────────────┬───────────────┘       │
│       ▲                            │                       │
│       │                            ├────────► db            │
│    public                          │          PostgreSQL     │
│                                    │          :5432 internal │
│                                    │                       │
│                                    └────────► redis         │
│                                               :6379 internal │
│                                                  ▲          │
│                                      ┌───────────┴────────┐ │
│                                      │                    │ │
│                                   worker                beat│
│                                Celery Worker       Celery Beat│
│                                      │                    │ │
│                                      └── same app image ──┘ │
└─────────────────────────────────────────────────────────────┘
```

## Services Compose cibles

```text
nginx   reverse proxy, seul service publié sur l'hôte
web     Django/DRF + Gunicorn
 db     PostgreSQL
redis   broker + result backend avec authentification
worker  Celery Worker, même image applicative que web
beat    Celery Beat + django-celery-beat, même image que web
```

## Contrat réseau

Le passage en conteneurs change le sens de « localhost-only ».

Dans la variante native, Gunicorn, PostgreSQL et Redis écoutaient sur `127.0.0.1` du serveur. Dans Compose, les services doivent communiquer via le réseau Docker et les noms DNS de services :

```text
web    → db:5432
web    → redis:6379
worker → db:5432
worker → redis:6379
beat   → db:5432
beat   → redis:6379
nginx  → web:8000
```

Gunicorn écoutera donc sur `0.0.0.0:8000` **dans le conteneur web**, mais le port `8000` ne sera pas publié sur l'hôte.

Contrat côté hôte :

```text
80    published=true
8000  published=false
5432  published=false
6379  published=false
```

## Ansible reste le plan de contrôle

La cible n'est pas de remplacer Ansible par Compose. Ansible doit préparer et converger l'hôte :

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

Le déploiement final devra utiliser `community.docker.docker_compose_v2` plutôt que lancer en parallèle les anciens rôles systemd `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx`.

Ces anciens rôles sont conservés dans la copie comme référence de migration tant que le portage Compose n'est pas terminé.

## Django REST Framework

La baseline expose déjà des endpoints JSON Django. Cette variante ajoutera explicitement **Django REST Framework** afin que l'API asynchrone soit portée par DRF et non uniquement par des vues JSON manuelles.

## Roadmap Docker Compose

```text
DC-00  Copie contrôlée de la baseline                 ✅
DC-01  Architecture Docker/Compose et contrats         ✅ DESIGN
DC-02  Dockerfile + .dockerignore + image non-root     ⏳
DC-03  Compose web/db/redis/worker/beat/nginx          ⏳
DC-04  Django REST Framework                           ⏳
DC-05  Rôle Ansible docker_engine                      ⏳
DC-06  Rôle Ansible compose_stack                      ⏳
DC-07  Vault → environnement/secrets Compose           ⏳
DC-08  Healthchecks + volumes + isolation réseau       ⏳
DC-09  Static gate                                     ⏳
DC-10  Première qualification E2E Compose              ⏳
DC-11  Idempotence stricte Ansible + stabilité Compose ⏳
DC-12  ZIP + SHA-256 + artifact GitHub Actions         ⏳
DC-13  Rapport final                                   ⏳
```

Le plan détaillé est dans `DOCKER_COMPOSE_IMPLEMENTATION_PLAN.md` et le fork contrôlé dans `DC_00_BASELINE_COPY.md`.
