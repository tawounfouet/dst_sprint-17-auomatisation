# Projet Ansible — Django/DRF + PostgreSQL + Redis + Celery + Docker Compose

Variante dérivée du projet qualifié `django-postgresql-redis-celery/` pour migrer l'exécution vers **Docker Engine + Docker Compose**, avec **Ansible comme plan de contrôle**.

## Statut

```text
BASELINE COPIED                 ✅
TARGET ARCHITECTURE             ✅ DESIGN
DJANGO CONFIG FOUNDATION        ✅ IMPLEMENTED
DJANGO-ENVIRON                  ✅ IMPLEMENTED
MULTI-ENV DEV/STG/PROD          ✅ IMPLEMENTED
SQLITE DEV-ONLY POLICY          ✅ QUALIFIED
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
STG-LIKE COMPOSE E2E            ✅ GREEN
ANTI-SQLITE RUNTIME STG         ✅ GREEN
DC-13 CI GREEN                  ✅
STRICT IDEMPOTENCE              ⏭ NEXT
PACKAGE + SHA-256               ⏳
FINAL REPORT                    ⏳
```

Les statuts GREEN sont attribués uniquement aux gates réellement observés dans GitHub Actions. Les qualifications DEV Full et STG-like utilisent des runners Docker GitHub Actions ; elles ne constituent pas encore une qualification d'un VPS SSH/production.

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

DC-13 a désormais qualifié cette politique au runtime STG : absence de `DATABASE_URL`, SQLite, schéma non PostgreSQL et `DJANGO_DEBUG=true` sont réellement rejetés par l'image immuable.

Django utilise `django-environ`. L'API asynchrone utilise Django REST Framework.

## Image applicative

Une seule image non-root sert à `web`, `worker` et `beat`. Les dépendances sont installées au build ; l'image ne lance ni migration ni `collectstatic` à son démarrage.

```text
BUILD   → image immutable
RELEASE → migrations + collectstatic + schedule Beat
RUN     → web / worker / beat / nginx
```

DC-12 a réellement construit une seule image puis confirmé que `web`, `worker` et `beat` utilisent le même image ID en DEV Full.

DC-13 va plus loin : l'image est construite hors Compose, promue via un registry localhost éphémère pour obtenir une vraie référence `repository@sha256`, puis le registry est supprimé avant le déploiement. Le runtime STG-like utilise exclusivement cette référence digest-pinned avec `--no-build --pull never`.

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

DC-12 a réellement confirmé ce contrat pour DEV Full. DC-13 l'a confirmé à nouveau dans un runtime STG-like avec Nginx temporairement publié sur `0.0.0.0:8081` pour éviter un conflit avec le runner.

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

Le gate a été rejoué avec succès sur le commit d'implémentation DC-13 :

```text
Run #10
Run ID 34138698606
Job ID 101795532634
HEAD cbc4845f61fd73bb43f408a8c0cc170217824fe2
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

La régression DEV Full a été rejouée avec succès lors de l'implémentation DC-13 :

```text
Run #3
Run ID 34138698561
Job ID 101795532662
HEAD cbc4845f61fd73bb43f408a8c0cc170217824fe2
Result SUCCESS
```

## DC-13 — STG-like E2E + anti-SQLite GREEN

Workflow :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-stg-e2e.yml
```

Qualification canonique :

```text
Run #2
Run ID 34138825440
Job ID 101795932401
HEAD 54776ceb82d55c7356df1e73d38054ba692088cb
Result SUCCESS

Started 2026-09-07T15:32:23Z
Updated 2026-09-07T15:33:44Z
Ubuntu 24.04.4
Python 3.12.14
Docker 28.0.4
Docker Compose v2.38.2
```

Preuves observées :

```text
application image built outside Compose                      ✅
image promoted to repository@sha256                           ✅
registry promotion removed before deployment                  ✅
third-party images preloaded outside Compose                  ✅
Compose build for web/worker/beat absent                      ✅
Compose runtime --no-build --pull never                       ✅
APPLICATION_ENV=stg                                           ✅
DJANGO_SETTINGS_MODULE=config.settings.stg                     ✅
DJANGO_DEBUG=false                                             ✅
Django database backend = PostgreSQL                          ✅
missing DATABASE_URL rejected                                 ✅
SQLite DATABASE_URL rejected                                  ✅
non-PostgreSQL DATABASE_URL rejected                          ✅
DJANGO_DEBUG=true rejected                                    ✅
PostgreSQL healthy + SELECT 1                                 ✅
Redis healthy + authenticated PING                            ✅
migrate + collectstatic + Beat schedule                      ✅
nginx/web/db/redis/worker/beat healthy                        ✅
web/worker/beat exact same prebuilt digest-pinned image       ✅
health/database/redis/celery via Nginx                        ✅
add(21,21) → 42                                               ✅
uppercase(datascientest) → DATASCIENTEST                      ✅
database_probe → SELECT 1                                     ✅
Beat total_run_count >= 1                                     ✅
periodic_heartbeat succeeded in Worker logs                   ✅
127.0.0.1:8081 reachable                                      ✅
127.0.0.1:8000/5432/6379 unreachable                          ✅
HostConfig.PortBindings absent on 8000/5432/6379              ✅
```

Digest applicatif observé dans le run canonique :

```text
sha256:f1fe85b62f40be2f2fda4a744ed736758b01c2cf077a87ad9e744bbe10169b0f
```

Verdicts :

```text
DC13_PARITY_PASS: STG-like preserves DC-12 functional task/health/Beat behavior with stricter runtime policy
DC13_STG_LIKE_E2E_PASS
```

Le premier run DC-13 a échoué parce que `--pull never` était appliqué alors que l'image tierce `redis:7.4-alpine` n'était pas encore présente sur le runner. La correction précharge PostgreSQL/Redis/Nginx explicitement **hors Compose** ; le contrat STG reste donc sans build et sans pull implicite au moment du déploiement.

La référence digest-pinned est obtenue via un registry localhost éphémère. Cela qualifie l'immutabilité `repository@sha256`, mais pas encore un registry distant de production, son authentification, sa signature ou sa provenance supply-chain.

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
DC-13  STG-like E2E + anti-SQLite runtime                         ✅ GREEN
DC-14  Strict idempotence                                         ⏭ NEXT
DC-15  Package + SHA-256 + artifact                               ⏳
DC-16  Final qualification report + 12-Factor matrix              ⏳
```

Les preuves historiques de la baseline native ne qualifient pas cette variante Docker Compose. DC-11, DC-12 et DC-13 constituent désormais ses qualifications propres et successives : statique/config, DEV Full runtime puis STG-like runtime immuable.
