# LOT 04 — Validation du rôle `django_app`

## Statut

**Implémenté ✅ — qualification runtime à venir.**

## Choix demandé : `venv` et `.venv`

Le LOT 04 n'utilise pas `virtualenv`.

Le runtime Python est créé avec la bibliothèque standard :

```bash
python3 -m venv /opt/datascientest-django/.venv
```

Le chemin partagé du projet est donc :

```text
django_install_dir = /opt/datascientest-django
django_venv_dir    = /opt/datascientest-django/.venv
```

## Livrables

```text
roles/django_app/
├── README.md
├── defaults/main.yml
├── handlers/main.yml
├── meta/main.yml
├── tasks/main.yml
└── templates/
    ├── django.env.j2
    └── django-gunicorn.service.j2
```

## Responsabilités implémentées

```text
python3-venv + pip + build deps
        ↓
user/group django
        ↓
deploy source
        ↓
python3 -m venv .venv
        ↓
install requirements dans .venv
        ↓
render environnement sécurisé
        ↓
Django check
        ↓
migrations
        ↓
collectstatic
        ↓
Gunicorn / systemd
```

## Idempotence prévue

- `python3 -m venv` utilise `creates: .venv/bin/python` ;
- `copy`, `template`, `apt`, `user` et `group` sont déclaratifs ;
- `migrate` n'est marqué `changed` que lorsque Django n'indique pas `No migrations to apply` ;
- `collectstatic` n'est marqué `changed` que lorsque des fichiers sont effectivement copiés ;
- `daemon_reload` n'est exécuté que lorsque l'unité systemd change.

La preuve définitive reste le second run E2E avec `changed=0`.

## Contrôles runtime à produire

```text
APP-01 .venv/bin/python existe           ⏳
APP-02 Django dependencies installées     ⏳
APP-03 manage.py check                    ⏳
APP-04 migrations PostgreSQL              ⏳
APP-05 collectstatic                      ⏳
APP-06 Gunicorn service active            ⏳
APP-07 127.0.0.1:8000 répond              ⏳
APP-08 /health/database/ via Django        ⏳
APP-09 second run changed=0               ⏳
```

Aucun de ces contrôles runtime n'est déclaré réussi avant leur exécution réelle.
