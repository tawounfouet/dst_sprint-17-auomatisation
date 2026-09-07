# RC-06B — Django Celery Beat

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ E2E**

RC-06B ajoute la planification périodique persistante avec `django-celery-beat` et un service systemd Celery Beat séparé du worker.

## Dépendance

La variante ajoute :

```text
django-celery-beat>=2.9,<3
```

Le package est enregistré dans `INSTALLED_APPS` sous `django_celery_beat`. Ses migrations seront appliquées par le `manage.py migrate` déjà présent dans le rôle `django_app`.

## Scheduler

Django configure :

```text
CELERY_BEAT_SCHEDULER = django_celery_beat.schedulers:DatabaseScheduler
```

Le scheduler persiste donc ses définitions dans PostgreSQL au lieu d'utiliser un simple fichier local de schedule.

## Tâche périodique de démonstration

Une tâche est ajoutée :

```text
tasks_demo.periodic_heartbeat
```

Elle retourne :

```json
{
  "status": "heartbeat",
  "timestamp": "..."
}
```

Un management command idempotent est également ajouté :

```text
python manage.py ensure_demo_periodic_task --seconds 30
```

Il crée ou met à jour une `PeriodicTask` nommée :

```text
datascientest-demo-heartbeat
```

avec trois sorties possibles :

```text
created
updated
unchanged
```

Le rôle Ansible utilise ces sorties pour conserver un comportement idempotent.

## Rôle Ansible

```text
ansible-project/roles/celery_beat/
├── defaults/main.yml
├── tasks/main.yml
├── handlers/main.yml
├── meta/main.yml
└── templates/celery-beat.service.j2
```

Le service attendu est :

```text
datascientest-celery-beat.service
```

et exécute :

```text
celery -A config beat
  --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

## Isolation Worker / Beat

Le worker et Beat sont volontairement séparés :

```text
Celery Worker       → exécute les tâches
Celery Beat         → planifie/publie les tâches périodiques
Redis               → broker
PostgreSQL          → état django-celery-beat
```

Cette séparation évite le mode `worker -B`, qui mélange deux responsabilités et est moins adapté à un service supervisé proprement par systemd.

## Qualification future

L'E2E devra démontrer à la fois :

```text
API Django → Redis → Worker → résultat
```

et :

```text
DatabaseScheduler → Redis → Worker → periodic_heartbeat
```

La preuve Beat pourra combiner : service actif, `PeriodicTask` présente et compteur/trace d'exécution observée après un intervalle réel.

## Correctif de cohérence associé

Les commandes `manage.py check`, `migrate` et `collectstatic` du rôle `django_app` reçoivent désormais aussi `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND` et `CELERY_RESULT_EXPIRES`. Cela évite qu'elles échouent depuis que ces paramètres sont obligatoires dans `settings.py`.

## Suite

Le prochain jalon devient **RC-07 — orchestration globale** avec l'ordre :

```text
common → postgresql → redis → django_app → celery → celery_beat → nginx
```
