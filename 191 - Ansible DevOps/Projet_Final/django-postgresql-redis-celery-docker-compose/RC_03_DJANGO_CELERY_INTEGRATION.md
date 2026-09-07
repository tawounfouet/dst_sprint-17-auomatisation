# RC-03 — Intégration Celery dans Django

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ RUNTIME**

Cette étape branche Celery dans l'application Django de la variante `django-postgresql-redis-celery` sans encore démarrer de worker ni installer Redis comme service Ansible.

## Changements réalisés

### Initialisation Celery

Le fichier suivant est ajouté :

```text
django-app/config/celery.py
```

Il crée l'application Celery, charge la configuration Django via le namespace `CELERY` et active l'autodiscovery des tâches :

```text
Celery("datascientest_django")
        ↓
config_from_object("django.conf:settings", namespace="CELERY")
        ↓
autodiscover_tasks()
```

### Chargement automatique

`django-app/config/__init__.py` expose désormais :

```python
from .celery import app as celery_app
```

Le worker et Django partageront ainsi la même configuration applicative.

### Paramètres Django

`config/settings.py` lit maintenant les variables :

```text
CELERY_BROKER_URL
CELERY_RESULT_BACKEND
CELERY_RESULT_EXPIRES
```

Les contrats de sérialisation sont figés en JSON :

```text
accept content      = json
task serializer     = json
result serializer   = json
```

La timezone Celery est alignée sur `Europe/Paris` via `TIME_ZONE`.

### Contrat Redis pour Celery

Les valeurs Ansible cibles sont préparées :

```text
redis_host             = 127.0.0.1
redis_port             = 6379
redis_broker_database  = 0
redis_result_database  = 1
```

Les URL Celery sont construites depuis le mot de passe Vault, avec encodage URL du secret :

```text
broker  → redis://:<secret>@127.0.0.1:6379/0
result  → redis://:<secret>@127.0.0.1:6379/1
```

Le mot de passe n'est pas codé en dur dans Git.

### Variable Vault ajoutée

Le contrat Vault de la variante comprend désormais :

```yaml
vault_postgresql_password: ...
vault_django_secret_key: ...
vault_redis_password: ...
```

`vault.example.yml` ne contient que des placeholders.

### EnvironmentFile Django

Le template systemd partagé avec Gunicorn et, plus tard, Celery expose maintenant :

```text
CELERY_BROKER_URL
CELERY_RESULT_BACKEND
CELERY_RESULT_EXPIRES
```

## Ce que RC-03 ne prouve pas

Cette étape ne constitue pas encore une preuve que :

- Redis est installé ;
- Redis répond à `PING` ;
- un worker Celery tourne ;
- une tâche est réellement publiée ;
- une tâche est réellement consommée ;
- le result backend retourne un résultat ;
- `database_probe()` atteint PostgreSQL ;
- le second `site.yml` reste à `changed=0` après ajout Redis/Celery.

Ces preuves seront obtenues dans les étapes suivantes, puis dans la qualification E2E dédiée.

## Critères de sortie RC-03

```text
config/celery.py présent                         ✅
config/__init__.py expose celery_app             ✅
settings.py charge broker/result backend         ✅
sérialisation JSON                               ✅
configuration Redis broker /0 et result /1       ✅
secret Redis prévu via Vault                     ✅
django.env.j2 expose les variables Celery        ✅
aucun secret réel versionné                      ✅
```

## Prochaine étape

**RC-04 — Tâches de démonstration + API asynchrone** : création de `tasks_demo`, des tâches `add`, `uppercase`, `database_probe`, des endpoints de soumission et de consultation de statut, ainsi que des tests applicatifs associés.
