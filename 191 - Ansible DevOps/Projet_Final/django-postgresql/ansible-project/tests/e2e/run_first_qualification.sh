#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$(cd "$PROJECT_DIR/.." && pwd)/evidence"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

TARGET_IMAGE="${E2E_TARGET_IMAGE:-geerlingguy/docker-ubuntu2404-ansible:latest}"
NETWORK="${E2E_NETWORK:-dst-ansible-django-e2e}"
APP_CONTAINER="${E2E_APP_CONTAINER:-dst-django-app1}"
DB_CONTAINER="${E2E_DB_CONTAINER:-dst-django-db1}"
KEEP_TARGETS="${E2E_KEEP_TARGETS:-0}"
CHECK_IDEMPOTENCE="${E2E_CHECK_IDEMPOTENCE:-0}"

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

assert_zero_changes() {
  local host="$1"
  local logfile="$2"
  local line changed
  line="$(grep -E "^${host}[[:space:]]+:" "$logfile" | tail -n 1 || true)"
  [[ -n "$line" ]] || fail "idempotence recap missing for $host"
  changed="$(printf '%s\n' "$line" | sed -nE 's/.*changed=([0-9]+).*/\1/p')"
  [[ -n "$changed" ]] || fail "unable to parse changed count for $host"
  [[ "$changed" == "0" ]] || fail "$host is not idempotent: changed=$changed"
  echo "IDEMPOTENCE PASS: $host changed=0"
}

collect_diagnostics() {
  local output="$EVIDENCE_DIR/validation/diagnostics-$TIMESTAMP.txt"
  {
    echo "LOT 10/11 diagnostics"
    echo "timestamp=$TIMESTAMP"
    for container in "$APP_CONTAINER" "$DB_CONTAINER"; do
      echo "===== $container ====="
      docker inspect "$container" 2>/dev/null || true
      docker logs "$container" 2>/dev/null || true
      docker exec "$container" systemctl --failed --no-pager 2>/dev/null || true
      docker exec "$container" journalctl -n 200 --no-pager 2>/dev/null || true
    done
  } >"$output" 2>&1 || true
  echo "Diagnostics: $output"
}

