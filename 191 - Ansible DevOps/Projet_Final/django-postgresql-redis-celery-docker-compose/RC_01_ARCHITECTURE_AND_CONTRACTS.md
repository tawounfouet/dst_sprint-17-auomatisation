# RC-01 — Architecture et contrats Redis/Celery

## Statut

**TERMINÉ ✅**

RC-01 fige l'architecture et les contrats techniques de la variante `django-postgresql-redis-celery` avant toute modification de dépendances ou de code applicatif.

## Décision principale

La cible reste une topologie mono-serveur Ubuntu 24.04 :

```text
server1
├── Nginx :80
├── Gunicorn 127.0.0.1:8000
├── Django
├── PostgreSQL 127.0.0.1:5432
├── Redis 127.0.0.1:6379
└── Celery Worker
```

Le même hôte porte tous les rôles Ansible.

## Contrat réseau figé

```text
80    → exposé
8000  → localhost-only
5432  → localhost-only
6379  → localhost-only
```

La future qualification E2E devra faire échouer le pipeline si Gunicorn, PostgreSQL ou Redis devient joignable hors du host.

## Rôles Ansible cibles

```text
common
postgresql
redis
django_app
celery
nginx
```

Ordre :

```text
common → postgresql → redis → django_app → celery → nginx
```

## Redis

Redis est retenu comme :

```text
broker Celery        → DB logique /0
result backend       → DB logique /1
```

Contrat :

```text
bind 127.0.0.1
protected-mode yes
port 6379
authentification activée
```

Secret :

```yaml
vault_redis_password: ...
```

Le secret ne doit ni être committé, ni apparaître en clair dans les logs.

## Celery

Un seul worker est prévu dans la première itération.

Service systemd cible :

```text
datascientest-celery.service
```

Il réutilise :

- le code Django ;
- `/opt/datascientest-django/.venv` ;
- le même utilisateur système que Django ;
- le même fichier d'environnement runtime.

Celery Beat est explicitement hors périmètre de RC-01.

## Tâches de démonstration figées

```text
add(x, y)
uppercase(value)
database_probe()
```

Preuves attendues :

```text
add(21,21) = 42
uppercase("datascientest") = "DATASCIENTEST"
database_probe() → PostgreSQL → SELECT 1
```

## API cible

Endpoints existants conservés :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

Endpoints à ajouter :

```text
GET  /health/redis/
GET  /health/celery/
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

La soumission est asynchrone : le POST retourne un `task_id`, puis la CI poll l'endpoint de statut jusqu'à `SUCCESS`.

## Contrat fonctionnel de santé

Les vérifications ne devront pas se limiter à systemd :

```text
PostgreSQL → SELECT 1
Redis      → PING/PONG authentifié
Celery     → worker fonctionnel + vraie tâche exécutée
Django     → endpoints HTTP
```

## Qualification cible

Le scénario canonique prévu est :

```text
site.yml #1
  ↓
services actifs
  ↓
HTTP health
  ↓
Redis PING
  ↓
Celery add(21,21) → 42
  ↓
Celery uppercase → DATASCIENTEST
  ↓
Celery database_probe → SELECT 1
  ↓
contrat réseau
  ↓
site.yml #2
  ↓
server1 changed=0
  ↓
ZIP + SHA-256 + artifact
```

## Qualification héritée

Aucune preuve GREEN de `django-postgresql/` n'est héritée par cette variante.

RC-01 documente uniquement l'architecture et les contrats. À ce stade :

```text
REDIS IMPLEMENTATION     non commencée
CELERY IMPLEMENTATION    non commencée
ASYNC TASK API           non commencée
E2E QUALIFICATION        non commencée
```

## Prochain jalon

**RC-02 — Dépendances Python**

Objectif : étendre proprement `django-app/requirements.txt` avec Celery et le client Redis, conserver les versions bornées et préparer les tests statiques associés sans encore implémenter les tâches métier.
