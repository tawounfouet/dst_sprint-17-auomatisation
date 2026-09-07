# DC-13 — STG-like E2E + anti-SQLite Runtime Qualification

## Statut

```text
IMPLEMENTATION                         ✅
IMMUTABLE IMAGE PREPARATION            ✅ QUALIFIED
ZERO COMPOSE BUILD IN STG              ✅ QUALIFIED
APPLICATION_ENV=stg                    ✅ QUALIFIED
config.settings.stg                    ✅ QUALIFIED
DEBUG=false                            ✅ QUALIFIED
POSTGRESQL REQUIRED                    ✅ QUALIFIED
MISSING DATABASE_URL REJECTION         ✅ QUALIFIED
SQLITE DATABASE_URL REJECTION          ✅ QUALIFIED
INVALID DATABASE_URL REJECTION         ✅ QUALIFIED
DJANGO_DEBUG=true REJECTION            ✅ QUALIFIED
SIX REAL SERVICES                      ✅ QUALIFIED
CELERY ROUND-TRIPS                     ✅ QUALIFIED
BEAT PERIODIC PROOF                    ✅ QUALIFIED
HOST PORT ISOLATION                    ✅ QUALIFIED
CI GREEN                               ✅
```

DC-13 élève la qualification Docker Compose au niveau **STG-like**. Contrairement à DC-12, la phase de déploiement ne possède aucun `build:` Compose et ne peut ni reconstruire ni tirer implicitement l'image applicative.

## Qualification canonique

```text
Workflow : Ansible Django PostgreSQL Redis Celery Compose STG-like E2E
Run      : #2
Run ID   : 34138825440
Job ID   : 101795932401
HEAD     : 54776ceb82d55c7356df1e73d38054ba692088cb
Result   : SUCCESS

Started  : 2026-09-07T15:32:23Z
Updated  : 2026-09-07T15:33:44Z

Runner   : Ubuntu 24.04.4
Python   : 3.12.14
Docker   : 28.0.4
Compose  : v2.38.2
```

Le verdict final observé est :

```text
DC13_STG_LIKE_E2E_PASS
```

Le même run termine également par :

```text
DC13_PARITY_PASS: STG-like preserves DC-12 functional task/health/Beat behavior with stricter runtime policy
```

## Contrat d'image immutable

Le workflow prépare d'abord l'image en dehors de Docker Compose :

```text
Dockerfile
   ↓ docker build
image locale mutable
   ↓ push vers registry localhost éphémère
repository digest sha256
   ↓ suppression du registry
APP_IMAGE=127.0.0.1:<port>/datascientest-django@sha256:<digest>
```

Pour le run canonique, le repository digest observé est :

```text
sha256:f1fe85b62f40be2f2fda4a744ed736758b01c2cf077a87ad9e744bbe10169b0f
```

Le registry de promotion ne fait pas partie de la stack applicative et est supprimé avant le déploiement STG-like. Le harness vérifie ensuite que la référence digest-pinned reste résoluble localement.

Le déploiement et les opérations one-shot utilisent :

```text
--no-build
--pull never
```

Le Compose rendu a été réellement vérifié avec :

```text
services exacts = nginx, web, db, redis, worker, beat
web build       = absent
worker build    = absent
beat build      = absent
web image       = APP_IMAGE@sha256
worker image    = APP_IMAGE@sha256
beat image      = APP_IMAGE@sha256
```

Preuve observée :

```text
DC13_COMPOSE_PASS: STG uses six services, zero Compose builds and one digest-pinned app image
DC13_ARTIFACT_PASS: web/worker/beat run the exact prebuilt digest-pinned image
```

## Images d'infrastructure

Le premier run DC-13 a mis en évidence une nuance importante. Le gate interdisait correctement tout pull Compose avec `--pull never`, mais le runner GitHub ne possédait pas encore `redis:7.4-alpine`. Le run #1 a donc échoué avec :

```text
No such image: redis:7.4-alpine
```

Ce n'était pas un échec fonctionnel de l'application ni de la politique STG. La correction consiste à précharger explicitement, **hors Compose**, les images tierces de runtime :