cleanup() {
  rm -f "$INVENTORY" "$VAULT_FILE" "$VAULT_PASS_FILE"
  if [[ "$KEEP_TARGETS" != "1" ]]; then
    docker rm -f "$APP_CONTAINER" "$DB_CONTAINER" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
  else
    echo "E2E_KEEP_TARGETS=1: Docker targets preserved for investigation."
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

for container in "$APP_CONTAINER" "$DB_CONTAINER"; do
  if docker inspect "$container" >/dev/null 2>&1; then
    fail "Docker target already exists: $container"
  fi
done
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  fail "Docker network already exists: $NETWORK"
fi

echo "== LOT 10/11 / static gate =="
bash tests/static_checks.sh

echo "== LOT 10/11 / provision Ubuntu 24.04 systemd targets =="
docker pull "$TARGET_IMAGE"
docker network create "$NETWORK" >/dev/null

for container in "$APP_CONTAINER" "$DB_CONTAINER"; do
  docker run --detach \
    --name "$container" \
    --hostname "$container" \
    --network "$NETWORK" \
    --privileged \
    --volume=/sys/fs/cgroup:/sys/fs/cgroup:rw \
    --cgroupns=host \
    "$TARGET_IMAGE" >/dev/null
done

for container in "$APP_CONTAINER" "$DB_CONTAINER"; do
  ready=0
  for _ in $(seq 1 30); do
    if ! docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true; then
      fail "$container exited during startup"
    fi
    state="$(docker exec "$container" systemctl is-system-running 2>/dev/null || true)"
    if [[ "$state" == "running" || "$state" == "degraded" ]]; then
      ready=1
      break
    fi
    sleep 2
  done
  [[ "$ready" == "1" ]] || fail "$container did not reach a usable systemd state"
done

APP_IP="$(docker inspect -f "{{with index .NetworkSettings.Networks \"$NETWORK\"}}{{.IPAddress}}{{end}}" "$APP_CONTAINER")"
DB_IP="$(docker inspect -f "{{with index .NetworkSettings.Networks \"$NETWORK\"}}{{.IPAddress}}{{end}}" "$DB_CONTAINER")"
[[ -n "$APP_IP" ]] || fail "app1 Docker IP could not be resolved"
[[ -n "$DB_IP" ]] || fail "db1 Docker IP could not be resolved"
printf 'app1=%s\ndb1=%s\n' "$APP_IP" "$DB_IP" | tee "$EVIDENCE_DIR/validation/target-addresses-$TIMESTAMP.txt"

echo "== LOT 10/11 / ephemeral inventory and encrypted Vault =="
cat >"$INVENTORY" <<EOF
---
all:
  children:
    app:
      hosts:
        app1:
          ansible_connection: community.docker.docker
          ansible_host: $APP_CONTAINER
    database:
      hosts:
        db1:
          ansible_connection: community.docker.docker
          ansible_host: $DB_CONTAINER
          postgresql_app_cidr: $APP_IP/32
EOF

umask 077
DB_PASSWORD="$(openssl rand -hex 24)"
DJANGO_SECRET_KEY="$(openssl rand -hex 32)"
VAULT_PASSWORD="$(openssl rand -hex 24)"
cat >"$VAULT_FILE" <<EOF
---
vault_postgresql_password: "$DB_PASSWORD"
vault_django_secret_key: "$DJANGO_SECRET_KEY"
EOF
printf '%s\n' "$VAULT_PASSWORD" >"$VAULT_PASS_FILE"
ansible-vault encrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"
unset DB_PASSWORD DJANGO_SECRET_KEY VAULT_PASSWORD

echo "== LOT 10 / preflight =="
bash scripts/preflight.sh

echo "== LOT 10 / first deployment =="
bash scripts/deploy.sh

echo "== LOT 10 / runtime validation =="
bash scripts/validate_runtime.sh

echo "== LOT 10 / control-node HTTP validation =="
for endpoint in root health database info; do
  case "$endpoint" in
    root) path="/" ;;
    health) path="/health/" ;;
    database) path="/health/database/" ;;
    info) path="/api/info/" ;;
  esac
  curl --fail --show-error --silent --max-time 30 \
    -H 'Host: app1' \
    "http://$APP_IP$path" \
    >"$EVIDENCE_DIR/validation/http-$endpoint-$TIMESTAMP.json"
done

python3 - "$EVIDENCE_DIR/validation/http-health-$TIMESTAMP.json" "$EVIDENCE_DIR/validation/http-database-$TIMESTAMP.json" <<'PY'
import json
import sys
from pathlib import Path

health = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
database = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
assert health == {"status": "healthy"}, health
assert database.get("status") == "healthy", database
assert database.get("database") == "connected", database
assert int(database.get("query")) == 1, database
PY

{
  echo "app1 nginx=$(docker exec "$APP_CONTAINER" systemctl is-active nginx)"
  echo "app1 gunicorn=$(docker exec "$APP_CONTAINER" systemctl is-active datascientest-django)"
  echo "db1 postgresql=$(docker exec "$DB_CONTAINER" systemctl is-active postgresql)"
} | tee "$EVIDENCE_DIR/validation/service-status-$TIMESTAMP.txt"

echo "LOT 10 first E2E qualification passed."

if [[ "$CHECK_IDEMPOTENCE" == "1" ]]; then
  IDEMPOTENCE_LOG="$EVIDENCE_DIR/validation/idempotence-$TIMESTAMP.txt"
  echo "== LOT 11 / second deployment with strict idempotence gate =="
  set -o pipefail
  ansible-playbook -i "$INVENTORY" playbooks/site.yml \
    --vault-password-file "$VAULT_PASS_FILE" 2>&1 | tee "$IDEMPOTENCE_LOG"

  assert_zero_changes app1 "$IDEMPOTENCE_LOG"
  assert_zero_changes db1 "$IDEMPOTENCE_LOG"

  echo "== LOT 11 / runtime validation after second deployment =="
  bash scripts/validate_runtime.sh
  echo "LOT 11 strict idempotence qualification passed."
fi
