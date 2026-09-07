#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$(cd "$PROJECT_DIR/.." && pwd)/evidence"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

TARGET_IMAGE="${E2E_TARGET_IMAGE:-geerlingguy/docker-ubuntu2404-ansible:latest}"
NETWORK="${E2E_NETWORK:-dst-ansible-django-redis-celery}"
SERVER_CONTAINER="${E2E_SERVER_CONTAINER:-dst-django-redis-celery-server1}"
KEEP_TARGET="${E2E_KEEP_TARGET:-0}"

INVENTORY="$PROJECT_DIR/inventories/prod/hosts.yml"
VAULT_FILE="$PROJECT_DIR/inventories/prod/group_vars/vault.yml"
VAULT_PASS_FILE="$PROJECT_DIR/.vault_pass"

mkdir -p "$EVIDENCE_DIR/logs" "$EVIDENCE_DIR/validation"
cd "$PROJECT_DIR"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

assert_network_contract() {
  local server_ip="$1"
  local output="$EVIDENCE_DIR/validation/redis-celery-network-$TIMESTAMP.txt"
  python3 - "$server_ip" <<'PY' | tee "$output"
import socket
import sys

host = sys.argv[1]

def probe(port: int, timeout: float = 1.5) -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        return sock.connect_ex((host, port)) == 0
    finally:
        sock.close()

checks = {
    80: True,
    8000: False,
    5432: False,
    6379: False,
}
for port, expected in checks.items():
    actual = probe(port)
    print(f"{host}:{port} reachable={str(actual).lower()} expected={str(expected).lower()}")
    if actual != expected:
        raise SystemExit(f"network contract failed for {host}:{port}")
PY
}

collect_diagnostics() {
  local output="$EVIDENCE_DIR/validation/redis-celery-diagnostics-$TIMESTAMP.txt"
  {
    echo "Redis/Celery mono-host E2E diagnostics"
    echo "timestamp=$TIMESTAMP"
    docker inspect "$SERVER_CONTAINER" 2>/dev/null || true
    docker logs "$SERVER_CONTAINER" 2>/dev/null || true
    docker exec "$SERVER_CONTAINER" systemctl --failed --no-pager 2>/dev/null || true
    for service in postgresql redis-server datascientest-django datascientest-celery datascientest-celery-beat nginx; do
      echo "===== $service ====="
      docker exec "$SERVER_CONTAINER" systemctl status "$service" --no-pager 2>/dev/null || true
      docker exec "$SERVER_CONTAINER" journalctl -u "$service" -n 120 --no-pager 2>/dev/null || true
    done
  } >"$output" 2>&1 || true
  echo "Diagnostics: $output"
}

cleanup() {
  rm -f "$INVENTORY" "$VAULT_FILE" "$VAULT_PASS_FILE"
  if [[ "$KEEP_TARGET" != "1" ]]; then
    docker rm -f "$SERVER_CONTAINER" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
  else
    echo "E2E_KEEP_TARGET=1: Docker target preserved for investigation."
  fi
}

on_exit() {
  local rc=$?
  trap - EXIT
  if [[ $rc -ne 0 ]]; then
    collect_diagnostics
  fi
  cleanup
  exit "$rc"
}
trap on_exit EXIT

for command in docker ansible ansible-playbook ansible-galaxy ansible-vault openssl curl python3; do
  require_command "$command"
done

[[ ! -e "$INVENTORY" ]] || fail "refusing to overwrite existing runtime inventory: $INVENTORY"
[[ ! -e "$VAULT_FILE" ]] || fail "refusing to overwrite existing Vault: $VAULT_FILE"
[[ ! -e "$VAULT_PASS_FILE" ]] || fail "refusing to overwrite existing Vault password file: $VAULT_PASS_FILE"

if docker inspect "$SERVER_CONTAINER" >/dev/null 2>&1; then
  fail "Docker target already exists: $SERVER_CONTAINER"
fi
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  fail "Docker network already exists: $NETWORK"
fi

echo "== RC-10 / static gate =="
bash tests/static_checks.sh

echo "== RC-10 / provision one Ubuntu 24.04 systemd target =="
docker pull "$TARGET_IMAGE"
docker network create "$NETWORK" >/dev/null
docker run --detach \
  --name "$SERVER_CONTAINER" \
  --hostname "$SERVER_CONTAINER" \
  --network "$NETWORK" \
  --privileged \
  --volume=/sys/fs/cgroup:/sys/fs/cgroup:rw \
  --cgroupns=host \
  "$TARGET_IMAGE" >/dev/null

ready=0
for _ in $(seq 1 30); do
  if ! docker inspect -f '{{.State.Running}}' "$SERVER_CONTAINER" 2>/dev/null | grep -q true; then
    fail "$SERVER_CONTAINER exited during startup"
  fi
  state="$(docker exec "$SERVER_CONTAINER" systemctl is-system-running 2>/dev/null || true)"
  if [[ "$state" == "running" || "$state" == "degraded" ]]; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == "1" ]] || fail "$SERVER_CONTAINER did not reach a usable systemd state"

