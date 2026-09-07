# DC-02 — Django Configuration Foundation

## Statut

```text
IMPLEMENTATION      ✅
RUNTIME QUALIFIED   ⏳
CI GREEN            ⏳
```

Ce jalon implémente la fondation de configuration multi-environnement de la variante Docker Compose. Il ne constitue pas encore une qualification runtime Docker/Compose.

## Objectifs livrés

- adoption de `django-environ` comme parser de configuration Django ;
- remplacement du `settings.py` monolithique par `config/settings/` ;
- environnements explicites `dev`, `stg`, `prod` ;
- métadonnées `APPLICATION_ENV`, `APPLICATION_VERSION`, `APPLICATION_COMMIT` ;
- configuration par `DATABASE_URL` ;
- fallback SQLite uniquement lorsque `DATABASE_URL` est absente en DEV ;
- PostgreSQL obligatoire en STG et PROD ;
- rejet d'une URL SQLite explicite, y compris en DEV ;
- interdiction de tout fallback sur erreur de connexion PostgreSQL ;
- fichiers `.env.*.example` sans secrets réels ;
- logs Django dirigés vers la console ;
- tests unitaires de la politique de base de données.

## Structure

```text
django-app/config/settings/
├── __init__.py
├── base.py
├── database.py
├── dev.py
├── stg.py
└── prod.py
```

Le module par défaut pour `manage.py`, WSGI et Celery est `config.settings.dev`. Les environnements gérés doivent toujours fournir explicitement `DJANGO_SETTINGS_MODULE=config.settings.stg` ou `config.settings.prod`.

## Contrat base de données

```text
DEV + DATABASE_URL absente      → SQLite ✅
DEV + PostgreSQL URL            → PostgreSQL ✅
DEV + SQLite URL explicite      → FAIL ❌
STG + DATABASE_URL absente      → FAIL ❌
STG + SQLite URL                → FAIL ❌
PROD + DATABASE_URL absente     → FAIL ❌
PROD + SQLite URL               → FAIL ❌
STG/PROD + PostgreSQL URL       → PostgreSQL ✅
```

Le code ne tente jamais une connexion PostgreSQL pour décider de basculer vers SQLite. Une indisponibilité PostgreSQL doit rester une panne visible.

## DEV Lite / DEV Full

```text
DEV Lite
  config.settings.dev
  DATABASE_URL absente
  SQLite local

DEV Full
  config.settings.dev
  DATABASE_URL PostgreSQL
  Redis/Celery fournis par l'environnement Compose
```

SQLite n'est pas destiné à être partagé entre les futurs conteneurs `web`, `worker` et `beat`.

## Sécurité et 12-Factor

Les secrets restent externes au code. Les exemples utilisent uniquement des placeholders `CHANGE_ME_*`. Les vrais fichiers `.env*` sont ignorés par Git ; seuls `.env.dev.example`, `.env.stg.example` et `.env.prod.example` sont versionnés.

Les settings ajoutent également une configuration de logging console afin de préparer le facteur XI — logs comme flux d'événements.

## Tests ajoutés

`tests/test_settings_database_policy.py` couvre :

```text
DEV sans DATABASE_URL → SQLite
DEV avec PostgreSQL → PostgreSQL
DEV avec SQLite explicite → rejet
STG sans DATABASE_URL → rejet
PROD avec SQLite → rejet
PROD avec PostgreSQL → accepté
```

Ces tests sont implémentés mais seront intégrés au gate CI dédié dans DC-11. Aucun résultat GREEN n'est revendiqué à ce stade.

## Prochain jalon

```text
DC-03 — Django REST Framework
```

Il ajoutera `djangorestframework`, `rest_framework` dans `INSTALLED_APPS`, puis migrera l'API asynchrone actuelle vers de vraies vues/serializers DRF tout en conservant les contrats fonctionnels déjà qualifiés dans la baseline.
