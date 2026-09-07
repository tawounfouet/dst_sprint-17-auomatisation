# RC-06 — Rôle Ansible Celery Worker

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ E2E**

RC-06 ajoute un rôle Ansible dédié au worker Celery de la variante mono-serveur Django/PostgreSQL/Redis/Celery.

## Structure

```text
ansible-project/roles/celery/
├── defaults/main.yml
├── tasks/main.yml
├── handlers/main.yml
├── meta/main.yml
└── templates/celery-worker.service.j2
```

## Contrat runtime

Le worker est lancé par systemd avec :

```text
/opt/datascientest-django/.venv/bin/celery
  -A config worker
  --loglevel=INFO
  --concurrency=2
  --hostname=worker1@%H
```

Il utilise le même utilisateur système `django`, le même `WorkingDirectory` et le même `EnvironmentFile` que l'application Django.

## Dépendances

Le rôle vérifie la présence de :

```text
manage.py
.venv/bin/celery
/etc/datascientest-django/django.env
```

et attend que Redis soit disponible sur `127.0.0.1:6379` avant de démarrer le worker.

## Redémarrage cohérent

Le rôle tient compte des changements réalisés précédemment par `django_app` :

```text
source Django modifiée
requirements modifiés
EnvironmentFile modifié
unité systemd modifiée
```

Dans ces cas, le worker est redémarré. Sinon, un deuxième passage conserve simplement le service à l'état `started`, ce qui prépare la future preuve `changed=0`.

## Sécurité systemd

L'unité applique notamment :

```text
NoNewPrivileges=true
PrivateTmp=true
Restart=on-failure
```

Le worker ne possède aucun port public propre dans cette architecture.

## Validation prévue

Le rôle vérifie `systemctl is-active datascientest-celery`. La preuve fonctionnelle réelle sera plus exigeante lors de l'E2E :

```text
Django API
  ↓
Redis broker
  ↓
Celery Worker
  ↓
result backend
```

avec `add(21,21) → 42`, `uppercase(...)` et `database_probe() → SELECT 1`.

## Prochaine extension

RC-06B ajoute `django-celery-beat` et un service scheduler séparé avant l'orchestration globale.
