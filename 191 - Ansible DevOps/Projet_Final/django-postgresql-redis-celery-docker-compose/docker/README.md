# Docker Compose — Multi-Environment Stack

Le dossier `docker/` porte un fichier de base commun et trois overlays explicites :

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
├── compose.prod.yml
├── nginx/
│   └── default.conf
└── redis/
    └── entrypoint.sh
```

## Topologie

`compose.yml` contient les six services : `nginx`, `web`, `db`, `redis`, `worker`, `beat`.

```text
Internet
   │
   ▼
nginx
   │ frontend
   ▼
web
   │ backend (internal)
   ├────────► db
   └────────► redis
                ▲
          worker / beat
```

`nginx` n'est pas membre du réseau `backend`; `db`, `redis`, `worker` et `beat` ne sont pas membres du réseau `frontend`. Le réseau `backend` est `internal: true`.

## Publication des ports

```text
DEV Full : 127.0.0.1:8080 → nginx:80 par défaut
STG/PROD: 0.0.0.0:80       → nginx:80 par défaut

8000 Gunicorn   → jamais publié
5432 PostgreSQL → jamais publié
6379 Redis      → jamais publié
```

## Hardening des process

`web`, `worker` et `beat` :

```text
image non-root
read_only root filesystem
no-new-privileges
cap_drop ALL
tmpfs /tmp
init=true
SIGTERM + stop_grace_period
CPU/RAM/PID limits
rotated json-file logs
```

Redis : utilisateur `redis`, rootfs read-only, `cap_drop ALL`, `no-new-privileges`, tmpfs runtime, volume `/data` writable.

Nginx : rootfs read-only, tmpfs runtime, `cap_drop ALL` puis ajout uniquement de `CHOWN`, `DAC_OVERRIDE`, `NET_BIND_SERVICE`, `SETGID`, `SETUID` pour rester compatible avec l'image officielle.

PostgreSQL : `no-new-privileges`, tmpfs `/tmp` et `/var/run/postgresql`, `shm_size`, limites CPU/RAM/PIDs et rotation des logs. Le rootfs reste writable comme exception explicite jusqu'à qualification d'un mode read-only compatible avec l'initialisation officielle.

## Healthchecks

```text
db     → pg_isready
redis  → PING authentifié
web    → /health/ + /health/database/ + /health/redis/
worker → celery inspect ping
beat   → process Beat + PeriodicTask DB présente
nginx  → reverse proxy /health/database/
```

La preuve fonctionnelle complète de Beat restera l'observation d'une tâche périodique réellement déclenchée et consommée.

## Logging

Tous les services utilisent `json-file` avec rotation :

```text
max-size=${DOCKER_LOG_MAX_SIZE:-10m}
max-file=${DOCKER_LOG_MAX_FILE:-3}
```

Django, Gunicorn et Celery continuent d'écrire sur stdout/stderr.

## Ressources

Les limites sont surchargeables sans rebuild via :

```text
POSTGRES_*_LIMIT / POSTGRES_CPUS
REDIS_*_LIMIT    / REDIS_CPUS
WEB_*_LIMIT      / WEB_CPUS
WORKER_*_LIMIT   / WORKER_CPUS
BEAT_*_LIMIT     / BEAT_CPUS
NGINX_*_LIMIT    / NGINX_CPUS
```

## Firewall hôte

Compose fournit la première barrière en ne publiant que Nginx. Le rôle Ansible `docker_runtime_hardening` fournit une défense supplémentaire : Docker reste en backend `iptables`, et `DOCKER-USER` saute vers `DST-COMPOSE-GUARD` pour autoriser uniquement les destinations publiques prévues puis bloquer le reste du forwarding Docker entrant sur l'interface externe.

Le matching utilise `conntrack --ctorigdstport` afin de raisonner sur le port hôte d'origine après DNAT.

## DEV Full / STG / PROD

DEV Full construit localement l'image commune et exige PostgreSQL. STG/PROD utilisent une `APP_IMAGE` immuable ; PROD doit promouvoir exactement le digest qualifié en STG.

## Statut

Le hardening est implémenté mais aucun `docker compose config`, runtime, firewall, reboot ou recovery GREEN n'est revendiqué avant DC-11 et les E2E suivants.
