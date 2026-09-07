# Role `compose_stack`

Ce rôle déploie la stack Docker Compose multi-environnement après préparation de l'hôte par `docker_engine`.

Contrat actif :

```text
common → docker_engine → compose_stack
```

Le rôle copie `docker/` vers `/opt/datascientest-compose/docker`, sélectionne exactement un overlay `dev`, `stg` ou `prod`, valide le contrat de secrets, rend `.env.runtime`, valide le merge Compose et converge la stack.

## Contrat de secrets DC-09

Le rôle exige notamment :

```text
DJANGO_SECRET_KEY   >= 50 caractères
POSTGRES_PASSWORD   >= 24 caractères
REDIS_PASSWORD      >= 24 caractères
3 valeurs distinctes
aucun marqueur placeholder
```

Les URLs dérivées doivent cibler exclusivement les services Compose :

```text
DATABASE_URL          → postgresql://...@db:5432/...
CELERY_BROKER_URL     → redis://...@redis:6379/...
CELERY_RESULT_BACKEND → redis://...@redis:6379/...
```

SQLite est explicitement refusé dans la configuration Compose.

## Fichier runtime

Le seul fichier de secrets runtime attendu est :

```text
/opt/datascientest-compose/docker/.env.runtime
```

Il est rendu :

```text
owner=root
group=root
mode=0600
backup=false
```

Le rôle contrôle ensuite ces métadonnées avec `stat`. Les anciens `.env`, `.env.dev`, `.env.stg` et `.env.prod` distants sont supprimés afin d'éviter des copies plaintext concurrentes.

Toutes les tâches susceptibles de manipuler ou développer les variables sensibles utilisent `no_log: true`.

## DEV Full

En `dev`, le rôle copie aussi `django-app/` comme build context et autorise une image locale. SQLite reste un mode DEV Lite hors Compose uniquement.

## STG / PROD

`APP_IMAGE` doit respecter :

```text
registry/path/image@sha256:<64 hexadecimal characters>
```

Aucun build applicatif n'est lancé sur le serveur de staging ou de production.

## Limite de sécurité importante

`.env.runtime` est protégé contre les utilisateurs non privilégiés, mais les variables injectées sont visibles par les utilisateurs ayant accès root ou au socket/API Docker. L'accès Docker doit donc être considéré comme un accès privilégié aux secrets de la stack.

## Idempotence

Le module Compose reste déclaratif avec `state: present`. Les commandes one-shot utilisent des règles `changed_when`; le vrai gate `changed=0` sera qualifié dans DC-14.
