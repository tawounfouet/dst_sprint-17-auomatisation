# DC-12 — DEV Full E2E Qualification

## Statut

```text
IMPLEMENTATION                  ✅
APPLICATION IMAGE BUILD         ✅ GREEN
POSTGRESQL REAL                 ✅ GREEN
REDIS REAL                      ✅ GREEN
SIX SERVICES HEALTH             ✅ GREEN
HTTP VIA NGINX                  ✅ GREEN
CELERY add(21,21)=42            ✅ GREEN
CELERY uppercase                ✅ GREEN
CELERY database_probe SELECT 1  ✅ GREEN
BEAT PERIODIC EXECUTION         ✅ GREEN
HOST PORT ISOLATION             ✅ GREEN
CI GREEN                        ✅
```

DC-12 est le premier jalon de la variante Docker Compose qui apporte une preuve runtime complète en DEV Full. Le gate ne se contente plus de `docker compose config` : il construit réellement l'image applicative, démarre PostgreSQL, Redis, Django/Gunicorn, Celery Worker, Celery Beat et Nginx, puis exerce la chaîne de bout en bout.

## Qualification canonique

```text
Workflow : Ansible Django PostgreSQL Redis Celery Compose DEV Full E2E
Run      : #2
Run ID   : 34135447354
Job ID   : 101785201280
HEAD     : f479e84b9152e3d9d1fab385b5256233a551f123

Started  : 2026-09-07T14:53:57Z
Updated  : 2026-09-07T14:55:01Z
Result   : SUCCESS

Runner   : Ubuntu 24.04.4
Python   : 3.12.14
Docker   : 28.0.4
Compose  : v2.38.2
```

Le workflow canonique est :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-dev-e2e.yml
```

Le Static Gate DC-11 a également été réexécuté sur le même HEAD et reste GREEN :

```text
Run ID : 34135447373
Job ID : 101785201716
Result : SUCCESS
```

## Harness

```text
ansible-project/tests/e2e/
├── run_dev_full_e2e.sh
└── validate_dev_full_e2e.py
```

Le harness crée un environnement DEV Full éphémère avec secrets aléatoires non persistés, un project name Compose unique et un nettoyage automatique `docker compose down --volumes --remove-orphans`.

Les diagnostics de panne sont redacted avant affichage et le fichier d'environnement temporaire n'est jamais imprimé.

## Build once réellement observé

L'image applicative est construite une fois :

```text
docker compose ... build web
```

Le run canonique a produit :

```text
DC12_BUILD_PASS: application image built once
```

Puis `web`, `worker` et `beat` sont lancés avec `--no-build`. Leur image ID est comparé à l'image construite :

```text
DC12_IMAGE_PASS: web/worker/beat share the one built image
```

Cela matérialise le contrat :

```text
BUILD   → une image applicative immutable
RELEASE → migrations + static + schedule
RUN     → web / worker / beat
```

## PostgreSQL réel

Le gate démarre d'abord `db` et attend son healthcheck. Une vraie requête est ensuite exécutée dans PostgreSQL :

```sql
SELECT 1;
```

Preuve observée :

```text
DC12_HEALTH_PASS: db
DC12_POSTGRES_PASS: SELECT 1
```

Le `database_probe` Celery fournit ensuite une seconde preuve, cette fois à travers toute la chaîne applicative.

## Redis réel

Redis est démarré avec authentification et son healthcheck doit devenir GREEN. La validation utilise `REDISCLI_AUTH`, jamais `redis-cli -a` :

```text
DC12_HEALTH_PASS: redis
DC12_REDIS_PASS: authenticated PING
```

Le broker `/0` et le result backend `/1` sont ensuite utilisés par les vrais round-trips Celery.

## Release phase

Avant le démarrage permanent des process applicatifs, trois commandes one-shot sont exécutées avec l'image construite :

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput --verbosity 0
python manage.py ensure_demo_periodic_task --seconds 5
```

Preuve observée :

```text
DC12_RELEASE_PASS: migrate + collectstatic + periodic schedule
```

Les migrations Django et `django-celery-beat` ont été réellement appliquées sur PostgreSQL.

## Six services réellement healthy

La cible runtime est exactement :

```text
nginx
web
db
redis
worker
beat
```

Le premier snapshot a produit :

```text
DC12_HEALTH_PASS: db
DC12_HEALTH_PASS: redis
DC12_HEALTH_PASS: web
DC12_HEALTH_PASS: worker
DC12_HEALTH_PASS: beat
DC12_HEALTH_PASS: nginx
DC12_SERVICES_PASS: six containers running
```

