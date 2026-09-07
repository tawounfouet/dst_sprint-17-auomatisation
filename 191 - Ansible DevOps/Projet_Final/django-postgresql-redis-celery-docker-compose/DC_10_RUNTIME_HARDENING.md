# DC-10 — Runtime Hardening

## Statut

```text
IMPLEMENTATION                 ✅
COMPOSE SECURITY CONTROLS      ✅ IMPLEMENTED
NETWORK SEGMENTATION           ✅ IMPLEMENTED
RESOURCE LIMITS                ✅ IMPLEMENTED
LOG ROTATION                   ✅ IMPLEMENTED
DOCKER DAEMON HARDENING        ✅ IMPLEMENTED
DOCKER-USER POLICY             ✅ IMPLEMENTED
COMPOSE CONFIG GREEN           ⏳
RUNTIME QUALIFIED              ⏳
FIREWALL QUALIFIED             ⏳
REBOOT/RECOVERY QUALIFIED      ⏳
CI GREEN                       ⏳
```

DC-10 durcit le runtime de la variante Docker Compose sans modifier le contrat fonctionnel de l'application.

## Orchestration active

Le jalon introduit un rôle dédié entre installation Docker et déploiement applicatif :

```text
common
  ↓
docker_engine
  ↓
docker_runtime_hardening
  ↓
compose_stack
```

`playbooks/runtime_hardening.yml` permet également d'appliquer ce rôle isolément sur un hôte où Docker Engine est déjà installé.

## Hardening Docker daemon

Le rôle `docker_runtime_hardening` gère `/etc/docker/daemon.json` avec :

```text
live-restore=true
log-driver=json-file
max-size=10m
max-file=3
iptables=true
ip6tables=true
firewall-backend=iptables
```

La configuration est contrôlée par `dockerd --validate` avant restart. Le rôle valide ensuite `docker info` et exige `Live Restore Enabled: true`.

Le choix du backend `iptables` est explicite afin d'utiliser le contrat `DOCKER-USER`. Une migration future vers nftables devra définir une politique nftables native.

## Hardening des process applicatifs

L'ancre Compose commune de `web`, `worker` et `beat` applique :

```text
init: true
read_only: true
security_opt: no-new-privileges:true
cap_drop: ALL
tmpfs /tmp
restart: unless-stopped
stop_grace_period: 30s
json-file log rotation
CPU/RAM/PID limits
```

L'image applicative reste non-root (`app`, UID 10001). Le volume `static_data` reste l'emplacement writable contrôlé utilisé par `web` pour `collectstatic`.

## Redis

Redis continue de tourner explicitement en utilisateur `redis` avec authentification obligatoire et ajoute :

```text
read_only root filesystem
cap_drop ALL
no-new-privileges
tmpfs /tmp et /run
volume redis_data writable
CPU/RAM/PID limits
log rotation
```

## Nginx

Nginx utilise :

```text
read_only root filesystem
no-new-privileges
cap_drop ALL
cap_add CHOWN,DAC_OVERRIDE,NET_BIND_SERVICE,SETGID,SETUID
tmpfs /tmp, /var/cache/nginx et /var/run
resource limits
log rotation
```

La configuration ajoute :

```text
server_tokens off
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: same-origin
```

HSTS n'est pas activé avant qualification HTTPS/TLS.

## PostgreSQL

PostgreSQL reçoit :

```text
no-new-privileges
tmpfs /tmp
tmpfs /var/run/postgresql
shm_size
CPU/RAM/PID limits
log rotation
restart unless-stopped
stop_grace_period 60s
```

Le root filesystem PostgreSQL reste writable. C'est une exception volontaire afin de ne pas fragiliser l'initialisation, les permissions et le cycle de vie du volume de l'image officielle avant qualification dédiée.

## Logging et ressources

Tous les services utilisent `json-file` avec rotation. Les budgets CPU/RAM/PIDs sont posés par défaut et restent surchargeables par variables d'environnement sans rebuild.

Ces valeurs sont des garde-fous, pas un capacity planning production validé.

## Healthchecks renforcés

```text
db     → pg_isready
redis  → PING authentifié
web    → /health/ + /health/database/ + /health/redis/
worker → celery inspect ping
beat   → process Beat + PeriodicTask datascientest-demo-heartbeat enabled
nginx  → reverse proxy /health/database/
```

Le healthcheck Beat ne remplace pas la preuve fonctionnelle E2E : DC-12/DC-13 devront démontrer qu'une occurrence périodique est réellement publiée puis consommée.

## Segmentation réseau

Le réseau unique est remplacé par :

```text
frontend
backend (internal=true)
```

Matrice :

```text
nginx   → frontend
web     → frontend + backend
db      → backend
redis   → backend
worker  → backend
beat    → backend
```

Nginx ne peut donc pas joindre directement PostgreSQL/Redis. Worker et Beat n'ont pas d'egress Internet via le réseau backend interne. Si de futures tâches Celery nécessitent un accès externe, un chemin egress explicite devra être ajouté.

## Contrat des ports

```text
DEV Full : 127.0.0.1:8080 → nginx:80
STG/PROD: 0.0.0.0:80       → nginx:80

8000 → non publié
5432 → non publié
6379 → non publié
```

## DOCKER-USER

Docker gère ses règles de bridge/NAT. DC-10 ajoute une chaîne projet :

```text
DOCKER-USER
   ↓
DST-COMPOSE-GUARD
```

La politique :

```text
RELATED,ESTABLISHED → RETURN
ports publics explicitement autorisés → RETURN
reste inbound depuis l'interface externe → DROP
autres directions/interfaces → RETURN
```

Le matching des ports publiés utilise `conntrack --ctorigdstport` car `DOCKER-USER` voit les paquets après DNAT.

Valeurs par défaut :

```text
DEV      → 8080 + 443, source 127.0.0.1/32
STG/PROD → 80 + 443, source 0.0.0.0/0
```

Le script géré vérifie la présence et le nombre exact des règles attendues. Il ne reconstruit la chaîne qu'en cas de dérive/variation du contrat et retourne `changed` ou `unchanged`, ce qui prépare l'idempotence DC-14.

Le drop-in `/etc/systemd/system/docker.service.d/20-datascientest-firewall.conf` exécute de nouveau la politique après démarrage/restart Docker.

## Recovery

Les services Compose utilisent `restart: unless-stopped`. L'application combine `SIGTERM`, `stop_grace_period`, `init=true`, rootfs read-only et volumes nommés. `live-restore` complète le contrat au niveau du daemon.

Aucune preuve de reboot/recovery n'est encore revendiquée.

## Limites actuelles

DC-10 n'a pas encore prouvé :

```text
dockerd --validate GREEN observé en CI
docker compose config GREEN
compatibilité read_only runtime des services
respect effectif des limites ressources
healthy des six services
DOCKER-USER sur hôte réel
reboot/recovery
absence runtime des ports 8000/5432/6379
```

## Prochain jalon

```text
DC-11 — Unit Tests + Static Gate + Compose Validation
```

DC-11 devra contrôler : configuration Django/DRF, anti-SQLite, image non-root, six services, hardening, réseaux, ports, secrets, Ansible syntax-check, `dockerd --validate` lorsque disponible et `docker compose config` DEV/STG/PROD avec valeurs canaris.
