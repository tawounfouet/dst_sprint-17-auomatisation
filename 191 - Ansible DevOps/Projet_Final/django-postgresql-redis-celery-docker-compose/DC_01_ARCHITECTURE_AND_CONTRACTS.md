# DC-01 — Architecture Docker Compose et contrats

## Statut

**DESIGN VALIDÉ ✅ — IMPLÉMENTATION À VENIR**

## Architecture cible

```text
                         Client / runner
                              │
                              │ HTTP :80
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ server1 — Ubuntu 24.04                                     │
│                                                             │
│ Docker Engine                                               │
│ ┌──────────────── Docker Compose ─────────────────────────┐ │
│ │                                                        │ │
│ │  nginx                                                 │ │
│ │   :80                                                  │ │
│ │    │                                                   │ │
│ │    ▼                                                   │ │
│ │  web                                                   │ │
│ │  Django + DRF + Gunicorn :8000                         │ │
│ │    │                         │                         │ │
│ │    │ SQL                     │ broker/results          │ │
│ │    ▼                         ▼                         │ │
│ │   db                       redis                       │ │
│ │ PostgreSQL :5432          Redis :6379 + auth           │ │
│ │    ▲                         ▲                         │ │
│ │    │                         │                         │ │
│ │    └────── worker ───────────┘                         │ │
│ │           Celery Worker                                │ │
│ │                                                        │ │
│ │    db ◄────── beat ───────────────► redis              │ │
│ │             Celery Beat + DatabaseScheduler            │ │
│ └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Contrat de service

| Service | Rôle | Image | Port conteneur | Port hôte |
|---|---|---|---:|---:|
| `nginx` | reverse proxy | nginx | 80 | 80 |
| `web` | Django/DRF + Gunicorn | image app | 8000 | aucun |
| `db` | PostgreSQL | postgres | 5432 | aucun |
| `redis` | broker/result backend | redis | 6379 | aucun |
| `worker` | Celery Worker | image app | aucun | aucun |
| `beat` | Celery Beat | image app | aucun | aucun |

## Contrat DNS Compose

L'application n'utilise plus des adresses `127.0.0.1` entre services :

```text
POSTGRES_HOST=db
REDIS_HOST=redis
NGINX_UPSTREAM=web:8000
```

Compose fournit la résolution DNS interne par nom de service.

## Contrat Gunicorn

Dans le conteneur `web` :

```text
0.0.0.0:8000
```

Ce bind est nécessaire pour que `nginx` puisse joindre `web` via le réseau Docker. Il ne rend pas Gunicorn public car aucun mapping `8000:8000` ne doit exister.

## Contrat PostgreSQL

PostgreSQL accepte les connexions du réseau Compose, mais `5432` n'est jamais publié sur l'hôte. Le compte applicatif reste distinct du superuser PostgreSQL.

## Contrat Redis

Redis doit :

```text
exiger une authentification
rester non publié côté hôte
servir le broker Celery
servir le result backend
```

Les URL Redis sont construites à partir d'un secret runtime et ne sont jamais stockées en clair dans Git.

## Contrat Celery

`worker` et `beat` utilisent exactement la même image que `web` pour garantir que code, dépendances Django et tâches Celery sont cohérents.

```text
web    = image app + commande Gunicorn
worker = image app + commande Celery worker
beat   = image app + commande Celery beat
```

## Contrat de persistance

PostgreSQL doit utiliser un volume nommé dédié. Les fichiers statiques doivent être accessibles à Nginx via volume partagé ou stratégie de build explicite. Le choix Redis persistant/éphémère sera documenté dans DC-08.

## Contrat Ansible

Ansible reste responsable de l'hôte et de la convergence de Compose :

```text
common → docker_engine → compose_stack
```

Le futur rôle `compose_stack` doit utiliser `community.docker.docker_compose_v2`.

## Contrat de qualification

Pour être GREEN, la nouvelle variante devra prouver au minimum :

```text
6 services attendus
health db/redis/web/nginx
GET health via Nginx
DRF API fonctionnelle
Celery add(21,21) → 42
Celery database_probe → SELECT 1
Celery Beat réellement déclenché
80 publié
8000/5432/6379 non publiés
second site.yml → changed=0
runtime toujours GREEN après idempotence
```

Aucune preuve RC de la baseline native ne satisfait ces gates à la place de la nouvelle qualification.
