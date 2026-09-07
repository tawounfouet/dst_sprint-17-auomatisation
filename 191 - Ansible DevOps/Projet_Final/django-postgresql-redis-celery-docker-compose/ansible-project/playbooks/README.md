# Playbooks — Variante Docker Compose

## `site.yml` — orchestration active DC-08

Le point d'entrée actif de la variante Docker Compose est désormais :

```text
Topology validation
        ↓
common
        ↓
docker_engine
        ↓
compose_stack
```

Les anciens rôles natifs `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx` ne sont plus appelés par `site.yml`.

Le projet attend exactement un hôte dans le groupe `app` et refuse un groupe `database` actif afin d'éviter de réutiliser par erreur l'ancienne topologie systemd.

## Inventories

```text
inventories/dev/
inventories/stg/
inventories/prod/
```

Chaque inventory fournit :

```text
hosts.example.yml
host_vars/server1.example.yml
group_vars/all.yml
group_vars/vault.example.yml
```

Copier les fichiers `.example` vers leurs noms runtime, puis chiffrer `vault.yml`. Les vrais `hosts.yml`, `host_vars/server1.yml` et `vault.yml` sont ignorés par Git.

## Exécution

Depuis `ansible-project/` :

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/site.yml --ask-vault-pass
ansible-playbook -i inventories/stg/hosts.yml playbooks/site.yml --ask-vault-pass
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass
```

## Sélection Compose

`deployment_environment` est fourni par l'inventory. Le rôle `compose_stack` sélectionne alors exactement :

```text
dev  → compose.yml + compose.dev.yml
stg  → compose.yml + compose.stg.yml
prod → compose.yml + compose.prod.yml
```

En STG/PROD, `APP_IMAGE` doit être une référence immuable `@sha256:<64 hex>`.

## Runtime environment

Le fichier distant :

```text
/opt/datascientest-compose/docker/.env.runtime
```

est rendu en mode `0600` depuis les variables d'inventory/Vault avec `no_log: true`. DC-09 renforcera encore la gestion, la rotation et les gates de secrets.

## Validation actuelle

Le rôle exécute `docker compose config --quiet`, puis `community.docker.docker_compose_v2` avec `wait=true`. Les preuves CI/E2E et l'idempotence stricte restent à qualifier dans les jalons ultérieurs.

`playbooks/validate.yml` est encore issu de la baseline native et sera remplacé par la validation Compose dans DC-10/DC-12 ; il ne doit pas être utilisé comme preuve de cette variante.
