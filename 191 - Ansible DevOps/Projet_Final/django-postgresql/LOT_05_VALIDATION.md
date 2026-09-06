# LOT 05 — Validation du rôle `nginx`

## Objectif

Le LOT 05 ajoute le frontend HTTP de l'application Django : **Nginx devant Gunicorn**, avec service des fichiers statiques et reverse proxy vers `127.0.0.1:8000`.

## Livrables

```text
ansible-project/roles/nginx/
├── README.md
├── defaults/main.yml
├── handlers/main.yml
├── meta/main.yml
├── tasks/main.yml
└── templates/
    └── django.conf.j2
```

## Contrôles implémentés

Le rôle :

1. installe `nginx` ;
2. vérifie que `{{ django_install_dir }}/staticfiles` existe ;
3. attend que Gunicorn soit joignable sur `127.0.0.1:8000` ;
4. génère un vhost dédié ;
5. supprime le site `default` ;
6. active le site Django ;
7. exécute `/usr/sbin/nginx -t` avant tout reload ;
8. active et démarre Nginx ;
9. attend l'ouverture de `127.0.0.1:80`.

## Flux attendu

```text
GET /
  ↓
Nginx :80
  ↓
Gunicorn 127.0.0.1:8000
  ↓
Django
  ↓
HTTP 200
```

Pour les statiques :

```text
GET /static/...
  ↓
Nginx
  ↓
/opt/datascientest-django/staticfiles/
```

## Validation runtime à produire plus tard

| ID | Contrôle | Statut actuel |
|---|---|---|
| NGX-01 | `nginx -t` | ⏳ runtime |
| NGX-02 | service Nginx active | ⏳ runtime |
| NGX-03 | port 80 local | ⏳ runtime |
| NGX-04 | Gunicorn upstream :8000 | ⏳ runtime |
| NGX-05 | `/` via Nginx | ⏳ runtime |
| NGX-06 | `/health/` via Nginx | ⏳ runtime |
| NGX-07 | `/health/database/` via Nginx | ⏳ runtime |
| NGX-08 | fichiers statiques | ⏳ runtime |
| NGX-09 | second run `changed=0` | ⏳ runtime |

## Statut

Le LOT 05 est **implémenté**. Il n'est pas encore déclaré **qualifié E2E** : les preuves runtime seront produites pendant les LOT 07 à 12.
