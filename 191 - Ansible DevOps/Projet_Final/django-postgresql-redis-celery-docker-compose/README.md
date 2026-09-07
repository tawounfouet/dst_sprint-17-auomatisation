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
SECURE RUNTIME CONFIGURATION    ✅ IMPLEMENTED
RUNTIME HARDENING               ✅ IMPLEMENTED
STATIC GATE                     ⏳
COMPOSE E2E                     ⏳
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Aucun statut runtime GREEN n'est revendiqué tant que les gates Ansible/Docker/Compose/CI n'ont pas été réellement exécutés.

## Stack cible

```text
Internet
   │
   ▼
nginx
   │ frontend
   ▼
web (Django/DRF + Gunicorn)
   │ backend
   ├──────────► PostgreSQL
   └──────────► Redis + auth
                    ▲
              worker / beat
```

Services Compose : `nginx`, `web`, `db`, `redis`, `worker`, `beat`.

## Configuration Django

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

Django utilise `django-environ`. L'API asynchrone utilise Django REST Framework.

## Image applicative

Une seule image non-root sert à `web`, `worker` et `beat`. Les dépendances sont installées au build ; l'image ne lance ni migration ni `collectstatic` à son démarrage.

```text
BUILD   → image immutable
RELEASE → image + config + migrations one-shot
RUN     → web / worker / beat / nginx
```

## Orchestration Ansible active

```text
common
  ↓
docker_engine
  ↓
docker_runtime_hardening
  ↓
compose_stack
```

Les anciens rôles natifs `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx` restent comme référence historique mais ne sont plus appelés par `playbooks/site.yml`.

## Secure Runtime Configuration

```text
Vault DEV/STG/PROD
       ↓
validation environment + qualité
       ↓
URLs dérivées avec urlencode
       ↓
.env.runtime root:root 0600
       ↓
Docker Compose
```

Les secrets DEV/STG/PROD sont indépendants. `secret_hygiene.py` scanne repository, logs/trees et ZIP sans afficher les valeurs détectées.

## Runtime Hardening — DC-10

Le rôle `docker_runtime_hardening` gère le daemon et le firewall Docker :

```text
/etc/docker/daemon.json
├── live-restore=true
├── json-file log rotation
├── iptables=true
└── firewall-backend=iptables

DOCKER-USER
   ↓
DST-COMPOSE-GUARD
```

Le script firewall est idempotent et un drop-in systemd réapplique la politique après restart Docker.

Côté Compose :

```text
no-new-privileges
cap_drop ALL lorsque compatible
read-only rootfs lorsque compatible
tmpfs runtime
init=true pour web/worker/beat
CPU/RAM/PID limits
json-file log rotation
healthchecks renforcés
restart unless-stopped
SIGTERM + stop_grace_period
frontend/backend segmentation
backend internal=true
```

Le contrat réseau reste :

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
DC-09  Secure runtime configuration                               ✅ IMPLEMENTED
DC-10  Runtime hardening                                          ✅ IMPLEMENTED
DC-11  Unit tests + static gate                                   ⏭ NEXT
DC-12  DEV Full E2E                                               ⏳
DC-13  STG-like E2E + anti-SQLite tests                           ⏳
DC-14  Strict idempotence                                         ⏳
DC-15  Package + SHA-256 + artifact                               ⏳
DC-16  Final qualification report + 12-Factor matrix              ⏳
```

Les preuves historiques de la baseline native ne qualifient pas cette variante Docker Compose.
