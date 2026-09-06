# LOT 01 — Validation de la mini-application Django

## Contrat couvert

Le lot fournit les quatre endpoints définis par `IMPLEMENTATION_PLAN.md` :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

La configuration Django dépend exclusivement de variables d'environnement pour les paramètres sensibles et de connexion PostgreSQL. Gunicorn et `psycopg` font partie des dépendances applicatives.

## Tests ajoutés

La suite `tests/test_health.py` vérifie :

- l'identité de `/` ;
- le liveness `/health/` ;
- le succès de `/health/database/` avec `SELECT 1` ;
- le retour HTTP 503 lorsque la connexion DB échoue ;
- `/api/info/`.

Le test unitaire du health check DB simule uniquement la couche connexion afin de tester le contrat HTTP sans exiger PostgreSQL dans cette étape. La vraie connexion PostgreSQL sera prouvée pendant les lots runtime/E2E.

## Validation attendue localement

Avec les variables d'environnement minimales définies :

```bash
python manage.py check
python manage.py test tests
```

La qualification avec PostgreSQL réel n'appartient pas au LOT 01 ; elle sera effectuée après le rôle `postgresql` puis pendant la qualification E2E.
