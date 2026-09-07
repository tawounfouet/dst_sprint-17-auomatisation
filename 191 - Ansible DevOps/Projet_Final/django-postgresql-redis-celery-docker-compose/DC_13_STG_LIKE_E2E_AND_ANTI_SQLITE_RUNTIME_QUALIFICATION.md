# DC-13 — STG-like E2E + anti-SQLite Runtime Qualification

## Statut

```text
IMPLEMENTATION                         ✅
IMMUTABLE IMAGE PREPARATION            ✅ IMPLEMENTED
ZERO COMPOSE BUILD IN STG              ✅ IMPLEMENTED
APPLICATION_ENV=stg                    ✅ IMPLEMENTED
config.settings.stg                    ✅ IMPLEMENTED
DEBUG=false                            ✅ IMPLEMENTED
POSTGRESQL REQUIRED                    ✅ IMPLEMENTED
MISSING DATABASE_URL REJECTION         ✅ IMPLEMENTED
SQLITE DATABASE_URL REJECTION          ✅ IMPLEMENTED
INVALID DATABASE_URL REJECTION         ✅ IMPLEMENTED
DJANGO_DEBUG=true REJECTION            ✅ IMPLEMENTED
SIX REAL SERVICES                      ✅ IMPLEMENTED
CELERY ROUND-TRIPS                     ✅ IMPLEMENTED
BEAT PERIODIC PROOF                    ✅ IMPLEMENTED
HOST PORT ISOLATION                    ✅ IMPLEMENTED
CI GREEN                               ⏳
```

DC-13 élève la qualification Docker Compose au niveau **STG-like**. Contrairement à DC-12, la phase de déploiement ne possède aucun `build:` Compose et ne peut ni reconstruire ni tirer implicitement l'image applicative.

Aucun statut GREEN n'est revendiqué avant observation d'un run GitHub Actions réussi.

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

Le registry de promotion n'appartient pas à la stack applicative et est supprimé avant le déploiement STG-like.

Le harness vérifie ensuite que la référence digest-pinned reste résoluble localement. Le déploiement utilise exclusivement :

```text
--no-build
--pull never
```

pour les `docker compose up` et les opérations one-shot de release.

Le Compose rendu doit avoir exactement six services et aucune clé `build` pour `web`, `worker` ou `beat`. Ces trois services doivent utiliser exactement la même référence `APP_IMAGE@sha256`.

## Politique runtime STG

Le runtime attendu est :

```text
APPLICATION_ENV=stg
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_DEBUG=false
DATABASES.default.ENGINE=django.db.backends.postgresql
```

Le harness exécute un snapshot positif depuis l'image immutable et exige ces quatre valeurs.

## Tests négatifs anti-SQLite

DC-13 exécute directement l'image immutable avec `config.settings.stg` et exige un échec pour :

```text
DATABASE_URL absente
DATABASE_URL=sqlite:///...
DATABASE_URL avec schéma non PostgreSQL
DJANGO_DEBUG=true
```

Les tests s'exécutent avec `--network none` afin de démontrer des refus de politique de configuration et non des erreurs de connectivité.

Les sorties d'erreur sont capturées dans des fichiers temporaires et ne sont pas imprimées. Le gate ne valide que la présence du motif d'erreur attendu.

## PostgreSQL et Redis réels

Après les tests négatifs, la stack démarre réellement `db` et `redis`, attend leurs healthchecks puis exige :

```text
PostgreSQL → SELECT 1
Redis      → PING authentifié
```

Redis utilise `REDISCLI_AUTH` ; aucun `redis-cli -a` n'est utilisé.

## Release phase

La même image digest-pinned exécute :

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py ensure_demo_periodic_task --seconds 5
```

Aucun rebuild et aucun pull ne sont autorisés pendant cette phase.

## Six services STG-like

La cible reste :

```text
nginx
web
db
redis
worker
beat
```

Le gate attend `healthy` pour les six services puis vérifie que `web`, `worker` et `beat` utilisent :

```text
même image ID
ET
exactement la référence digest-pinned préparée avant le déploiement
```

## Round-trips fonctionnels

Comme DC-12, DC-13 doit préserver le contrat fonctionnel :

```text
add(21,21)               → 42
uppercase(datascientest) → DATASCIENTEST
database_probe()         → {database: connected, query: 1}
```

Les appels passent par Nginx, Django/DRF, Redis broker, Celery Worker et le result backend Redis. `database_probe()` exécute un vrai `SELECT 1` PostgreSQL depuis le Worker.

## Preuve Beat

Le gate exige simultanément :

```text
PeriodicTask.total_run_count >= 1
ET
worker logs contenant tasks_demo.periodic_heartbeat ... succeeded
```

La présence du process Beat ou d'une ligne `PeriodicTask` ne suffit donc pas.

## Contrat réseau STG-like

Pour éviter un conflit de port sur le runner, le port public de qualification est :

```text
0.0.0.0:8081 → nginx:80
```

Les ports internes restent non publiés :

```text
8000 Gunicorn   → host unreachable + HostConfig.PortBindings vide
5432 PostgreSQL → host unreachable + HostConfig.PortBindings vide
6379 Redis      → host unreachable + HostConfig.PortBindings vide
```

La qualification ne prétend pas encore prouver la politique `DOCKER-USER` sur une machine de staging réelle ; cette frontière reste explicitement séparée de l'absence de publication Docker.

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

## Workflow

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

## Critère GREEN

DC-13 sera déclaré GREEN uniquement après observation d'un workflow réussi terminant par :

```text
DC13_STG_LIKE_E2E_PASS
```

et après enregistrement du run ID, job ID, commit SHA, versions runtime et preuves observées.

## Prochain jalon après GREEN

```text
DC-14 — Strict Idempotence
```