Une seconde photographie complète a été réalisée en fin de qualification et les six services étaient toujours `healthy`.

## HTTP réel via Nginx

Le validateur appelle depuis le runner hôte :

```text
GET /health/
GET /health/database/
GET /health/redis/
GET /health/celery/
GET /api/info/
```

Les réponses ont confirmé Django, PostgreSQL, Redis, au moins un worker Celery et l'identité de la stack :

```text
DC12_HTTP_PASS: health/database/redis/celery
DC12_HTTP_PASS: /api/info/
```

## Round-trips Celery réels

Les tâches sont soumises via Nginx/DRF, un `task_id` est récupéré puis le result backend est pollé jusqu'à `SUCCESS`.

Résultats observés :

```text
DC12_TASK_PASS: add(21,21)=42
DC12_TASK_PASS: uppercase(datascientest)
DC12_TASK_PASS: database_probe SELECT 1
```

Le contrat fonctionnel réellement qualifié est donc :

```text
add(21,21)               → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe()          → {"database": "connected", "query": 1}
```

`database_probe()` exerce :

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

## Preuve Celery Beat réelle

Le schedule `datascientest-demo-heartbeat` est configuré à 5 secondes pour la qualification.

Le gate ne se contente pas du statut du process Beat. Il exige simultanément :

```text
PeriodicTask.total_run_count >= 1
ET
worker logs contenant tasks_demo.periodic_heartbeat ... succeeded
```

Preuve canonique :

```text
DC12_BEAT_PASS: total_run_count>=1 and worker logged successful heartbeat
```

Beat a donc réellement publié au moins une occurrence et le Worker l'a réellement consommée avec succès.

## Isolation des ports depuis l'hôte

Le seul port publié en DEV Full est :

```text
127.0.0.1:8080 → nginx:80
```

Les probes TCP réelles depuis l'hôte ont donné :

```text
DC12_NETWORK_PASS: 127.0.0.1:8080 reachable=true
DC12_NETWORK_PASS: 127.0.0.1:8000 reachable=false
DC12_NETWORK_PASS: 127.0.0.1:5432 reachable=false
DC12_NETWORK_PASS: 127.0.0.1:6379 reachable=false
```

Le gate vérifie en plus `HostConfig.PortBindings` des conteneurs et exige l'absence de host binding pour les ports internes :

```text
DC12_NETWORK_PASS: web:8000 published=false
DC12_NETWORK_PASS: db:5432 published=false
DC12_NETWORK_PASS: redis:6379 published=false
```

Cette vérification est volontairement basée sur `docker inspect` plutôt que sur `docker compose port`, car un port `expose` peut être affiché par certains chemins CLI sans constituer un host binding réel.

Le résultat final de `docker compose ps` confirme que seul Nginx porte une publication hôte ; `web` affiche `8000/tcp`, qui est un port exposé au réseau Docker et non un mapping vers l'hôte.

## Première exécution et correction du gate

Le run #1 (`34135203656`) avait déjà validé les six services, PostgreSQL, Redis, les trois tâches Celery, Beat et les probes TCP. Il a toutefois échoué à cause d'un faux négatif du harness : `docker compose port web 8000` renvoyait `:0` pour le port exposé.

Le gate a été corrigé pour lire le contrat effectif `HostConfig.PortBindings`. Le run #2 sur le commit `f479e84b...` est alors devenu la qualification canonique GREEN.

## Frontière de la preuve réseau

DC-12 prouve que `8000`, `5432` et `6379` ne sont pas publiés ni joignables sur `127.0.0.1` depuis l'hôte. Il ne prétend pas qu'un hôte Docker ne pourrait jamais atteindre directement une IP de bridge de conteneur : cette propriété nécessiterait une politique firewall hôte explicite et relève notamment de la future qualification `DOCKER-USER`.

## Ce que DC-12 ne prouve pas encore

```text
STG-like image digest-pinned runtime
Ansible complet contre une cible de déploiement dédiée
DOCKER-USER runtime sur cible isolée
anti-SQLite runtime STG/PROD
strict idempotence
reboot/recovery
TLS/HTTPS
package + SHA-256
```

## Verdict

```text
DC12_DEV_FULL_E2E_PASS
```

**DC-12 est GREEN.**

## Prochain jalon

```text
DC-13 — STG-like E2E + anti-SQLite Runtime Qualification
```
