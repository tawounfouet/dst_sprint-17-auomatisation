# Projet Ansible — Django/DRF + PostgreSQL + Redis + Celery + Docker Compose

Variante dérivée du projet qualifié `django-postgresql-redis-celery/` pour migrer l'exécution vers **Docker Engine + Docker Compose**, avec **Ansible comme plan de contrôle**.

## Statut

```text
BASELINE COPIED                 ✅
TARGET ARCHITECTURE             ✅ DESIGN
DJANGO CONFIG FOUNDATION        ✅ IMPLEMENTED
DJANGO-ENVIRON                  ✅ IMPLEMENTED
MULTI-ENV DEV/STG/PROD          ✅ IMPLEMENTED
SQLITE DEV-ONLY POLICY          ✅ IMPLEMENTED
DJANGO REST FRAMEWORK           ✅ IMPLEMENTED
12-FACTOR DOCKER IMAGE          ✅ IMPLEMENTED
BASE DOCKER COMPOSE STACK       ✅ IMPLEMENTED
MULTI-ENV COMPOSE               ✅ IMPLEMENTED
ANSIBLE DOCKER ENGINE           ✅ IMPLEMENTED
ANSIBLE COMPOSE DEPLOY          ✅ IMPLEMENTED
INVENTORIES DEV/STG/PROD        ✅ IMPLEMENTED
SECRETS / ENV HARDENING         ⏳
RUNTIME HARDENING               ⏳
STATIC GATE                     ⏳
COMPOSE E2E                     ⏳
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Aucun statut runtime GREEN n'est revendiqué tant que les futurs gates Ansible/Docker/Compose/CI n'ont pas été réellement exécutés.

## Django / DRF / configuration

La configuration est multi-environnement :

```text
django-app/config/settings/
├── base.py
├── database.py
├── dev.py
├── stg.py
└── prod.py
```

Politique DB :

```text
DEV Lite + DATABASE_URL absente → SQLite autorisé
DEV Full Compose                → PostgreSQL obligatoire
STG/PROD                        → PostgreSQL obligatoire, SQLite interdit
```

L'API asynchrone utilise Django REST Framework et conserve les endpoints Celery historiques.

## Image 12-Factor

Une seule image applicative non-root sert à :

```text
             APP_IMAGE
           /     |     \
        web    worker   beat
     Gunicorn  Celery  Celery Beat
```

Dépendances au build, logs stdout/stderr, SIGTERM, pas de migration automatique au boot.

## Docker Compose

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
└── compose.prod.yml
```

Services :

```text
nginx
web
db
redis
worker
beat
```

DEV Full construit localement l'image commune. STG/PROD exigent une `APP_IMAGE` déjà construite et ne buildent pas sur le serveur.

## Orchestration Ansible active — DC-08

Le point d'entrée actif est désormais :

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

Les anciens rôles natifs `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx` restent comme référence historique mais ne sont plus appelés par `playbooks/site.yml`.

Le rôle `compose_stack` :

```text
valide environment + APP_IMAGE
        ↓
déploie docker/ sous /opt/datascientest-compose
        ↓
rend .env.runtime en 0600
        ↓
docker compose config --quiet
        ↓
démarre db + redis + web
        ↓
migrate / collectstatic / PeriodicTask en one-shot
        ↓
converge les 6 services avec docker_compose_v2
```

En STG/PROD, `APP_IMAGE` doit correspondre strictement à :

```text
registry/path/image@sha256:<64 hex>
```

## Inventories

```text
ansible-project/inventories/
├── dev/
├── stg/
└── prod/
```

Chaque environnement fournit des exemples de `hosts`, `host_vars`, `group_vars/all.yml` et `vault.example.yml`. Les vrais `hosts.yml`, `host_vars/server1.yml` et `vault.yml` sont ignorés par Git.

La topologie active ne contient plus de groupe `database` : un seul hôte `app` héberge Docker et PostgreSQL vit dans la stack Compose.

## Secrets

Les trois secrets de base restent :

```text
vault_django_secret_key
vault_postgresql_password
vault_redis_password
```

Ils alimentent un fichier runtime distant protégé ; les passwords sont URL-encodés lorsqu'ils entrent dans `DATABASE_URL` et les URLs Redis. DC-09 renforcera la gestion complète du lifecycle et les gates anti-fuite.

## Contrat réseau cible

```text
DEV Full : Nginx seulement sur 127.0.0.1:8080 par défaut
STG/PROD: Nginx seulement sur :80 par défaut

8000 Gunicorn   published=false
5432 PostgreSQL published=false
6379 Redis      published=false
```

## Roadmap

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
DC-09  Secure runtime configuration                               ⏭ NEXT
DC-10  Runtime hardening                                          ⏳
DC-11  Unit tests + static gate                                   ⏳
DC-12  DEV Full E2E                                               ⏳
DC-13  STG-like E2E + anti-SQLite tests                           ⏳
DC-14  Strict idempotence                                         ⏳
DC-15  Package + SHA-256 + artifact                               ⏳
DC-16  Final qualification report + 12-Factor matrix              ⏳
```

Les preuves historiques de la baseline native ne qualifient pas cette variante Docker Compose.
