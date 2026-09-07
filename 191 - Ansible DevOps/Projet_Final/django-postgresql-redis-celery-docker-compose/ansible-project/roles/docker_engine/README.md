# Role `docker_engine`

Ce rôle prépare un hôte **Ubuntu 24.04 (Noble)** pour la variante Docker Compose du projet.

Il suit le mode d'installation par dépôt APT officiel Docker :

```text
remove conflicting distribution packages
        ↓
ca-certificates + curl
        ↓
/etc/apt/keyrings/docker.asc
        ↓
/etc/apt/sources.list.d/docker.sources
        ↓
docker-ce
        ↓
docker-ce-cli
        ↓
containerd.io
        ↓
docker-buildx-plugin
        ↓
docker-compose-plugin
        ↓
docker.service enabled + started
```

## Validations intégrées

Le rôle termine par des commandes non mutantes :

```text
docker info
docker compose version
docker buildx version
```

Une erreur de daemon ou l'absence du plugin Compose v2 fait donc échouer le rôle.

## Sécurité

Le rôle n'ajoute volontairement aucun utilisateur au groupe `docker` dans DC-07. L'appartenance au groupe `docker` confère un niveau de privilège très élevé sur l'hôte et sera traitée séparément si nécessaire.

Le rôle n'utilise pas le convenience script `get.docker.com`, ne déploie aucun conteneur applicatif et ne lance pas `hello-world`.

## Portée

```text
DC-07 : Docker Engine + Compose v2 uniquement
DC-08 : déploiement de la stack Compose via Ansible
```

Les anciens rôles systemd natifs copiés depuis la baseline restent présents comme référence historique mais ne doivent pas être combinés avec la future stack Compose active.
