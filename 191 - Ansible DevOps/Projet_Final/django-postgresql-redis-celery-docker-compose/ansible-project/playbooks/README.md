# Playbooks — Variante Docker Compose

## État de transition

La variante a été copiée depuis la baseline native `django-postgresql-redis-celery/`. Les anciens `site.yml` et `validate.yml` décrivent encore la qualification systemd historique et restent présents comme **référence de migration** jusqu'à DC-08/DC-10.

Ils ne doivent pas être interprétés comme le point d'entrée final de la variante Docker Compose.

## `docker_engine.yml` — DC-07

Le playbook actif du jalon DC-07 est :

```text
playbooks/docker_engine.yml
```

Il cible le groupe `app`, élève les privilèges et applique uniquement :

```text
docker_engine
```

Il ne déploie aucun composant applicatif.

Exécution :

```bash
ansible-playbook \
  -i inventories/prod/hosts.yml \
  playbooks/docker_engine.yml
```

Syntax check :

```bash
ansible-playbook \
  -i inventories/prod/hosts.yml \
  playbooks/docker_engine.yml \
  --syntax-check
```

## Validations DC-07

Le rôle `docker_engine` vérifie lui-même :

```text
Docker service enabled + active
docker info
docker compose version
docker buildx version
```

Ces validations ne constituent pas encore une qualification CI ou E2E tant qu'elles n'ont pas été exécutées sur un hôte cible réel ou sur le futur harness de qualification.

## Cible DC-08

Le prochain jalon remplacera progressivement l'orchestration native par :

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

avec des inventories séparés :

```text
dev
stg
prod
```

et une sélection explicite des overlays Compose correspondants.