```text
postgres:16-alpine
redis:7.4-alpine
nginx:1.27-alpine
```

Le contrat reste donc strict :

```text
application image → construite/promue avant déploiement, digest-pinned
infra images       → préchargées avant déploiement
Compose            → --no-build --pull never
```

Le run canonique a observé :

```text
DC13_INFRA_IMAGES_PASS: third-party runtime images preloaded outside Compose
```

## Politique runtime STG

Le runtime qualifié est :

```text
APPLICATION_ENV=stg
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_DEBUG=false
DATABASES.default.ENGINE=django.db.backends.postgresql
```

Le snapshot positif réellement observé est :

```text
DC13_POLICY_PASS: stg + config.settings.stg + DEBUG=false + PostgreSQL backend
```

Cette preuve vérifie le backend Django chargé, pas seulement le contenu du fichier Compose.

## Tests négatifs anti-SQLite

DC-13 exécute directement l'image immutable avec `config.settings.stg` et `--network none`. Les quatre refus ont été observés :

```text
DC13_POLICY_PASS: missing DATABASE_URL rejected
DC13_POLICY_PASS: SQLite DATABASE_URL rejected
DC13_POLICY_PASS: invalid DATABASE_URL scheme rejected
DC13_POLICY_PASS: DJANGO_DEBUG=true rejected
```

Les cas couverts sont donc :

```text
DATABASE_URL absente                       → FAIL attendu
DATABASE_URL=sqlite:///...                 → FAIL attendu
DATABASE_URL avec schéma non PostgreSQL    → FAIL attendu
DJANGO_DEBUG=true                          → FAIL attendu
```

L'utilisation de `--network none` permet de distinguer un refus de politique de configuration d'un simple échec de connectivité vers la base.

## PostgreSQL et Redis réels

Après les tests négatifs, la stack démarre réellement PostgreSQL et Redis puis exige leurs healthchecks.

Preuves observées :

```text
DC13_HEALTH_PASS: db
DC13_HEALTH_PASS: redis
DC13_POSTGRES_PASS: SELECT 1
DC13_REDIS_PASS: authenticated PING
```

Redis est sondé avec `REDISCLI_AUTH` ; aucun mot de passe n'est passé à `redis-cli -a`.

## Release phase

La même image digest-pinned exécute :

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py ensure_demo_periodic_task --seconds 5
```

Preuve observée :

```text
DC13_RELEASE_PASS: migrate + collectstatic + periodic schedule
```

Aucun rebuild et aucun pull Compose ne sont autorisés pendant cette phase.

## Six services STG-like

La cible runtime a été réellement démarrée :

```text
nginx
web
db
redis
worker
beat
```

Les six services sont devenus `healthy`, puis un second snapshot final a confirmé qu'ils étaient toujours `healthy` après tous les tests fonctionnels.

Preuve observée :

```text
DC13_SERVICES_PASS: six containers running
```

La photographie finale montre également :

```text
nginx  → 0.0.0.0:8081->80/tcp
web    → 8000/tcp, non publié hôte
db     → aucun port publié hôte
redis  → aucun port publié hôte
worker → aucun port publié
beat   → aucun port publié
```

## Round-trips fonctionnels

DC-13 conserve les mêmes contrats fonctionnels que DC-12, mais sous politiques STG plus strictes.

Preuves observées :

```text
DC13_HTTP_PASS: health/database/redis/celery
DC13_HTTP_PASS: /api/info/
DC13_TASK_PASS: add(21,21)=42
DC13_TASK_PASS: uppercase(datascientest)
DC13_TASK_PASS: database_probe SELECT 1
```

`database_probe()` constitue toujours une preuve end-to-end :

```text
host
  ↓ HTTP
Nginx
  ↓
Django / DRF
  ↓ enqueue
Redis broker
  ↓
Celery Worker
  ↓ psycopg
PostgreSQL
  ↓ SELECT 1
Redis result backend
  ↓ poll HTTP
