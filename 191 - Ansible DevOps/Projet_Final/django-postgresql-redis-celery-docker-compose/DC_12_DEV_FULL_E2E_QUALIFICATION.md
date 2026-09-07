# DC-12 — DEV Full E2E Qualification

## Statut

```text
IMPLEMENTATION                  ✅
APPLICATION IMAGE BUILD         ✅ IMPLEMENTED
POSTGRESQL REAL                 ✅ IMPLEMENTED
REDIS REAL                      ✅ IMPLEMENTED
SIX SERVICES HEALTH             ✅ IMPLEMENTED
HTTP VIA NGINX                  ✅ IMPLEMENTED
CELERY add(21,21)=42            ✅ IMPLEMENTED
CELERY uppercase                ✅ IMPLEMENTED
CELERY database_probe SELECT 1  ✅ IMPLEMENTED
BEAT PERIODIC EXECUTION         ✅ IMPLEMENTED
HOST PORT ISOLATION             ✅ IMPLEMENTED
CI GREEN                        ⏳
```

DC-12 est le premier jalon de la variante Docker Compose qui exige des preuves runtime réelles. Le gate ne se contente plus de `docker compose config` : il construit l'image, démarre réellement PostgreSQL, Redis, Django/Gunicorn, Celery Worker, Celery Beat et Nginx, puis exerce le système de bout en bout.

Aucun statut GREEN n'est revendiqué tant que le workflow GitHub Actions dédié n'a pas été observé avec succès.

## Workflow

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-dev-e2e.yml
```

Le workflow s'exécute sur Ubuntu 24.04 avec Docker Engine / Docker Compose v2 du runner GitHub Actions.

## Harness

```text
ansible-project/tests/e2e/
├── run_dev_full_e2e.sh
└── validate_dev_full_e2e.py
```

Le script principal crée un environnement DEV Full éphémère avec secrets aléatoires non persistés, un project name Compose unique et un nettoyage automatique `docker compose down --volumes`.

Les logs de diagnostic sont redacted avant affichage. Le fichier d'environnement temporaire n'est jamais imprimé.

## Build once

L'image applicative est construite explicitement une seule fois :

```text
docker compose ... build web
```

La suite démarre `web`, `worker` et `beat` avec `--no-build`, puis vérifie que les trois conteneurs utilisent exactement le même image ID.

## Phase données réelle

Le gate démarre d'abord :

```text
db
redis
```

puis attend leurs healthchecks.

PostgreSQL est vérifié avec un vrai :

```sql
SELECT 1;
```

Redis est vérifié avec un `PING` authentifié via `REDISCLI_AUTH` ; aucun mot de passe n'est passé avec `redis-cli -a`.

## Release phase

Avant de démarrer les process applicatifs permanents, le gate exécute trois opérations one-shot avec l'image construite :

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py ensure_demo_periodic_task --seconds 5
```

Cela préserve le contrat :

```text
BUILD   → image immutable
RELEASE → migrations + static + schedule
RUN     → web / worker / beat
```

## Six services

La cible runtime est exactement :

```text
nginx
web
db
redis
worker
beat
```

DC-12 attend le statut `healthy` des six services, puis reprend une seconde photographie de santé en fin de qualification.

## HTTP réel via Nginx

Le validateur appelle depuis l'hôte :

```text
GET /health/
GET /health/database/
GET /health/redis/
GET /health/celery/
GET /api/info/
```

Les réponses doivent confirmer :

```text
Django healthy
PostgreSQL connected + query=1
Redis connected
au moins un Celery Worker joignable
runtime=gunicorn
database=postgresql
broker=redis
async_runtime=celery
scheduler=django-celery-beat
```

## Round-trips Celery réels

Le gate soumet réellement les trois tâches via Nginx/DRF, récupère leurs `task_id`, poll le result backend Redis et exige :

```text
add(21,21)              → 42
uppercase(datascientest) → DATASCIENTEST
database_probe()         → {database: connected, query: 1}
```

`database_probe()` constitue une preuve end-to-end :

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
Celery result backend Redis
  ↓ poll HTTP
host
```

## Preuve Celery Beat

Le schedule `datascientest-demo-heartbeat` utilise un intervalle de 5 secondes pour la qualification.

Le gate exige simultanément :

```text
PeriodicTask.total_run_count >= 1
ET
worker logs contenant tasks_demo.periodic_heartbeat ... succeeded
```

Ainsi, la simple présence du process Beat ou de la ligne en base ne suffit pas : il faut une émission périodique et une consommation réussie par le Worker.

## Isolation des ports depuis l'hôte

Le seul port DEV publié est :

```text
127.0.0.1:8080 → nginx:80
```

Le validateur exige depuis l'hôte :

```text
127.0.0.1:8080 reachable=true
127.0.0.1:8000 reachable=false
127.0.0.1:5432 reachable=false
127.0.0.1:6379 reachable=false
```

Il vérifie également avec `docker compose port` que `web:8000`, `db:5432` et `redis:6379` n'ont aucune publication Docker.

Le workflow arrête préalablement d'éventuels services PostgreSQL/Redis/Nginx du runner afin qu'un service système préinstallé ne crée pas de faux positif sur les ports réservés.

## Ce que DC-12 ne prouve pas encore

```text
STG-like image digest-pinned runtime
Ansible complet contre une cible Docker dédiée
DOCKER-USER runtime sur cible isolée
anti-SQLite runtime STG/PROD
strict idempotence
reboot/recovery
TLS/HTTPS
package + SHA-256
```

Ces preuves sont réservées aux jalons suivants.

## Prochain jalon après GREEN

```text
DC-13 — STG-like E2E + anti-SQLite Runtime Qualification
```
