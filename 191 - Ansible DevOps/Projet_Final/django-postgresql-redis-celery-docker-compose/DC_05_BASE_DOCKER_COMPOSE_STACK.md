# DC-05 — Base Docker Compose Stack

## Statut

```text
IMPLEMENTATION       ✅
COMPOSE CONFIG GREEN ⏳
RUNTIME QUALIFIED    ⏳
CI GREEN             ⏳
```

Ce jalon introduit la première topologie Docker Compose complète de la variante. Il ne revendique pas encore de succès runtime : les builds, `docker compose config`, healthchecks observés et preuves E2E seront qualifiés dans les jalons ultérieurs.

## Services livrés

```text
nginx
web
db
redis
worker
beat
```

Architecture :

```text
Client
  │
  ▼
nginx :80
  │
  ▼
web — Django/DRF + Gunicorn :8000
  ├──────────────► db — PostgreSQL :5432
  └──────────────► redis — Redis :6379
                         ▲
                    ┌────┴────┐
                    │         │
                  worker     beat
                  Celery   Celery Beat
```

## Une seule image applicative

`web`, `worker` et `beat` partagent le même bloc Compose et la même référence `APP_IMAGE`.

```text
APP_IMAGE
   │
   ├── web
   ├── worker
   └── beat
```

Le build pointe vers `../django-app/Dockerfile` et transmet :

```text
APPLICATION_VERSION
APPLICATION_COMMIT
```

Les commandes de process diffèrent seulement au runtime : Gunicorn pour `web`, Celery Worker pour `worker`, Celery Beat pour `beat`.

## PostgreSQL persistant

Le service `db` utilise :

```text
postgres:16-alpine
```

avec un volume nommé :

```text
postgres_data:/var/lib/postgresql/data
```

et un healthcheck `pg_isready`.

Aucun port `5432` n'est publié sur l'hôte. `expose: 5432` documente uniquement le contrat inter-conteneurs.

## Redis authentifié

Le service `redis` utilise :

```text
redis:7.4-alpine
```

avec :

```text
REDIS_PASSWORD obligatoire
ACL temporaire générée au démarrage
protected-mode yes
AOF activé
redis_data:/data
```

Le mot de passe n'est pas inscrit dans `compose.yml`. Le script d'entrypoint écrit un fichier ACL temporaire avec `umask 077` puis lance Redis.

Le healthcheck utilise `REDISCLI_AUTH` et attend `PONG`, sans utiliser `redis-cli -a`.

Le contrat actuel refuse les mots de passe Redis contenant des espaces. Le futur jalon DC-09 définira le format canonique des secrets générés/injectés par Ansible.

## Réseau

La stack utilise un réseau bridge Compose privé :

```text
app
```

Service discovery :

```text
nginx  → web:8000
web    → db:5432
web    → redis:6379
worker → db:5432
worker → redis:6379
beat   → db:5432
beat   → redis:6379
```

Contrat hôte attendu :

```text
80    published=true
8000  published=false
5432  published=false
6379  published=false
```

Seul `nginx` possède une section `ports:`.

## Dépendances et healthchecks

Ordre logique :

```text
db healthy ─┐
             ├──► web healthy ─► nginx
redis healthy┘

 db healthy ─┐
              ├──► worker
redis healthy ┘

 db healthy ─┐
              ├──► beat
redis healthy ┘
```

Healthchecks implémentés :

```text
db     → pg_isready
redis  → PING authentifié
web    → GET /health/ via urllib Python
worker → celery inspect ping
beat   → vérification du process Celery Beat PID 1
nginx  → GET /health/ via proxy
```

Le healthcheck Beat ne constitue pas une preuve fonctionnelle de scheduling. La preuve forte restera : PeriodicTask présente + compteur/exécution réelle observée dans la qualification E2E.

## Nginx

Le reverse proxy est défini dans :

```text
docker/nginx/default.conf
```

Il :

```text
proxy_pass → web:8000
transmet Host / X-Real-IP / X-Forwarded-For / X-Forwarded-Proto
sert /static/ depuis static_data
n'écrit pas de secret
```

## Volumes

```text
postgres_data  → données PostgreSQL
redis_data     → AOF Redis
static_data    → staticfiles partagés entre web et nginx
```

Les migrations et `collectstatic` ne sont pas exécutés automatiquement au boot. `static_data` est seulement préparé pour les futurs admin one-shot processes.

## Variables runtime requises

Le Compose base attend notamment :

```text
DJANGO_SECRET_KEY
DATABASE_URL
CELERY_BROKER_URL
CELERY_RESULT_BACKEND
POSTGRES_PASSWORD
REDIS_PASSWORD
```

Il accepte aussi :

```text
APPLICATION_ENV
DJANGO_SETTINGS_MODULE
APPLICATION_VERSION
APPLICATION_COMMIT
APP_IMAGE
```

`DATABASE_URL` et les URLs Celery sont fournies directement plutôt que reconstruites dans Compose afin que l'encodage des mots de passe reste la responsabilité du futur mécanisme de configuration Ansible/DC-09.

## Disposability

`web`, `worker` et `beat` utilisent :

```text
stop_grace_period: 30s
```

et héritent du `STOPSIGNAL SIGTERM`/`exec` définis dans DC-04.

## Limites actuelles

Ce jalon ne prouve pas encore :

```text
docker compose config réussi
images téléchargées/buildées
services réellement healthy
connectivité inter-conteneurs
network publication observée
Redis ACL réellement opérationnelle
même image digest observé pour web/worker/beat
migration/collectstatic one-shot
```

Aucun statut GREEN n'est donc revendiqué avant qualification.

## Prochain jalon

```text
DC-06 — Multi-environment Docker Compose
```

Il introduira les overlays `dev`, `stg` et `prod`, les différences DEV Lite/DEV Full, l'interdiction SQLite hors DEV, les politiques de publication de ports et la préparation de la promotion d'une même image entre STG et PROD.
