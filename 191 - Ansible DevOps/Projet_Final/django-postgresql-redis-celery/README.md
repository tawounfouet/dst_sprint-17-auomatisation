# Projet Ansible — Django + PostgreSQL + Redis + Celery

Variante dérivée du projet `django-postgresql/` afin d'ajouter Redis et Celery sur une topologie mono-serveur Ubuntu 24.04.

## Statut

```text
BASELINE COPIED          ✅
REDIS IMPLEMENTATION     ⏳
CELERY IMPLEMENTATION    ⏳
ASYNC TASK API           ⏳
E2E QUALIFICATION        ⏳
IDEMPOTENCE              ⏳
PACKAGE / ARTIFACT       ⏳
```

> Important : la qualification GREEN du projet source n'est pas héritée. Cette variante devra produire sa propre qualification E2E avant d'être considérée qualifiée.

## Baseline source

```text
Source dossier : 191 - Ansible DevOps/Projet_Final/django-postgresql/
Source snapshot : 22feae813b4e85df891304b596cfb07b8940081b
Branche         : feat/ansible-django-postgresql-project
```

Le projet source a été qualifié en mono-host sur Ubuntu 24.04 avec Nginx, Gunicorn, Django et PostgreSQL. Cette preuve sert uniquement de référence de conception.

## Architecture cible

```text
Nginx :80
   ↓
Gunicorn 127.0.0.1:8000
   ↓
Django
   ├── PostgreSQL 127.0.0.1:5432
   └── Redis      127.0.0.1:6379
                       ↓
                  Celery Worker
```

Le contrat réseau cible sera :

```text
80    → exposé
8000  → localhost-only
5432  → localhost-only
6379  → localhost-only
```

## Rôles cibles

```text
common
postgresql
redis
django_app
celery
nginx
```

Les rôles `redis` et `celery` ne sont pas encore implémentés à l'issue de RC-00.

## Roadmap

Le plan détaillé est défini dans [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

Le prochain jalon après RC-00 est **RC-01 — Architecture et contrats**.