host
```

## Preuve Celery Beat

DC-13 exige simultanément :

```text
PeriodicTask.total_run_count >= 1
ET
worker logs contenant tasks_demo.periodic_heartbeat ... succeeded
```

Le run canonique a observé :

```text
DC13_BEAT_PASS: total_run_count>=1 and worker logged successful heartbeat
```

La simple présence du process Beat ou de la ligne en base n'est donc pas considérée comme suffisante.

## Contrat réseau STG-like

Le port public de qualification est :

```text
0.0.0.0:8081 → nginx:80
```

Les preuves depuis l'hôte sont :

```text
127.0.0.1:8081 reachable=true
127.0.0.1:8000 reachable=false
127.0.0.1:5432 reachable=false
127.0.0.1:6379 reachable=false
```

Le gate vérifie aussi directement `HostConfig.PortBindings` :

```text
web:8000   published=false
db:5432    published=false
redis:6379 published=false
```

Preuves observées :

```text
DC13_NETWORK_PASS: 127.0.0.1:8081 reachable=true
DC13_NETWORK_PASS: 127.0.0.1:8000 reachable=false
DC13_NETWORK_PASS: 127.0.0.1:5432 reachable=false
DC13_NETWORK_PASS: 127.0.0.1:6379 reachable=false
DC13_NETWORK_PASS: web:8000 published=false
DC13_NETWORK_PASS: db:5432 published=false
DC13_NETWORK_PASS: redis:6379 published=false
DC13_RUNTIME_VALIDATION_PASS
```

Cette qualification prouve l'absence de publication Docker vers l'hôte. Elle ne prétend pas encore qualifier la politique `DOCKER-USER` sur une machine de staging réelle ni un firewall cloud/VPS.

## Comparaison avec DC-12 DEV Full

```text
                         DC-12 DEV Full              DC-13 STG-like
Compose build            autorisé                    interdit
APP_IMAGE                tag local                   repository@sha256
Compose pull             comportement local DEV      --pull never
settings                 config.settings.dev         config.settings.stg
APPLICATION_ENV          dev                         stg
DEBUG                    false dans le gate           false obligatoire
SQLite sans DB URL       autorisé en DEV Lite        interdit
PostgreSQL               réel en DEV Full            obligatoire
six services             réel                        réel
add / uppercase          réel                        réel
database_probe           réel SELECT 1               réel SELECT 1
Beat                     émission + consommation      émission + consommation
ports 8000/5432/6379     non publiés                 non publiés
```

DC-13 ne remplace pas DC-12 : il démontre que le même comportement fonctionnel subsiste lorsque les politiques d'exécution deviennent plus strictes.

La régression DC-12 a d'ailleurs été rejouée avec succès sur le commit d'implémentation DC-13 :

```text
DEV Full run #3
Run ID 34138698561
Job ID 101795532662
HEAD cbc4845f61fd73bb43f408a8c0cc170217824fe2
Result SUCCESS
```

Le static gate DC-11 a également été rejoué avec succès sur ce même commit :

```text
Static Gate run #10
Run ID 34138698606
Job ID 101795532634
HEAD cbc4845f61fd73bb43f408a8c0cc170217824fe2
Result SUCCESS
```

Le commit runtime canonique `54776ceb...` ne modifie ensuite que le workflow DC-13 afin de précharger les images tierces avant le déploiement `--pull never`.

## Workflow et harness

Workflow :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-stg-e2e.yml
```

Harness :

```text
ansible-project/tests/e2e/
├── prepare_stg_immutable_image.sh
├── run_stg_like_e2e.sh
└── validate_stg_like_e2e.py
```

## Frontière de la qualification

DC-13 ne prouve pas encore :

```text
idempotence stricte Ansible/Compose
DOCKER-USER sur cible de staging dédiée
reboot/recovery après déploiement
TLS/HTTPS
registry distant réel avec authentification
signature/SBOM/provenance supply-chain
package final + SHA-256
VPS SSH/production
```

L'image de qualification est promue dans un registry local éphémère afin d'obtenir et d'exercer une vraie référence `repository@sha256`. Cela qualifie le contrat immuable du déploiement, pas un registry de production distant.

## Verdict

```text
DC-13 STG-like E2E + anti-SQLite Runtime Qualification  ✅ GREEN
```

## Prochain jalon

```text
DC-14 — Strict Idempotence
```
