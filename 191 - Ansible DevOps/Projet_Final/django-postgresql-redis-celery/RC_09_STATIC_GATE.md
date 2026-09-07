# RC-09 — Static gate Redis / Celery / Beat

## Statut

**IMPLÉMENTÉ ✅ — EXÉCUTION CI DÉDIÉE À VENIR EN RC-10**

RC-09 adapte la barrière de qualité statique héritée de la baseline Django/PostgreSQL à la nouvelle variante mono-host :

```text
Django + PostgreSQL + Redis + Celery Worker + Django Celery Beat + Nginx
```

Le but est de refuser avant tout E2E une structure incomplète, une mauvaise topologie, une exposition réseau involontaire, une régression `.venv`, une unité Celery incohérente ou un fichier sensible versionné.

## Structure contrôlée

`tests/static_checks.sh` exige désormais les rôles :

```text
common
postgresql
redis
django_app
celery
celery_beat
nginx
```

ainsi que leurs fichiers essentiels :

```text
roles/redis/handlers/main.yml
roles/celery/handlers/main.yml
roles/celery/templates/celery-worker.service.j2
roles/celery_beat/handlers/main.yml
roles/celery_beat/templates/celery-beat.service.j2
```

Le scaffold applicatif contrôle également :

```text
config/celery.py
tasks_demo/tasks.py
tasks_demo/views.py
tasks_demo/urls.py
tasks_demo/management/commands/ensure_demo_periodic_task.py
health/views.py
health/urls.py
```

## Dépendances Python

La barrière exige les contrats suivants :

```text
Django>=5.2,<5.3
gunicorn>=23,<24
psycopg[binary]>=3.2,<4
celery>=5.5,<6
redis>=6,<7
django-celery-beat>=2.9,<3
```

## Topologie mono-host

L'inventaire d'exemple doit désormais utiliser uniquement :

```text
server1
```

dans les groupes :

```text
app
database
```

La présence de `app1` ou `db1` dans `hosts.example.yml` est refusée.

Les anciens exemples `host_vars/app1.example.yml` et `host_vars/db1.example.yml` sont supprimés dans RC-09 ; `server1.example.yml` devient l'exemple canonique.

## Invariants réseau

Le static gate exige :

```text
Gunicorn    → 127.0.0.1:8000
PostgreSQL  → 127.0.0.1:5432
Redis       → 127.0.0.1:6379
```

Il refuse notamment :

```text
PostgreSQL 0.0.0.0/0 ou ::/0
Redis bind 0.0.0.0
Redis protected-mode no
DJANGO_ALLOWED_HOSTS = *
```

La preuve que ces ports ne sont réellement pas accessibles depuis l'extérieur du host reste une preuve runtime RC-10, pas statique.

## Redis

Le rôle Redis doit contenir :

```text
bind localhost
protected-mode yes
requirepass via variable
REDISCLI_AUTH
PING → PONG
```

La barrière vérifie également que le rôle ne passe pas le mot de passe à `redis-cli` via l'option `-a`.

## Celery Worker

Le template worker doit :

```text
utiliser {{ django_venv_dir }}/bin/celery
charger {{ django_environment_file }}
exécuter un worker séparé
ne pas utiliser worker -B
```

Cette dernière règle garantit que Beat reste un service distinct.

## Django Celery Beat

La barrière exige :

```text
django_celery_beat dans INSTALLED_APPS
DatabaseScheduler dans settings.py
service celery-beat séparé
management command ensure_demo_periodic_task
tâche tasks_demo.periodic_heartbeat
```

## Syntaxes

Le script conserve les contrôles :

```text
bash -n
Python ast.parse
YAML via PyYAML lorsque disponible
ansible-playbook --syntax-check
```

Pour le `--syntax-check`, si aucun Vault réel n'est présent, un Vault factice temporaire non secret contient maintenant les trois variables nécessaires :

```text
vault_postgresql_password
vault_django_secret_key
vault_redis_password
```

Il est supprimé automatiquement à la fin du contrôle.

## Fichiers sensibles

Le contrôle Git refuse notamment :

```text
.vault_pass
inventories/prod/hosts.yml
inventories/prod/group_vars/vault.yml
inventories/prod/host_vars/server1.yml
id_rsa / id_ed25519
*.pem
*.key
```

Aucun secret réel n'est ajouté au dépôt.

## Ce que RC-09 ne prouve pas

RC-09 est une barrière statique. Il ne prouve pas encore :

```text
redis-server active
Celery Worker actif
Celery Beat actif
Redis PING réel dans le harness final
add(21,21) → 42 via broker/worker/backend
database_probe → SELECT 1
heartbeat Beat réellement déclenché
ports internes invisibles depuis le runner
second site.yml → changed=0
```

Ces preuves appartiennent aux runs GitHub Actions des jalons RC-10 et RC-11.

## Prochaine étape

**RC-10 — Première qualification E2E GitHub Actions** : créer le harness mono-host Ubuntu 24.04 et le workflow dédié, exécuter la stack complète, observer les logs réels et ne déclarer GREEN que si le run se termine avec succès.
