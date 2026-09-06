# Role `nginx`

Expose l'application Django en HTTP et joue le rôle de reverse proxy devant Gunicorn.

## Architecture

```text
Client
  │
  │ HTTP :80
  ▼
Nginx
  │
  ├── /static/ → /opt/datascientest-django/staticfiles/
  │
  └── / → http://127.0.0.1:8000
                    │
                    ▼
                 Gunicorn
                    │
                    ▼
                  Django
```

Gunicorn reste volontairement inaccessible depuis le réseau externe ; seul Nginx écoute sur le port HTTP public.

## Responsabilités

- installer Nginx ;
- vérifier que `collectstatic` a déjà produit le répertoire statique ;
- vérifier que Gunicorn écoute bien sur `127.0.0.1:8000` ;
- générer le vhost Django ;
- désactiver le site Nginx par défaut ;
- activer le vhost Django ;
- exécuter `nginx -t` avant reload ;
- démarrer et activer Nginx ;
- attendre l'ouverture du port HTTP local.

## Variables principales

```yaml
nginx_listen_port: 80
nginx_server_name: "_"
nginx_upstream_host: 127.0.0.1
nginx_upstream_port: 8000
nginx_static_url: /static/
nginx_static_root: "{{ django_install_dir }}/staticfiles"
```

## Reverse proxy

Le vhost transmet notamment :

```text
Host
X-Real-IP
X-Forwarded-For
X-Forwarded-Proto
```

vers Gunicorn.

## Idempotence attendue

Après convergence :

- le paquet Nginx reste `present` ;
- le vhost reste inchangé ;
- le site par défaut reste absent ;
- le lien symbolique reste en place ;
- `nginx -t` reste une vérification sans changement ;
- le service reste `started/enabled`.

La preuve réelle `changed=0` sera produite lors du scénario E2E.
