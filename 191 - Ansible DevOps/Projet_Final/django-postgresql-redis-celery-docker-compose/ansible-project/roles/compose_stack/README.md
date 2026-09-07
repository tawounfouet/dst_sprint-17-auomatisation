# Role `compose_stack`

Ce rôle déploie la stack Docker Compose multi-environnement après préparation de l'hôte par `docker_engine`.

Contrat actif :

```text
common → docker_engine → compose_stack
```

Le rôle copie les fichiers `docker/` vers `/opt/datascientest-compose/docker`, sélectionne exactement un overlay `dev`, `stg` ou `prod`, rend un fichier `.env.runtime` protégé en `0600`, valide le merge via `docker compose config --quiet`, puis converge la stack avec `community.docker.docker_compose_v2`.

## DEV Full

En `dev`, le rôle copie aussi `django-app/` comme build context et autorise une image taggée locale. SQLite n'est pas un mode Compose : `DATABASE_URL` reste obligatoire.

## STG / PROD

`APP_IMAGE` doit respecter :

```text
registry/path/image@sha256:<64 hexadecimal characters>
```

Aucun build applicatif n'est lancé sur le serveur de staging ou de production. L'overlay consomme l'artefact immuable déjà construit.

## Secrets

Le rôle attend `compose_stack_runtime_environment` mais n'embarque aucun secret par défaut. Les secrets sont fournis par l'inventory/Vault et le rendu du fichier runtime utilise `no_log: true`.

Le durcissement complet de la génération et de la rotation des secrets appartient à DC-09.

## Idempotence

Le module Compose est utilisé avec `state: present`, `recreate: auto` implicite et `remove_orphans`. Le second passage `changed=0` sera qualifié dans DC-14.

## Rôles natifs historiques

Les rôles `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx` restent présents comme référence de migration mais ne sont plus appelés par `site.yml`.
