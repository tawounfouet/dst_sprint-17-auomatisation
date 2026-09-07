# Playbooks — Variante Docker Compose

## `site.yml` — orchestration active DC-10

Le point d'entrée actif est désormais :

```text
Topology validation
        ↓
common
        ↓
docker_engine
        ↓
docker_runtime_hardening
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

## Playbooks spécialisés

```text
playbooks/docker_engine.yml      → Docker Engine + Compose v2
playbooks/runtime_hardening.yml  → daemon hardening + DOCKER-USER policy
playbooks/site.yml               → convergence complète
```

`runtime_hardening.yml` suppose que Docker Engine est déjà installé.

## Sélection Compose

`deployment_environment` est fourni par l'inventory. Le rôle `compose_stack` sélectionne exactement :

```text
dev  → compose.yml + compose.dev.yml
stg  → compose.yml + compose.stg.yml
prod → compose.yml + compose.prod.yml
```

En STG/PROD, `APP_IMAGE` doit être une référence immuable `@sha256:<64 hex>`.

## Secure runtime

Le fichier distant :

```text
/opt/datascientest-compose/docker/.env.runtime
```

est rendu `root:root` / `0600` depuis l'inventory/Vault avec `no_log: true`.

## Hardening hôte

DC-10 gère :

```text
/etc/docker/daemon.json
live-restore
rotation json-file
firewall-backend=iptables
DOCKER-USER → DST-COMPOSE-GUARD
```

Le drop-in systemd Docker réapplique la politique firewall après chaque restart du daemon.

## Validation actuelle

`compose_stack` exécute `docker compose config --quiet` avant convergence. Le rôle `docker_runtime_hardening` valide la configuration `dockerd`, `live-restore` et la présence du jump `DOCKER-USER`.

Ces contrôles sont implémentés mais ne constituent pas encore une preuve CI/E2E GREEN tant qu'ils n'ont pas été observés dans DC-11/DC-12/DC-13.

`playbooks/validate.yml` est encore issu de la baseline native et sera remplacé par la validation Compose E2E ; il ne doit pas être utilisé comme preuve de cette variante.
