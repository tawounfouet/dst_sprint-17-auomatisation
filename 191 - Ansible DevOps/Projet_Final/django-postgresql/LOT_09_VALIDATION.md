# LOT 09 — Static checks et correction structurelle

## Objectif

Ajouter une barrière de qualité déterministe avant toute qualification E2E.

L'audit de structure réalisé pour construire cette barrière a mis en évidence une lacune du LOT 01 : le dépôt contenait les settings, vues et tests Django, mais pas plusieurs fichiers de scaffold indispensables aux commandes déjà documentées (`manage.py`, `requirements.txt`, routage URL et WSGI). Le LOT 09 corrige cette incohérence sans prétendre qu'elle constitue une preuve runtime.

## Corrections Django intégrées

```text
django-app/
├── manage.py
├── requirements.txt
├── config/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── health/
    ├── __init__.py
    ├── apps.py
    ├── urls.py
    └── views.py
```

Les dépendances restent bornées : Django 5.2, Gunicorn 23.x et psycopg 3.x.

## Hardening statique

Le wildcard `django_allowed_hosts: "*"` a été retiré. Les valeurs par défaut autorisent localhost, le nom d'inventaire de l'hôte applicatif et son `ansible_host`. Les fallbacks réseau ambigus de PostgreSQL ont également été retirés afin qu'une adresse d'inventaire absente provoque une erreur explicite plutôt qu'une configuration silencieuse.

## Suite de contrôles

| ID | Contrôle | Statut code |
|---|---|---|
| STATIC-01 | structure Ansible requise | ✅ implémenté |
| STATIC-02 | scaffold Django complet | ✅ implémenté |
| STATIC-03 | dépendances Django/Gunicorn/psycopg | ✅ implémenté |
| STATIC-04 | syntaxe Bash | ✅ implémenté |
| STATIC-05 | syntaxe Python via `ast` | ✅ implémenté |
| STATIC-06 | syntaxe YAML si PyYAML disponible | ✅ implémenté |
| STATIC-07 | contrat `.venv` sans `virtualenv` | ✅ implémenté |
| STATIC-08 | SCRAM + absence de `trust`/CIDR large | ✅ implémenté |
| STATIC-09 | Gunicorn uniquement sur `127.0.0.1:8000` | ✅ implémenté |
| STATIC-10 | absence de wildcard `ALLOWED_HOSTS` | ✅ implémenté |
| STATIC-11 | garde contre fichiers sensibles versionnés | ✅ implémenté |
| STATIC-12 | syntax-check Ansible si environnement disponible | ✅ implémenté |

## Exécution

```bash
cd "191 - Ansible DevOps/Projet_Final/django-postgresql/ansible-project"
./tests/static_checks.sh
```

## Statut de preuve

Le script est implémenté dans ce lot. Aucune exécution complète de cette suite contre un checkout local n'est déclarée réussie ici, et aucune preuve runtime/E2E n'est fabriquée. La première qualification réelle de la pile complète commence au LOT 10.
