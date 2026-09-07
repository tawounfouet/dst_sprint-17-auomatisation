# RC-00 — Fork contrôlé de la baseline

## Objectif

Créer le squelette de `django-postgresql-redis-celery/` à partir de la baseline qualifiée `django-postgresql/`, sans modifier le projet source et sans hériter artificiellement de son statut GREEN.

## Source

```text
Dossier source  : 191 - Ansible DevOps/Projet_Final/django-postgresql/
Snapshot source : 22feae813b4e85df891304b596cfb07b8940081b
Branche source  : feat/ansible-django-postgresql-project
```

La qualification mono-host historique reste attachée au projet source. Elle n'est pas une preuve pour cette nouvelle variante.

## Éléments copiés

La copie RC-00 reprend les éléments utiles de la baseline :

```text
django-app/
ansible-project/
evidence/                 # structure vide / .gitkeep, pas de logs historiques
ARCHITECTURE.md
IMPLEMENTATION_GUIDE.md
```

Le nouveau `IMPLEMENTATION_PLAN.md` est conservé comme document directeur de la variante Redis/Celery.

## Éléments volontairement non copiés comme preuve

Les documents et résultats de qualification de la baseline ne sont pas dupliqués comme preuves du nouveau projet :

```text
E2E_QUALIFICATION_REPORT.md
MONOHOST_E2E_QUALIFICATION_REPORT.md
LOT_10_VALIDATION.md
LOT_11_VALIDATION.md
LOT_12_VALIDATION.md
LOT_13_VALIDATION.md
anciens logs runtime
anciens packages
anciens SHA-256
anciens Artifact IDs
```

Les validations antérieures restent consultables dans le dossier source.

## Intégrité de la baseline

RC-00 ne modifie aucun fichier sous :

```text
191 - Ansible DevOps/Projet_Final/django-postgresql/
```

La nouvelle variante évolue exclusivement sous :

```text
191 - Ansible DevOps/Projet_Final/django-postgresql-redis-celery/
```

## État après RC-00

```text
BASELINE COPIED          ✅
REDIS IMPLEMENTATION     ⏳
CELERY IMPLEMENTATION    ⏳
ASYNC TASK API           ⏳
E2E QUALIFICATION        ⏳
IDEMPOTENCE              ⏳
```

Aucun succès Redis/Celery n'est revendiqué à ce stade.

## Prochain jalon

**RC-01 — Architecture et contrats** : adapter les documents de conception à la stack Nginx → Gunicorn → Django → PostgreSQL + Redis → Celery et figer les responsabilités des nouveaux rôles.