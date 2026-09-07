# Amendement au plan d’implantation — Django Celery Beat

## Décision

À la demande formulée après RC-04, `django-celery-beat` devient désormais **dans le périmètre de la première qualification**.

Cet amendement remplace donc l'ancien non-objectif « Celery Beat » du plan initial.

## Nouvelle architecture complémentaire

```text
PostgreSQL
   ▲
   │ état scheduler
   │
Django Celery Beat
   │
   │ publie les tâches périodiques
   ▼
Redis broker
   │
   ▼
Celery Worker
```

## Nouveau rôle

```text
roles/celery_beat/
```

Le worker et Beat restent deux services systemd indépendants.

## Nouvelle tâche de qualification

```text
tasks_demo.periodic_heartbeat
```

La définition périodique est persistée via `django-celery-beat` et créée de façon idempotente par :

```text
python manage.py ensure_demo_periodic_task --seconds 30
```

## Roadmap amendée

```text
RC-06   rôle Celery Worker
RC-06B  django-celery-beat + DatabaseScheduler + periodic_heartbeat
RC-07   orchestration globale
RC-08   validation runtime Worker + Beat
RC-09   static gate
RC-10   qualification E2E immédiate + périodique
RC-11   idempotence
RC-12   packaging + artifact
RC-13   rapport final
```

## Definition of Done ajoutée

La qualification finale devra également prouver :

```text
celery-beat service active
PeriodicTask datascientest-demo-heartbeat présente
DatabaseScheduler utilisé
une émission périodique réellement observée
le worker reçoit/exécute periodic_heartbeat
aucun redémarrage inutile au second site.yml
```

Cet amendement ne modifie pas la règle principale : aucun succès runtime ne sera déclaré avant observation réelle dans GitHub Actions.
