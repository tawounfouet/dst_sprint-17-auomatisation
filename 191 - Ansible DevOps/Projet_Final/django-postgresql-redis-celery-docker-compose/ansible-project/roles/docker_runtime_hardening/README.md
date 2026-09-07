# Role `docker_runtime_hardening`

Ce rôle applique le durcissement hôte après `docker_engine` et avant `compose_stack`.

```text
common
  ↓
docker_engine
  ↓
docker_runtime_hardening
  ↓
compose_stack
```

## Docker daemon

Le rôle gère `/etc/docker/daemon.json` avec :

```text
live-restore=true
json-file logging
max-size=10m
max-file=3
iptables=true
ip6tables=true
firewall-backend=iptables
```

La configuration est validée par `dockerd --validate` avant restart. Après convergence, `docker info` doit confirmer `Live Restore Enabled: true`.

## DOCKER-USER

Le rôle gère uniquement une chaîne utilisateur dédiée et laisse Docker propriétaire de ses règles de bridge/NAT :

```text
DOCKER-USER
   ↓
DST-COMPOSE-GUARD
```

La chaîne autorise `RELATED,ESTABLISHED`, puis les ports publiés explicitement autorisés via `conntrack --ctorigdstport`, bloque le reste du trafic entrant depuis l'interface externe et laisse tomber les autres directions/interfaces sur `RETURN`.

Par défaut :

```text
DEV      → original dst port 8080 + 443, source 127.0.0.1/32
STG/PROD → original dst ports 80 + 443, source 0.0.0.0/0
```

Le bind Compose DEV reste `127.0.0.1:8080`; la règle firewall est une défense supplémentaire et non le mécanisme principal d'isolation.

## Idempotence

Le script `/usr/local/sbin/datascientest-docker-user-firewall` vérifie d'abord la présence et le nombre exact des règles attendues. Il ne reconstruit la chaîne que si elle a dérivé ou si le contrat a changé, puis retourne `changed` ou `unchanged` à Ansible.

Le drop-in systemd :

```text
/etc/systemd/system/docker.service.d/20-datascientest-firewall.conf
```

réapplique la politique après chaque démarrage/restart du daemon Docker.

## Limites

Le projet force le backend Docker `iptables` afin d'utiliser `DOCKER-USER`. Une migration future vers nftables devra définir un contrat natif nftables au lieu de réutiliser cette chaîne.

Aucune preuve runtime/firewall GREEN n'est revendiquée avant DC-11/DC-12/DC-13.
