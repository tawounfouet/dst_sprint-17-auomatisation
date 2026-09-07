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
UNIT TEST / STATIC GATE         ✅ GREEN
COMPOSE CONFIG VALIDATION       ✅ GREEN DEV/STG/PROD
DC-11 CI GREEN                  ✅
DEV FULL COMPOSE E2E            ✅ GREEN
DC-12 CI GREEN                  ✅
STRICT IDEMPOTENCE              ⏳
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Les statuts GREEN sont attribués uniquement aux gates réellement observés dans GitHub Actions. La qualification DEV Full utilise un runner Docker GitHub Actions ; elle ne constitue pas encore une qualification d'un VPS SSH/production.

## Stack cible

```text
Internet / host
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
DEV Full Compose                → PostgreSQL
STG/PROD                        → PostgreSQL obligatoire, SQLite interdit
```

Django utilise `django-environ`. L'API asynchrone utilise Django REST Framework.

## Image applicative

Une seule image non-root sert à `web`, `worker` et `beat`. Les dépendances sont installées au build ; l'image ne lance ni migration ni `collectstatic` à son démarrage.

```text
BUILD   → image immutable
RELEASE → migrations + collectstatic + schedule Beat
RUN     → web / worker / beat / nginx
```

DC-12 a réellement construit une seule image puis confirmé que `web`, `worker` et `beat` utilisent le même image ID.

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

Les secrets DEV/STG/PROD sont indépendants. `secret_hygiene.py` scanne repository, logs/trees et ZIP sans afficher les valeurs détectées. Les gates CI utilisent des secrets canaris/éphémères et ne persistent aucune valeur sensible.

## Runtime Hardening — DC-10

Le rôle `docker_runtime_hardening` gère le daemon et le firewall Docker :

```text
/etc/docker/daemon.json
├── live-restore=true
├── json-file log rotation
├── iptables=true
└── ip6tables=true

DOCKER-USER
   ↓
DST-COMPOSE-GUARD
```

Le champ Docker daemon `firewall-backend` a été retiré après validation réelle avec Docker Engine 28.0.4, qui le rejetait sur le runner. Le contrat reste explicitement fondé sur les règles iptables/`DOCKER-USER` gérées par le rôle ; la preuve runtime `DOCKER-USER` sur une cible de déploiement dédiée reste à produire.

Côté Compose : `no-new-privileges`, `cap_drop`, rootfs read-only lorsque compatible, `tmpfs`, `init=true` pour les process applicatifs, limites CPU/RAM/PIDs, rotation des logs, healthchecks renforcés, restart/recovery et segmentation `frontend` / `backend`.

Le contrat réseau est :

```text
DEV Full : Nginx seulement sur 127.0.0.1:8080 par défaut
STG/PROD: Nginx seulement sur :80 par défaut

8000 Gunicorn   published=false
5432 PostgreSQL published=false
6379 Redis      published=false
```

DC-12 a réellement confirmé ce contrat pour DEV Full depuis le runner hôte.

## DC-11 — Static Gate GREEN

Le gate canonique est :

```bash
cd ansible-project
./tests/static_checks.sh
```

Il exécute :

```text
secret hygiene repository
Bash/Python/YAML syntax
Django settings + DRF tests
SQLite DEV-only negative policies
Dockerfile non-root / SIGTERM checks
six-service Compose structure
runtime hardening checks
Ansible syntax-check
Docker Compose config DEV/STG/PROD
validation du Compose rendu
dockerd --validate lorsque disponible
```

Qualification canonique initiale :

```text
Run #7
Run ID 34133167102
Job ID 101777908524
HEAD 4c1a7f2a567739724794653d356ac17cc77312fb
Result SUCCESS
```

Le gate a été rejoué avec succès sur le HEAD DC-12 :

```text
Run ID 34135447373
Job ID 101785201716
HEAD f479e84b9152e3d9d1fab385b5256233a551f123
Result SUCCESS
```

## DC-12 — DEV Full E2E GREEN

Workflow :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-dev-e2e.yml
```

Qualification canonique :

```text
Run #2
Run ID 34135447354
Job ID 101785201280
HEAD f479e84b9152e3d9d1fab385b5256233a551f123
Result SUCCESS

Ubuntu 24.04.4
Python 3.12.14
Docker 28.0.4
Docker Compose v2.38.2
```

Preuves observées :

```text
application image built once                         ✅
PostgreSQL healthy + real SELECT 1                  ✅
Redis healthy + authenticated PING                  ✅
migrations + collectstatic + Beat schedule          ✅
nginx/web/db/redis/worker/beat healthy              ✅
web/worker/beat same built image                    ✅
HTTP health database/redis/celery via Nginx         ✅
add(21,21) → 42                                     ✅
uppercase(datascientest) → DATASCIENTEST            ✅
database_probe → SELECT 1                           ✅
Beat total_run_count >= 1                           ✅
periodic_heartbeat succeeded in Worker logs         ✅
127.0.0.1:8080 reachable                            ✅
127.0.0.1:8000 unreachable                          ✅
127.0.0.1:5432 unreachable                          ✅
127.0.0.1:6379 unreachable                          ✅
no Docker HostConfig.PortBindings on 8000/5432/6379 ✅
```

Verdict :

```text
DC12_DEV_FULL_E2E_PASS
```

La preuve réseau signifie que les ports internes ne sont pas publiés sur l'hôte/loopback. Elle ne prétend pas qu'une IP de bridge Docker soit intrinsèquement inaccessible depuis l'hôte sans politique firewall supplémentaire.

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
DC-11  Unit tests + static gate + Compose validation              ✅ GREEN
DC-12  DEV Full E2E                                               ✅ GREEN
DC-13  STG-like E2E + anti-SQLite runtime                         ⏭ NEXT
DC-14  Strict idempotence                                         ⏳
DC-15  Package + SHA-256 + artifact                               ⏳
DC-16  Final qualification report + 12-Factor matrix              ⏳
```

Les preuves historiques de la baseline native ne qualifient pas cette variante Docker Compose ; DC-11 et DC-12 constituent ses premières qualifications propres.
