#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_PROJECT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="$(cd "$ANSIBLE_PROJECT/.." && pwd)"
INVENTORY="$ANSIBLE_PROJECT/inventories/stg/hosts.yml"
VAULT_FILE="$ANSIBLE_PROJECT/inventories/stg/group_vars/vault.yml"
DEPLOY_ROOT="/opt/datascientest-compose"
DEPLOY_DIR="$DEPLOY_ROOT/docker"
RUNTIME_ENV="$DEPLOY_DIR/.env.runtime"
TMP_DIR="$(mktemp -d)"
PASS1_LOG="$TMP_DIR/pass1.log"
PASS2_LOG="$TMP_DIR/pass2.log"
RUNTIME_BEFORE="$TMP_DIR/runtime-before.tsv"
RUNTIME_AFTER="$TMP_DIR/runtime-after.tsv"
VOLUMES_BEFORE="$TMP_DIR/volumes-before.tsv"
VOLUMES_AFTER="$TMP_DIR/volumes-after.tsv"
CHECKSUMS_BEFORE="$TMP_DIR/checksums-before.txt"
CHECKSUMS_AFTER="$TMP_DIR/checksums-after.txt"
PROJECT_NAME="datascientest"
APP_IMAGE=""

fail() {
  echo "DC14_IDEMPOTENCE_FAIL: $*" >&2
  exit 1
}

if [[ "${GITHUB_ACTIONS:-}" != "true" && "${DC14_ALLOW_EPHEMERAL_HOST:-}" != "1" ]]; then
  fail "this qualification mutates the Docker host; use an ephemeral runner or set DC14_ALLOW_EPHEMERAL_HOST=1 explicitly"
fi

if [[ -e "$INVENTORY" || -e "$VAULT_FILE" ]]; then
  fail "refusing to overwrite an existing runtime inventory or Vault file"
fi

cleanup() {
  rc=$?
  set +e
  if [[ -f "$RUNTIME_ENV" && -d "$DEPLOY_DIR" ]]; then
    (
      cd "$DEPLOY_DIR"
      docker compose \
        --project-name "$PROJECT_NAME" \
        --env-file .env.runtime \
        -f compose.yml \
        -f compose.stg.yml \
        down --volumes --remove-orphans --timeout 10 >/dev/null 2>&1
    ) || true
  fi
  sudo rm -rf "$DEPLOY_ROOT" >/dev/null 2>&1 || true
  rm -f "$INVENTORY" "$VAULT_FILE"
  rm -rf "$TMP_DIR"
  if (( rc != 0 )); then
    echo "DC14_STRICT_IDEMPOTENCE_FAIL" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

POSTGRES_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(24))
PY
)"
REDIS_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(24))
PY
)"
DJANGO_SECRET_KEY="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(64))
PY
)"

umask 077
cat > "$INVENTORY" <<'EOF'
---
all:
  children:
    app:
      hosts:
        localhost:
          ansible_connection: local
EOF

cat > "$VAULT_FILE" <<EOF
---
vault_environment: stg
vault_secret_generation: 1
vault_django_secret_key: "$DJANGO_SECRET_KEY"
vault_postgresql_password: "$POSTGRES_PASSWORD"
vault_redis_password: "$REDIS_PASSWORD"
EOF
chmod 0600 "$INVENTORY" "$VAULT_FILE"

cd "$ANSIBLE_PROJECT"
export ANSIBLE_FORCE_COLOR=0
export ANSIBLE_NOCOWS=1

echo "== DC-14 host preparation =="
sudo systemctl stop nginx.service 2>/dev/null || true
sudo systemctl stop postgresql.service 2>/dev/null || true
sudo systemctl stop redis-server.service 2>/dev/null || true

ansible-playbook \
  -i "$INVENTORY" \
  playbooks/site.yml \
  --tags common,docker_engine,runtime_hardening \
  -e deployment_environment=stg

docker info >/dev/null
docker compose version

echo "== DC-14 preload immutable dependencies outside Compose =="
docker pull postgres:16-alpine >/dev/null
docker pull redis:7.4-alpine >/dev/null
docker pull nginx:1.27-alpine >/dev/null

