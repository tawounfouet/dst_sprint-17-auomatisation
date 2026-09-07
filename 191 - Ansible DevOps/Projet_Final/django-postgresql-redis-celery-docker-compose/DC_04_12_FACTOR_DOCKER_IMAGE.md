# DC-04 — 12-Factor Docker Image

## Statut

```text
IMPLEMENTATION      ✅
IMAGE BUILD GREEN   ⏳
RUNTIME QUALIFIED   ⏳
CI GREEN            ⏳
```

Ce jalon introduit l'image applicative commune de la variante Docker Compose. Il ne constitue pas encore une qualification runtime : le build réel, les conteneurs et les preuves E2E arriveront avec les jalons Compose/CI.

## Livrables

```text
django-app/
├── Dockerfile
├── .dockerignore
└── docker/
    ├── entrypoint.sh
    └── gunicorn.conf.py
```

## Image commune

Une seule image applicative doit servir aux trois process types :

```text
                   django-app image
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
             web        worker       beat
          Gunicorn      Celery      Celery Beat
```

Compose remplacera uniquement la commande de démarrage pour `worker` et `beat`. Aucune image Python distincte ne doit être maintenue pour ces process.

## Dockerfile multi-stage

Le `Dockerfile` comporte deux étapes :

```text
builder
  └── installe les dépendances Python dans /install

runtime
  ├── copie uniquement les dépendances construites
  ├── copie le code applicatif
  ├── crée l'utilisateur app UID/GID 10001
  └── exécute le runtime sans privilège root
```

Les dépendances sont donc installées au **build**. Aucun `pip install` n'est prévu au démarrage du conteneur.

L'image de base par défaut est :

```text
python:3.12-slim-bookworm
```

Le Dockerfile accepte cependant `PYTHON_IMAGE` comme build argument afin qu'une qualification ultérieure puisse imposer une référence plus stricte, y compris un digest.

## Utilisateur non-root

Le runtime crée :

```text
user  : app
uid   : 10001
group : app
gid   : 10001
```

et termine par :

```dockerfile
USER app
```

Le code et `staticfiles/` sont préparés avec des permissions compatibles avec cet utilisateur.

## Configuration explicite en conteneur

L'entrypoint refuse de démarrer si les variables suivantes ne sont pas fournies explicitement :

```text
DJANGO_SETTINGS_MODULE
APPLICATION_ENV
```

Les valeurs autorisées sont :

```text
APPLICATION_ENV=dev → DJANGO_SETTINGS_MODULE=config.settings.dev
APPLICATION_ENV=stg → DJANGO_SETTINGS_MODULE=config.settings.stg
APPLICATION_ENV=prod → DJANGO_SETTINGS_MODULE=config.settings.prod
```

Cette barrière évite qu'un conteneur de staging/production puisse démarrer par erreur sur le défaut de développement et donc sur le fallback SQLite DEV-only.

Le mode DEV Lite hors conteneur conserve la commodité de `manage.py` avec `config.settings.dev` par défaut.

## Metadata immutable

Le build accepte :

```text
APPLICATION_VERSION
APPLICATION_COMMIT
```

Ces valeurs sont inscrites dans :

```text
ENV APPLICATION_VERSION
ENV APPLICATION_COMMIT
OCI label org.opencontainers.image.version
OCI label org.opencontainers.image.revision
```

Elles décrivent l'artefact construit. `APPLICATION_ENV` reste exclusivement runtime et n'est pas baked dans l'image.

Cible future : une même image/digest promue entre STG et PROD, avec seule la configuration runtime qui change.

## Gunicorn / port binding

La commande par défaut est :

```text
gunicorn config.wsgi:application --config docker/gunicorn.conf.py
```

Le binding par défaut est :

```text
0.0.0.0:8000
```

Il s'agit d'un port interne au réseau Compose. Le jalon Compose interdira sa publication sur l'hôte.

La configuration accepte notamment :

```text
GUNICORN_BIND
WEB_CONCURRENCY
GUNICORN_TIMEOUT
GUNICORN_GRACEFUL_TIMEOUT
GUNICORN_KEEPALIVE
```

## Logs

Gunicorn écrit :

```text
access log → stdout
error log  → stderr
```

Django avait déjà été configuré pour utiliser un `StreamHandler`. Aucun fichier de log applicatif permanent n'est créé dans le conteneur.

Cela prépare le facteur XI des 12-Factor Apps : logs traités comme flux d'événements.

## Arrêt propre

Le Dockerfile déclare :

```dockerfile
STOPSIGNAL SIGTERM
```

L'entrypoint termine avec :

```sh
exec "$@"
```

Le process applicatif devient donc PID 1 et reçoit directement les signaux Docker. Gunicorn utilise son `graceful_timeout`; les commandes Celery de Compose bénéficieront du même forwarding de signal.

Les `stop_grace_period` Compose seront fixés dans un jalon ultérieur.

## `.dockerignore`

Le contexte de build exclut notamment :

```text
.git
caches Python
venv locaux
.env et .env.*
SQLite local
staticfiles/media locaux
logs/pid
```

Aucun secret réel ne doit pouvoir entrer dans l'image via le contexte Docker.

## Build / Release / Run

Le contrat devient :

```text
Git commit
    ↓
BUILD
    ├── dependencies installées
    ├── code copié
    ├── version/revision inscrites
    └── image produite
    ↓
RELEASE
    image digest + configuration environnement
    ↓
RUN
    web / worker / beat
```

Les migrations et `collectstatic` ne sont pas exécutés par le Dockerfile ni automatiquement par l'entrypoint. Ils resteront des **admin/release one-off processes**, conformément au facteur XII.

## Points 12-Factor couverts par DC-04

```text
II   Dependencies      → explicites et installées au build
V    Build/Release/Run → image construite séparément du runtime
VI   Processes         → image commune, process types distincts
VII  Port binding      → Gunicorn 0.0.0.0:8000 interne
IX   Disposability     → SIGTERM + exec + graceful timeout
XI   Logs              → stdout/stderr
XII  Admin processes   → aucun migrate/collectstatic automatique au boot
```

Les facteurs nécessitant Compose, Ansible ou la CI seront qualifiés plus tard.

## Limites actuelles

Ce jalon ne prouve pas encore :

```text
docker build réussi
exécution en utilisateur non-root observée
même image utilisée par web/worker/beat
healthcheck runtime
publication réseau
promotion réelle par digest
reproductibilité exacte des versions Python transitoires
```

Les dépendances sont bornées dans `requirements.txt`, mais un lock exact et/ou une qualification par digest pourra être ajouté si l'on veut une reproductibilité bit-à-bit plus stricte.

## Prochain jalon

```text
DC-05 — Base Docker Compose Stack
```

Il branchera `nginx`, `web`, `db`, `redis`, `worker` et `beat` autour de cette image commune avec réseaux privés, volumes, dépendances et premières healthchecks.
