# RC-04 — Tâches de démonstration + API asynchrone

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ RUNTIME**

RC-04 ajoute une application Django dédiée aux tâches Celery de démonstration et expose une API minimale permettant de soumettre les tâches puis d'interroger leur état.

## Application ajoutée

```text
django-app/tasks_demo/
├── __init__.py
├── apps.py
├── tasks.py
├── urls.py
├── views.py
└── tests/
    ├── __init__.py
    ├── test_api.py
    └── test_tasks.py
```

`tasks_demo.apps.TasksDemoConfig` est enregistré dans `INSTALLED_APPS` et `tasks_demo.urls` est inclus dans `config.urls`.

## Tâches Celery

Trois tâches sont implémentées.

### `add(x, y)`

```text
21 + 21 → 42
```

Cette tâche permet de qualifier ultérieurement le round-trip le plus simple via le broker et le result backend.

### `uppercase(value)`

```text
"datascientest" → "DATASCIENTEST"
```

Cette tâche teste un payload chaîne JSON. L'API limite la valeur à 1024 caractères afin d'éviter un endpoint de démonstration totalement non borné.

### `database_probe()`

La tâche exécute réellement :

```sql
SELECT 1
```

via `django.db.connection`, puis renvoie :

```json
{
  "database": "connected",
  "query": 1
}
```

Quand le worker Celery sera démarré, cette tâche constituera une preuve du chemin :

```text
Django API
   ↓
Redis broker
   ↓
Celery Worker
   ↓
Django DB connection
   ↓
psycopg
   ↓
PostgreSQL
   ↓
SELECT 1
```

## API asynchrone

Endpoints :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

Les endpoints de soumission retournent un `202` avec :

```json
{
  "task_id": "...",
  "status": "PENDING"
}
```

Le endpoint de consultation utilise `celery.result.AsyncResult` et retourne le résultat uniquement quand la tâche est terminée avec succès.

En cas d'échec, l'API retourne seulement :

```json
{
  "error": "task_failed"
}
```

Le détail brut de l'exception Celery n'est donc pas exposé au client.

## Validation des entrées

`add` accepte uniquement des nombres JSON et rejette notamment les booléens.

`uppercase` exige une chaîne non vide de 1024 caractères maximum.

Les payloads JSON invalides retournent un statut `400`.

`database_probe` n'accepte aucun SQL fourni par le client ; la requête reste fixe (`SELECT 1`).

## CSRF et portée du laboratoire

Les endpoints POST de démonstration sont marqués `csrf_exempt` afin de permettre la future qualification par `curl`/GitHub Actions sans session Django.

Cette décision est acceptable pour ce laboratoire fermé car les tâches exposées sont volontairement bornées et non métier. Elle **ne doit pas être interprétée comme un modèle d'API publique de production**.

Pour une exposition réelle, il faudrait ajouter au minimum une politique d'authentification/autorisation, rate limiting et protection adaptée au type de client.

## Tests ajoutés

Les tests unitaires couvrent :

```text
add.run(21,21) → 42
uppercase.run("datascientest") → "DATASCIENTEST"
database_probe() avec connexion mockée
soumission add
validation payload add
soumission uppercase
soumission database_probe
consultation SUCCESS
consultation FAILURE sans fuite d'exception
```

Les appels `.delay()` et `AsyncResult` sont mockés dans ces tests. Ils vérifient donc le contrat applicatif, **pas encore le transport Redis/Celery réel**.

## Ce que RC-04 ne prouve pas encore

RC-04 ne démontre pas encore :

- que `redis-server` est installé ;
- que Redis répond à `PING` ;
- qu'un worker Celery tourne ;
- qu'un message publié est réellement consommé ;
- que Redis `/1` contient/rend le résultat ;
- que `database_probe()` atteint PostgreSQL depuis un vrai worker ;
- que la stack reste idempotente après ajout des nouveaux services.

Ces preuves seront apportées par RC-05 à RC-11.

## Critères de sortie RC-04

```text
tasks_demo enregistré dans Django                 ✅
add(x,y)                                           ✅
uppercase(value)                                   ✅
database_probe() / SELECT 1                        ✅
POST /api/tasks/add/                               ✅
POST /api/tasks/uppercase/                         ✅
POST /api/tasks/database-probe/                    ✅
GET /api/tasks/<task_id>/                          ✅
validation des payloads                            ✅
pas de fuite brute d'exception Celery              ✅
tests unitaires applicatifs ajoutés                ✅
qualification broker/worker réelle                 ⏳
```

## Prochaine étape

**RC-05 — rôle Ansible Redis** : installation de `redis-server`, configuration `127.0.0.1:6379`, `protected-mode yes`, authentification Vault, service systemd, handler et validation `PING → PONG`.