chmod +x tests/e2e/prepare_stg_immutable_image.sh
APP_IMAGE="$(./tests/e2e/prepare_stg_immutable_image.sh)"
if ! [[ "$APP_IMAGE" =~ @sha256:[0-9a-f]{64}$ ]]; then
  fail "immutable application image helper did not return repository@sha256"
fi
if ! docker image inspect "$APP_IMAGE" >/dev/null 2>&1; then
  fail "digest-pinned application image is not locally resolvable"
fi
APP_IMAGE_METADATA_BEFORE="$(docker image inspect "$APP_IMAGE" --format '{{.Id}}|{{.Created}}')"
echo "DC14_ARTIFACT_PASS: one prebuilt digest-pinned application image prepared before the idempotence pair"

run_site() {
  local log_file="$1"
  ansible-playbook \
    -i "$INVENTORY" \
    playbooks/site.yml \
    -e deployment_environment=stg \
    -e "app_image=$APP_IMAGE" \
    -e application_version=0.14.0-idempotence \
    -e "application_commit=${GITHUB_SHA:-local}" \
    | tee "$log_file"
}

recap_changed() {
  local log_file="$1"
  local recap
  recap="$(grep -E '^localhost[[:space:]]+:' "$log_file" | tail -n 1)"
  [[ -n "$recap" ]] || fail "Ansible recap for localhost is missing"
  if [[ "$recap" =~ changed=([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    fail "cannot parse changed count from Ansible recap"
  fi
}

recap_failed() {
  local log_file="$1"
  local recap
  recap="$(grep -E '^localhost[[:space:]]+:' "$log_file" | tail -n 1)"
  if [[ "$recap" =~ failed=([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    fail "cannot parse failed count from Ansible recap"
  fi
}

compose() {
  (
    cd "$DEPLOY_DIR"
    docker compose \
      --project-name "$PROJECT_NAME" \
      --env-file .env.runtime \
      -f compose.yml \
      -f compose.stg.yml \
      "$@"
  )
}

snapshot_runtime() {
  local output="$1"
  : > "$output"
  for service in nginx web db redis worker beat; do
    local cid image_id configured_image health
    cid="$(compose ps -q "$service")"
    [[ -n "$cid" ]] || fail "service $service has no runtime container"
    image_id="$(docker inspect --format '{{.Image}}' "$cid")"
    configured_image="$(docker inspect --format '{{.Config.Image}}' "$cid")"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")"
    [[ "$health" == "healthy" ]] || fail "service $service is not healthy ($health)"
    printf '%s\t%s\t%s\t%s\n' "$service" "$cid" "$image_id" "$configured_image" >> "$output"
  done
}

snapshot_volumes() {
  local output="$1"
  : > "$output"
  for service in db redis web; do
    local cid
    cid="$(compose ps -q "$service")"
    docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' "$cid" \
      | sed '/^$/d' \
      | sort \
      | while IFS= read -r volume; do
          printf '%s\t%s\n' "$service" "$volume"
        done >> "$output"
  done
}

snapshot_checksums() {
  local output="$1"
  (
    cd "$DEPLOY_DIR"
    sha256sum \
      compose.yml \
      compose.stg.yml \
      nginx/default.conf \
      redis/entrypoint.sh \
      .env.runtime
  ) > "$output"
}

echo "== DC-14 convergence pass 1 =="
run_site "$PASS1_LOG"
[[ "$(recap_failed "$PASS1_LOG")" == "0" ]] || fail "first convergence failed"
PASS1_CHANGED="$(recap_changed "$PASS1_LOG")"
if (( PASS1_CHANGED < 1 )); then
  fail "first convergence was expected to materialize state"
fi
echo "DC14_PASS1_PASS: first convergence changed=$PASS1_CHANGED"

[[ -f "$RUNTIME_ENV" ]] || fail "runtime environment was not deployed"
snapshot_runtime "$RUNTIME_BEFORE"
snapshot_volumes "$VOLUMES_BEFORE"
snapshot_checksums "$CHECKSUMS_BEFORE"

echo "== DC-14 seed durable probes =="
compose exec -T db sh -ec '
  PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 \
    -c "CREATE TABLE IF NOT EXISTS dc14_idempotence_probe (id integer PRIMARY KEY, marker text NOT NULL);" \
    -c "INSERT INTO dc14_idempotence_probe (id, marker) VALUES (1, '\''preserved'\'') ON CONFLICT (id) DO UPDATE SET marker = EXCLUDED.marker;" \
    >/dev/null
'
compose exec -T redis sh -ec '
  export REDISCLI_AUTH="$REDIS_PASSWORD"
  redis-cli -h 127.0.0.1 -p 6379 SET dc14:idempotence preserved >/dev/null
  redis-cli -h 127.0.0.1 -p 6379 SAVE >/dev/null
'
compose exec -T web python -c "from pathlib import Path; Path('/app/staticfiles/.dc14-idempotence').write_text('preserved', encoding='utf-8')"
echo "DC14_DATA_SEED_PASS: PostgreSQL, Redis and static-volume probes written"

echo "== DC-14 convergence pass 2 =="
run_site "$PASS2_LOG"
[[ "$(recap_failed "$PASS2_LOG")" == "0" ]] || fail "second convergence failed"
PASS2_CHANGED="$(recap_changed "$PASS2_LOG")"
if [[ "$PASS2_CHANGED" != "0" ]]; then
  echo "--- changed task diagnostics ---" >&2
  grep -B1 -A1 -E '^changed: \[localhost\]' "$PASS2_LOG" >&2 || true
  fail "second convergence is not strict-idempotent: changed=$PASS2_CHANGED"
fi
echo "DC14_ANSIBLE_PASS: second full site convergence changed=0"

snapshot_runtime "$RUNTIME_AFTER"
snapshot_volumes "$VOLUMES_AFTER"
snapshot_checksums "$CHECKSUMS_AFTER"

cmp -s "$RUNTIME_BEFORE" "$RUNTIME_AFTER" \
  || fail "one or more long-running service containers were recreated or changed image"
echo "DC14_CONTAINER_PASS: six long-running service container IDs and image IDs are unchanged"

cmp -s "$VOLUMES_BEFORE" "$VOLUMES_AFTER" \
  || fail "named volume attachments changed across convergence"
echo "DC14_VOLUME_PASS: PostgreSQL, Redis and static named-volume attachments are unchanged"

cmp -s "$CHECKSUMS_BEFORE" "$CHECKSUMS_AFTER" \
  || fail "deployed Compose/runtime configuration checksums changed on pass 2"
echo "DC14_CONFIG_PASS: Compose files, service configs and .env.runtime checksums are unchanged"

APP_IMAGE_METADATA_AFTER="$(docker image inspect "$APP_IMAGE" --format '{{.Id}}|{{.Created}}')"
[[ "$APP_IMAGE_METADATA_AFTER" == "$APP_IMAGE_METADATA_BEFORE" ]] \
  || fail "application image identity or creation metadata changed"
echo "DC14_ARTIFACT_PASS: application image identity/creation metadata unchanged; no rebuild occurred in the idempotence pair"

POSTGRES_MARKER="$(compose exec -T db sh -ec 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT marker FROM dc14_idempotence_probe WHERE id = 1"')"
[[ "$POSTGRES_MARKER" == "preserved" ]] || fail "PostgreSQL durable probe was not preserved"

REDIS_MARKER="$(compose exec -T redis sh -ec 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h 127.0.0.1 -p 6379 GET dc14:idempotence')"
[[ "$REDIS_MARKER" == "preserved" ]] || fail "Redis durable probe was not preserved"

STATIC_MARKER="$(compose exec -T web python -c "from pathlib import Path; print(Path('/app/staticfiles/.dc14-idempotence').read_text(encoding='utf-8'))")"
[[ "$STATIC_MARKER" == "preserved" ]] || fail "static-volume durable probe was not preserved"
echo "DC14_DATA_PASS: PostgreSQL, Redis and static-volume data survived pass 2"

python3 tests/e2e/validate_stg_like_e2e.py \
  --base-url http://127.0.0.1 \
  --public-port 80 >/dev/null
echo "DC14_FUNCTIONAL_PASS: post-idempotence STG health, Celery round-trips and host-port contract remain valid"

echo "DC14_COMPOSE_EQUIVALENCE: runtime containers are stable; release/admin docker compose run --rm processes remain intentionally ephemeral but report changed=false when they make no state change"
echo "DC14_STRICT_IDEMPOTENCE_PASS"
