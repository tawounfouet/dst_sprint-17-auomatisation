# Docker Compose — Multi-Environment Stack

Le dossier `docker/` porte désormais un fichier de base commun et trois overlays explicites :

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
├── compose.prod.yml
├── nginx/
│   └── default.conf
└── redis/
    └── entrypoint.sh
```

## Principe

`compose.yml` contient la topologie commune : `nginx`, `web`, `db`, `redis`, `worker`, `beat`, volumes, réseau privé, healthchecks et dépendances.

Il ne publie désormais **aucun port hôte** et ne contient plus de `build:` applicatif. La politique de build, d'image et de publication est portée par l'overlay sélectionné.

## DEV Full

```bash
docker compose \
  -f compose.yml \
  -f compose.dev.yml \
  up --build -d
```

Contrat :

```text
APPLICATION_ENV=dev
DJANGO_SETTINGS_MODULE=config.settings.dev
DATABASE_URL obligatoire → PostgreSQL
SQLite interdit dans ce mode
image applicative construite localement
Nginx publié uniquement sur 127.0.0.1:8080 par défaut
aucun port 8000/5432/6379 publié
```

Le fallback SQLite reste réservé au **DEV Lite hors stack Compose**, lorsque `DATABASE_URL` est volontairement absente.

## STG

```bash
docker compose \
  -f compose.yml \
  -f compose.stg.yml \
  up -d
```

Contrat :

```text
APPLICATION_ENV=stg
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_DEBUG=false
DATABASE_URL obligatoire et PostgreSQL-only via les settings Django
APP_IMAGE obligatoire
aucun build applicatif depuis les sources
aucun bind mount du code
aucun port 8000/5432/6379 publié
```

`APP_IMAGE` doit être fourni sous forme de référence immuable, idéalement :

```text
registry.example.com/datascientest-django@sha256:<digest>
```

## PROD

```bash
docker compose \
  -f compose.yml \
  -f compose.prod.yml \
  up -d
```

Le contrat PROD est le même que STG pour l'artefact applicatif, avec :

```text
APPLICATION_ENV=prod
DJANGO_SETTINGS_MODULE=config.settings.prod
DJANGO_DEBUG=false
```

Le déploiement PROD doit réutiliser **exactement le même `APP_IMAGE` / digest que celui qualifié en STG**.

## Promotion d'image

La cible de release est :

```text
CI build
   ↓
APP_IMAGE=registry/...@sha256:ABC
   ↓
STG qualifie sha256:ABC
   ↓
PROD déploie sha256:ABC
```

STG et PROD ne doivent pas rebuild l'application. Les futurs rôles Ansible vérifieront que la référence fournie respecte le contrat de promotion.

## Réseau

Le service discovery reste interne à Compose :

```text
nginx  → web:8000
web    → db:5432
web    → redis:6379
worker → db:5432
worker → redis:6379
beat   → db:5432
beat   → redis:6379
```

Publication hôte :

```text
DEV Full : nginx → 127.0.0.1:8080 par défaut
STG/PROD: nginx → :80 par défaut

8000 → jamais publié
5432 → jamais publié
6379 → jamais publié
```

## Secrets

Aucun secret réel n'est versionné. `DJANGO_SECRET_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `DATABASE_URL`, `CELERY_BROKER_URL` et `CELERY_RESULT_BACKEND` sont injectés par l'environnement d'exécution ; Ansible/Vault prendra cette responsabilité dans les jalons suivants.

## Statut

Les fichiers sont implémentés, mais aucun `docker compose config` ou runtime GREEN n'est revendiqué avant les gates prévus plus loin dans la roadmap.