SERVER_IP="$(docker inspect -f "{{with index .NetworkSettings.Networks \"$NETWORK\"}}{{.IPAddress}}{{end}}" "$SERVER_CONTAINER")"
[[ -n "$SERVER_IP" ]] || fail "server1 Docker IP could not be resolved"
printf 'server1=%s\n' "$SERVER_IP" | tee "$EVIDENCE_DIR/validation/redis-celery-address-$TIMESTAMP.txt"

echo "== RC-10 / generate mono-host inventory =="
cat >"$INVENTORY" <<EOF
---
all:
  children:
    app:
      hosts:
        server1:
          ansible_connection: community.docker.docker
          ansible_host: $SERVER_CONTAINER
          postgresql_host: 127.0.0.1
          postgresql_app_cidr: 127.0.0.1/32
          postgresql_listen_addresses: 127.0.0.1
          redis_host: 127.0.0.1
          redis_bind_address: 127.0.0.1
          django_allowed_hosts: "localhost,127.0.0.1,server1,$SERVER_IP"
    database:
      hosts:
        server1:
EOF

ansible-inventory -i "$INVENTORY" --graph | tee "$EVIDENCE_DIR/validation/redis-celery-inventory-$TIMESTAMP.txt"

echo "== RC-10 / generate encrypted ephemeral Vault =="
umask 077
DB_PASSWORD="$(openssl rand -hex 24)"
DJANGO_SECRET_KEY="$(openssl rand -hex 32)"
REDIS_PASSWORD="$(openssl rand -hex 24)"
VAULT_PASSWORD="$(openssl rand -hex 24)"
cat >"$VAULT_FILE" <<EOF
---
vault_postgresql_password: "$DB_PASSWORD"
vault_django_secret_key: "$DJANGO_SECRET_KEY"
vault_redis_password: "$REDIS_PASSWORD"
EOF
printf '%s\n' "$VAULT_PASSWORD" >"$VAULT_PASS_FILE"
ansible-vault encrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"
unset DB_PASSWORD DJANGO_SECRET_KEY REDIS_PASSWORD VAULT_PASSWORD

echo "== RC-10 / preflight =="
bash scripts/preflight.sh

echo "== RC-10 / first deployment =="
bash scripts/deploy.sh

echo "== RC-10 / runtime validation with real Redis/Celery/Beat paths =="
bash scripts/validate_runtime.sh

echo "== RC-10 / control-node HTTP validation =="
for endpoint in root health database redis celery info; do
  case "$endpoint" in
    root) path="/" ;;
    health) path="/health/" ;;
    database) path="/health/database/" ;;
    redis) path="/health/redis/" ;;
    celery) path="/health/celery/" ;;
    info) path="/api/info/" ;;
  esac
  curl --fail --show-error --silent --max-time 30 \
    -H 'Host: server1' \
    "http://$SERVER_IP$path" \
    >"$EVIDENCE_DIR/validation/redis-celery-http-$endpoint-$TIMESTAMP.json"
done

python3 - \
  "$EVIDENCE_DIR/validation/redis-celery-http-health-$TIMESTAMP.json" \
  "$EVIDENCE_DIR/validation/redis-celery-http-database-$TIMESTAMP.json" \
  "$EVIDENCE_DIR/validation/redis-celery-http-redis-$TIMESTAMP.json" \
  "$EVIDENCE_DIR/validation/redis-celery-http-celery-$TIMESTAMP.json" <<'PY'
import json
import sys
from pathlib import Path

health = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
database = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
redis = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
celery = json.loads(Path(sys.argv[4]).read_text(encoding="utf-8"))

assert health == {"status": "healthy"}, health
assert database.get("status") == "healthy", database
assert database.get("database") == "connected", database
assert int(database.get("query")) == 1, database
assert redis.get("status") == "healthy", redis
assert redis.get("redis") == "connected", redis
assert celery.get("status") == "healthy", celery
assert celery.get("celery") == "connected", celery
assert int(celery.get("workers", 0)) >= 1, celery
PY

echo "== RC-10 / service status =="
{
  echo "server1 postgresql=$(docker exec "$SERVER_CONTAINER" systemctl is-active postgresql)"
  echo "server1 redis=$(docker exec "$SERVER_CONTAINER" systemctl is-active redis-server)"
  echo "server1 gunicorn=$(docker exec "$SERVER_CONTAINER" systemctl is-active datascientest-django)"
  echo "server1 celery=$(docker exec "$SERVER_CONTAINER" systemctl is-active datascientest-celery)"
  echo "server1 celery_beat=$(docker exec "$SERVER_CONTAINER" systemctl is-active datascientest-celery-beat)"
  echo "server1 nginx=$(docker exec "$SERVER_CONTAINER" systemctl is-active nginx)"
} | tee "$EVIDENCE_DIR/validation/redis-celery-service-status-$TIMESTAMP.txt"

echo "== RC-10 / network exposure contract =="
assert_network_contract "$SERVER_IP"

echo "RC-10 qualification passed: static gate, mono-host deployment, PostgreSQL, Redis, Django, Celery Worker, Django Celery Beat, Nginx, async task round-trips and network contract are GREEN."
