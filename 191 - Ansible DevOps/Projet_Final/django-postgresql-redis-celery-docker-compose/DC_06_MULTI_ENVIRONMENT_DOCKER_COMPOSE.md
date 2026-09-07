# DC-06 — Multi-Environment Docker Compose

## Statut

```text
IMPLEMENTATION         ✅
COMPOSE CONFIG GREEN   ⏳
RUNTIME QUALIFIED      ⏳
CI GREEN               ⏳
```

Ce jalon introduit les overlays Docker Compose dédiés à `dev`, `stg` et `prod`. Il formalise les politiques de build, d'image, de debug et de publication réseau sans encore revendiquer de validation runtime.

## Livrables

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
└── compose.prod.yml
```

Le `compose.yml` de base reste la topologie commune et devient volontairement neutre vis-à-vis de l'environnement : il ne porte plus de build applicatif et ne publie plus de port hôte.

## Modèle de composition

```text
compose.yml
    │
    ├── + compose.dev.yml   → DEV Full
    ├── + compose.stg.yml   → STG
    └── + compose.prod.yml  → PROD
```

La topologie reste identique :

```text
nginx
  ↓
web
 ├── db
 └── redis
      ↑
 worker / beat
```

## DEV Full

Le DEV Full utilise explicitement :

```text
APPLICATION_ENV=dev
DJANGO_SETTINGS_MODULE=config.settings.dev
```

Il construit localement la même image applicative pour :

```text
web
worker
beat
```

avec un même `Dockerfile` et une même valeur `APP_IMAGE`.

Le fichier de base exige déjà `DATABASE_URL`. Comme `config.settings.dev` rejette une URL SQLite explicite, le DEV Full Compose ne peut fonctionner qu'avec PostgreSQL.

Le fallback SQLite reste donc uniquement :

```text
DEV Lite hors Compose
+ DATABASE_URL absente
→ SQLite
```

et jamais :

```text
DEV Full Compose
→ SQLite
```

Le port HTTP de développement est publié par défaut uniquement sur :

```text
127.0.0.1:8080
```

Aucun port applicatif interne n'est publié :

```text
8000 Gunicorn   → non publié
5432 PostgreSQL → non publié
6379 Redis      → non publié
```

Aucun bind mount du code n'est activé par défaut. Cette décision maintient un DEV Full plus proche de STG/PROD ; le DEV Lite reste le mode de développement rapide.

## STG

L'overlay STG force :

```text
APPLICATION_ENV=stg
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_DEBUG=false
```

`APP_IMAGE` devient obligatoire.

Aucun `build:` applicatif n'est présent en STG. Le déploiement consomme donc une image déjà construite par la chaîne de build/release.

Les settings Django imposent en complément :

```text
DATABASE_URL obligatoire
PostgreSQL obligatoire
SQLite interdit
DJANGO_DEBUG=true interdit
```

Il n'existe aucun bind mount du code source en STG.

## PROD

L'overlay PROD force :

```text
APPLICATION_ENV=prod
DJANGO_SETTINGS_MODULE=config.settings.prod
DJANGO_DEBUG=false
```

Comme en STG :

```text
APP_IMAGE obligatoire
aucun build depuis le serveur de déploiement
aucun bind mount du code
PostgreSQL obligatoire
SQLite interdit
```

Les protections supplémentaires définies dans `config.settings.prod` restent actives, notamment HSTS et cookies sécurisés.

## Promotion STG → PROD

Le contrat d'artefact devient :

```text
Git commit
   ↓
CI BUILD
   ↓
image immutable
registry/...@sha256:ABC
   ↓
STG
qualifie sha256:ABC
   ↓
PROD
réutilise sha256:ABC
```

STG et PROD ne doivent jamais reconstruire l'application à partir du code local.

La variable de release reste :

```text
APP_IMAGE
```

La valeur recommandée est une référence par digest :

```text
registry.example.com/datascientest-django@sha256:<digest>
```

Compose exige que `APP_IMAGE` soit fournie dans STG/PROD. La vérification stricte du format `@sha256:` sera ajoutée côté Ansible/static gate afin de ne pas dépendre d'une convention humaine.

## Image unique pour web / worker / beat

Dans chaque environnement :

```text
                   APP_IMAGE
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
           web       worker      beat
```

Les trois process types doivent donc exécuter le même code et les mêmes dépendances. Seule leur commande runtime change.

## Politique de debug

```text
DEV Full → DJANGO_DEBUG configurable, true par défaut
STG      → false imposé
PROD     → false imposé
```

Django contient en plus une barrière de démarrage qui refuse `DJANGO_DEBUG=true` en staging ou production.

## Politique réseau

Le fichier de base ne publie plus aucun port.

Chaque overlay publie seulement Nginx :

```text
DEV Full → 127.0.0.1:${NGINX_HTTP_PORT:-8080}:80
STG      → ${NGINX_HTTP_BIND_ADDRESS:-0.0.0.0}:${NGINX_HTTP_PORT:-80}:80
PROD     → ${NGINX_HTTP_BIND_ADDRESS:-0.0.0.0}:${NGINX_HTTP_PORT:-80}:80
```

Les ports suivants restent seulement internes au réseau Compose dans les trois environnements :

```text
8000
5432
6379
```

## Parité DEV/STG/PROD

La hiérarchie retenue est :

```text
DEV Lite
  → confort local
  → SQLite possible

DEV Full
  → stack Compose complète
  → PostgreSQL
  → image construite localement

STG
  → topologie prod-like
  → image immutable préconstruite
  → PostgreSQL strict

PROD
  → même topologie STG
  → même digest que STG
  → politiques de sécurité production
```

Cette séparation protège le principe de dev/prod parity sans sacrifier le mode local léger.

## 12-Factor renforcé

DC-06 renforce particulièrement :

```text
III  Config             → environnement explicite
V    Build/Release/Run  → STG/PROD ne buildent pas
X    Dev/Prod parity    → même topologie, DEV Full proche PROD
```

La promotion par digest est préparée mais ne sera réellement prouvée qu'avec la CI et les rôles Ansible.

## Limites actuelles

Ce jalon ne prouve pas encore :

```text
docker compose config pour les trois overlays
build DEV Full réussi
pull STG/PROD réussi
absence de ports internes observée au runtime
même digest effectivement déployé entre STG et PROD
anti-SQLite exécuté en CI
```

Aucun statut GREEN n'est donc revendiqué à ce stade.

## Prochain jalon

```text
DC-07 — Ansible docker_engine
```

Il installera et qualifiera Docker Engine ainsi que Docker Compose v2 sur l'hôte cible, avant que DC-08 ne déploie réellement cette stack multi-environnement via Ansible.
