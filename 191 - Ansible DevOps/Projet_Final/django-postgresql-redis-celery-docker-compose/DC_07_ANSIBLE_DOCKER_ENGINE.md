# DC-07 — Ansible Docker Engine

## Statut

```text
IMPLEMENTATION       ✅
ANSIBLE SYNTAX GREEN ⏳
RUNTIME QUALIFIED    ⏳
CI GREEN              ⏳
```

Ce jalon introduit le rôle Ansible `docker_engine` chargé de préparer l'hôte Ubuntu 24.04 pour la future stack Docker Compose. Il ne déploie encore aucun conteneur applicatif.

## Livrables

```text
ansible-project/
├── playbooks/
│   └── docker_engine.yml
└── roles/
    └── docker_engine/
        ├── README.md
        ├── defaults/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── meta/
            └── main.yml
```

## Plateforme cible

Le rôle est volontairement strict pour cette variante :

```text
Distribution : Ubuntu
Release      : 24.04 / noble
Architectures mappées : amd64, arm64, armhf, ppc64el, s390x
```

Une autre distribution/release ou une architecture non mappée fait échouer le preflight.

## Installation officielle par APT

Le rôle utilise le dépôt officiel Docker et non le convenience script.

Flux :

```text
conflicting packages removed
        ↓
ca-certificates + curl
        ↓
/etc/apt/keyrings/docker.asc
        ↓
/etc/apt/sources.list.d/docker.sources
        ↓
APT refresh
        ↓
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

Le fichier `docker.sources` utilise :

```text
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
```

## Conflits supprimés

Lorsque `docker_engine_remove_conflicting_packages=true`, le rôle retire les paquets susceptibles d'entrer en conflit avec les paquets officiels Docker :

```text
docker.io
docker-compose
docker-compose-v2
docker-doc
docker-buildx
podman-docker
containerd
runc
```

Les données Docker existantes sous `/var/lib/docker` ne sont pas supprimées par ce rôle.

## Service Docker

Le contrat Ansible est :

```text
docker.service
  state   = started
  enabled = true
```

Le rôle ne modifie encore ni `daemon.json`, ni les règles firewall, ni le groupe `docker`. Ces sujets appartiennent aux jalons de hardening ultérieurs.

## Validations intégrées

Après installation :

```text
docker info
docker compose version
docker buildx version
```

Ces tâches utilisent `changed_when: false` afin que les contrôles eux-mêmes ne cassent pas l'idempotence future.

## Pourquoi aucun `hello-world`

DC-07 qualifie l'installation du moteur et des plugins, pas le runtime applicatif. Le rôle ne télécharge donc pas volontairement une image de test externe.

La première exécution réelle de conteneurs arrivera avec DC-08/DC-12.

## Accès non-root

Aucun utilisateur n'est ajouté automatiquement au groupe `docker`.

Cette décision est volontaire : l'accès au socket Docker via ce groupe confère des privilèges très élevés sur l'hôte. L'automatisation continuera d'utiliser `become: true` pour les opérations d'administration Docker tant qu'une politique différente n'est pas explicitement décidée.

## Playbook autonome

```text
playbooks/docker_engine.yml
```

cible uniquement le groupe :

```text
app
```

et applique uniquement le rôle :

```text
docker_engine
```

L'ancien `site.yml` issu de la baseline native n'est pas encore remplacé dans DC-07 afin d'éviter de mélanger les services systemd historiques avec la future stack Compose.

## Idempotence attendue

Les mécanismes utilisés sont déclaratifs :

```text
apt state=present/absent
file state=directory
get_url stable destination
copy stable docker.sources
service state=started enabled=true
validation commands changed_when=false
```

Le gate `changed=0` sera toutefois prouvé seulement dans DC-14.

## Référence officielle vérifiée au moment du jalon

La conception suit la documentation officielle Docker pour Ubuntu : clé APT dans `/etc/apt/keyrings/docker.asc`, source deb822 `docker.sources`, puis installation de `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` et `docker-compose-plugin`.

## Limites actuelles

Aucun des points suivants n'est encore revendiqué comme observé :

```text
ansible-playbook --syntax-check GREEN
installation réelle sur Ubuntu 24.04
docker info GREEN observé
docker compose version GREEN observé
docker buildx version GREEN observé
idempotence changed=0
stack applicative déployée
```

## Prochain jalon

```text
DC-08 — Ansible compose_stack + inventories dev/stg/prod
```

Il introduira l'orchestration active `common → docker_engine → compose_stack`, les inventories multi-environnements et la sélection contrôlée des overlays Compose, sans réactiver les anciens rôles systemd natifs.
