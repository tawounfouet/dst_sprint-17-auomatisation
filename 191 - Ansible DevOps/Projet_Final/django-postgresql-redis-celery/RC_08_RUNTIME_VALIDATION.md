# RC-08 — Runtime validation Redis / Celery / Beat

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ DANS GITHUB ACTIONS**

RC-08 transforme `playbooks/validate.yml` en contrat runtime de la variante mono-serveur Django + PostgreSQL + Redis + Celery Worker + Django Celery Beat.

Le playbook de validation est maintenant conçu pour vérifier les services, les dépendances locales, les endpoints de santé et deux vrais round-trips Celery lorsque la stack est déployée.

## Services contrôlés

La validation exige que les services suivants soient actifs :

```text
postgresql
datascientest-django
redis-server
datascientest-celery
datascientest-celery-beat
nginx
```

Un simple état systemd n'est cependant pas considéré comme une preuve suffisante.

## PostgreSQL

Le contrat historique est conservé :

```text
service active
127.0.0.1:5432 accessible localement
database django_app présente
role django_app présent
/health/database/ → SELECT 1
```

## Redis

La validation Redis combine :

```text
redis-server active
127.0.0.1:6379 accessible localement
PING authentifié → PONG
GET /health/redis/ → healthy
```

Le mot de passe n'est pas passé sur la ligne de commande `redis-cli`. Il est injecté via `REDISCLI_AUTH` et la tâche Ansible correspondante utilise `no_log: true`.

## Celery Worker

Le worker est contrôlé à deux niveaux :

```text
systemd datascientest-celery active
GET /health/celery/ → worker répond au control ping
```

Le endpoint `/health/celery/` ne considère pas la simple accessibilité de Redis comme suffisante : au moins une réponse au `Celery control ping` est requise.

## Round-trip asynchrone réel

`validate.yml` est maintenant prêt à exécuter réellement :

```text
POST /api/tasks/add/ {"x":21,"y":21}
        ↓
Redis /0
        ↓
Celery Worker
        ↓
Redis /1
        ↓
GET /api/tasks/<task_id>/
        ↓
SUCCESS / result = 42
```

Puis :

```text
POST /api/tasks/database-probe/
        ↓
Redis
        ↓
Celery Worker
        ↓
Django DB connection
        ↓
PostgreSQL
        ↓
SELECT 1
        ↓
SUCCESS / query = 1
```

Ces deux contrôles constituent la preuve fonctionnelle la plus importante du worker.

## Django Celery Beat

La validation vérifie :

```text
datascientest-celery-beat active
PeriodicTask datascientest-demo-heartbeat présente
task = tasks_demo.periodic_heartbeat
enabled = true
total_run_count >= 1
```

Le dernier critère oblige le `DatabaseScheduler` à avoir réellement déclenché au moins une occurrence. Le playbook attend au maximum environ une minute afin de laisser passer l'intervalle de laboratoire de 30 secondes.

Cette preuve démontre que Beat a planifié/publié une occurrence. La consommation générale du worker est prouvée séparément par les round-trips `add` et `database_probe`.

## Endpoints de santé ajoutés

La variante expose maintenant :

```text
GET /health/redis/
GET /health/celery/
```

`/health/redis/` exécute un vrai `PING` via le client Python Redis en utilisant `CELERY_BROKER_URL`.

`/health/celery/` utilise le control API Celery et exige au moins une réponse worker.

Aucun mot de passe Redis ni détail brut d'exception n'est exposé dans ces payloads.

## Ce que RC-08 ne prouve pas encore

Le code de validation est maintenant implémenté, mais aucun nouveau run GitHub Actions Redis/Celery/Beat n'a encore été observé.

RC-08 ne permet donc pas encore d'affirmer :

```text
GitHub Actions GREEN
ports 8000/5432/6379 inaccessibles depuis le runner
second site.yml → changed=0
package final qualifié
artifact final qualifié
```

Ces preuves viendront avec RC-09 à RC-12.

## Critères de sortie

```text
PostgreSQL service + DB + role                       ✅ code de validation
Redis service + PING                                 ✅ code de validation
Gunicorn service                                     ✅ code de validation
Celery Worker service                                ✅ code de validation
Celery Beat service                                  ✅ code de validation
Nginx service + nginx -t                             ✅ code de validation
/health/                                             ✅ code de validation
/health/database/                                    ✅ code de validation
/health/redis/                                       ✅ implémenté
/health/celery/                                      ✅ implémenté
add(21,21) → result 42                               ✅ scénario de validation
Celery database_probe → SELECT 1                    ✅ scénario de validation
Beat PeriodicTask total_run_count >= 1               ✅ scénario de validation
preuve runtime GitHub Actions                       ⏳
```

## Prochaine étape

**RC-09 — Static gate** : adapter les contrôles statiques hérités à la topologie `server1`, aux rôles `redis`, `celery`, `celery_beat`, aux nouveaux endpoints et aux invariants localhost-only, puis lancer la première qualification E2E en RC-10.
