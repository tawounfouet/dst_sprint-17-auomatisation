# Docker Compose — Base Stack

Le fichier `compose.yml` décrit la topologie commune aux futurs environnements DEV Full, STG et PROD.

Il ne contient aucun secret réel. Les variables sensibles (`DJANGO_SECRET_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `DATABASE_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`) doivent être injectées par l'environnement d'exécution ; la génération Ansible/Vault sera ajoutée dans les jalons suivants.

Services :

```text
nginx → web → db
          └→ redis ← worker / beat
```

Seul Nginx publie un port hôte. `web:8000`, `db:5432` et `redis:6379` restent uniquement sur le réseau Compose.

`web`, `worker` et `beat` utilisent la même image `APP_IMAGE` et le même `Dockerfile`. Leurs commandes diffèrent uniquement au runtime.

Les overlays `compose.dev.yml`, `compose.stg.yml` et `compose.prod.yml` seront introduits dans DC-06.
