# DC-03 — Django REST Framework

## Statut

```text
IMPLEMENTATION      ✅
RUNTIME QUALIFIED   ⏳
CI GREEN            ⏳
```

Ce jalon migre l'API de tâches asynchrones de vues Django JSON manuelles vers **Django REST Framework**, sans modifier les contrats fonctionnels déjà qualifiés dans la baseline native.

## Livrables

- ajout de `djangorestframework>=3.16,<4` ;
- ajout de `rest_framework` dans `INSTALLED_APPS` ;
- configuration DRF commune dans `config/settings/base.py` ;
- `BrowsableAPIRenderer` activé uniquement en DEV ;
- création de `tasks_demo/serializers.py` ;
- migration des endpoints vers `@api_view` + `Response` ;
- validation stricte des payloads avant soumission Celery ;
- conservation des codes HTTP et des messages d'erreur métier existants ;
- tests API basés sur `rest_framework.test.APIClient`.

## Endpoints conservés

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

## Serializers

```text
AddTaskSerializer
UppercaseTaskSerializer
TaskAcceptedSerializer
TaskStatusSerializer
```

Les champs d'entrée sont volontairement stricts afin de préserver le comportement historique :

```text
{"x": 21, "y": 21}       → accepté
{"x": "21", "y": 21}   → rejeté
{"x": true, "y": 21}    → rejeté

{"value": "datascientest"} → accepté
{"value": ""}             → rejeté
len(value) > 1024           → rejeté
```

DRF ne doit pas convertir implicitement la chaîne `"21"` en nombre, car cela casserait le contrat initial.

## Contrats de réponse préservés

Soumission acceptée :

```json
{
  "task_id": "...",
  "status": "PENDING"
}
```

avec HTTP `202`.

Payload `add` invalide :

```json
{"error": "x_and_y_must_be_numbers"}
```

Payload `uppercase` invalide :

```json
{"error": "value_must_be_a_non_empty_string_up_to_1024_chars"}
```

JSON invalide :

```json
{"error": "invalid_json"}
```

Échec Celery :

```json
{
  "task_id": "...",
  "status": "FAILURE",
  "error": "task_failed"
}
```

Aucune exception Celery/backend n'est exposée au client.

## Configuration DRF

Le socle `base.py` utilise :

```text
JSONParser
JSONRenderer
AllowAny
aucune authentication DRF par défaut
```

Ce choix est volontaire pour préserver le caractère public/anonyme de l'API de démonstration de la baseline. Il ne constitue pas une recommandation de sécurité pour une API métier de production ; l'authentification/autorisation devra être ajoutée dans un jalon de hardening applicatif si cette API évolue au-delà de la démonstration.

En DEV uniquement, le renderer HTML browsable est ajouté pour faciliter l'exploration locale.

STG et PROD restent JSON-only via la configuration commune.

## Tests ajoutés / renforcés

`tasks_demo/tests/test_api.py` vérifie désormais notamment :

```text
add valide → 202
string numérique → 400
booléen → 400
champ manquant → 400
JSON invalide → 400 + contrat legacy
uppercase valide → 202
uppercase vide → 400
uppercase > 1024 → 400
database_probe → 202
task SUCCESS → résultat retourné
task FAILURE → pas de fuite d'exception
GET sur endpoint POST → 405
```

Ces tests sont implémentés mais ne seront déclarés GREEN qu'après exécution dans le gate CI prévu au jalon DC-11.

## Compatibilité Celery

La migration DRF ne modifie pas les tâches :

```text
add
uppercase
database_probe
periodic_heartbeat
```

Les vues soumettent toujours les mêmes tâches Celery et le polling de résultat repose toujours sur `AsyncResult`.

## Prochain jalon

```text
DC-04 — 12-Factor Docker Image
```

Objectif : construire l'image applicative immutable commune à `web`, `worker` et `beat`, avec Dockerfile non-root, `.dockerignore`, dépendances intégrées au build, Gunicorn en port binding, logs console et arrêt propre.
