# RC-02 — Dépendances Python Redis/Celery

## Statut

**TERMINÉ ✅ — contrat de dépendances préparé**

RC-02 étend la baseline Python afin de préparer l'intégration Celery/Redis sans encore modifier la configuration Django ni créer de worker systemd.

## Fichier modifié

```text
django-app/requirements.txt
```

Le contrat devient :

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
```

## Choix

### Celery

```text
celery>=5.5,<6
```

La borne majeure `<6` évite une mise à niveau majeure implicite pendant le projet tout en autorisant les correctifs et versions mineures compatibles de la branche 5.x retenue.

### redis-py

```text
redis>=6,<7
```

Le client Python Redis sera utilisé par :

- Django pour `PING`/health checks ;
- Celery via son transport Redis ;
- le result backend Celery.

## Contrats conservés

La variante conserve :

```text
Django 5.2.x
Gunicorn 23.x
psycopg 3.x
Python standard venv sous .venv
```

Aucune dépendance `virtualenv` n'est introduite.

## Ce que RC-02 ne prouve pas encore

À ce stade, aucun run E2E Redis/Celery n'a été exécuté. RC-02 ne prouve donc pas encore :

```text
installation pip réelle sur server1
connexion Redis
worker Celery
round-trip de tâche
idempotence
```

Ces preuves seront apportées par les jalons ultérieurs et la qualification dédiée.

## Prochain jalon

**RC-03 — Intégration Celery dans Django**

La prochaine étape doit ajouter :

```text
config/celery.py
configuration Celery dans settings.py
chargement de l'application Celery depuis config/__init__.py
variables d'environnement du broker/result backend
```

sans encore confondre cette configuration applicative avec le rôle Ansible `celery`, qui sera traité séparément en RC-06.
