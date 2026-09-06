# Projet Ansible — Django + PostgreSQL + Redis + Celery

Variante dérivée du projet `django-postgresql/` afin d'ajouter Redis et Celery sur une topologie mono-serveur Ubuntu 24.04.

## Statut

```text
BASELINE COPIED          ✅
ARCHITECTURE / CONTRACTS ✅
PYTHON DEPENDENCIES      ✅
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

## Architecture cible figée en RC-01

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

Le contrat réseau est :

```text
80    → exposé
8000  → localhost-only
5432  → localhost-only
6379  → localhost-only
```

Redis sera utilisé comme broker Celery (`/0`) et result backend (`/1`), avec authentification et mot de passe fourni par Ansible Vault.

## Dépendances Python — RC-02

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
```

Le runtime conserve Python standard `venv` sous `.venv` ; aucune dépendance `virtualenv` n'est introduite.

## Rôles cibles

```text
common
postgresql
redis
django_app
celery
nginx
```

Ordre prévu :

```text
common → postgresql → redis → django_app → celery → nginx
```

Les rôles `redis` et `celery` ne sont pas encore implémentés à l'issue de RC-02.

## Tâches de démonstration cibles

```text
add(21, 21)                → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe()           → PostgreSQL → SELECT 1
```

La future CI devra exécuter réellement ces tâches via Redis et un worker Celery.

## Documentation

Le plan détaillé est défini dans [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

Les contrats d'architecture sont définis dans [`ARCHITECTURE.md`](./ARCHITECTURE.md).

Étapes réalisées :

```text
RC-00  Fork contrôlé de la baseline    ✅
RC-01  Architecture et contrats        ✅
RC-02  Dépendances Python              ✅
```

Le prochain jalon est **RC-03 — Intégration Celery dans Django**.
