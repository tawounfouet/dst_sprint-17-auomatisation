#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"
TMP_DIR="$(mktemp -d)"
ENV_FILE="$TMP_DIR/stg-like.env"
RENDERED_JSON="$TMP_DIR/stg-compose.json"
PROJECT_NAME="datascientest-dc13-${GITHUB_RUN_ID:-local}-${RANDOM}"
HTTP_PORT="8081"

: "${APP_IMAGE:?APP_IMAGE must be provided as an already-built immutable digest reference}"
if ! [[ "$APP_IMAGE" =~ @sha256:[0-9a-f]{64}$ ]]; then
  echo "DC13_ARTIFACT_FAIL: APP_IMAGE must be digest-pinned" >&2
  exit 1
fi
if ! docker image inspect "$APP_IMAGE" >/dev/null 2>&1; then
  echo "DC13_ARTIFACT_FAIL: APP_IMAGE is not locally available before STG-like deployment" >&2
  exit 1
fi
ARTIFACT_IMAGE_ID="$(docker image inspect "$APP_IMAGE" --format '{{.Id}}')"

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

COMPOSE=(
  docker compose
  --project-name "$PROJECT_NAME"
  --env-file "$ENV_FILE"
  -f "$DOCKER_DIR/compose.yml"
  -f "$DOCKER_DIR/compose.stg.yml"
)

redact_stream() {
  sed \
    -e "s/${POSTGRES_PASSWORD}/[REDACTED_POSTGRES]/g" \
    -e "s/${REDIS_PASSWORD}/[REDACTED_REDIS]/g" \
    -e "s/${DJANGO_SECRET_KEY}/[REDACTED_DJANGO]/g"
}

diagnostics() {
  echo "== DC-13 diagnostics ==" >&2
  "${COMPOSE[@]}" ps 2>&1 | redact_stream >&2 || true
  for service in nginx web db redis worker beat; do
    echo "--- logs: $service ---" >&2
    "${COMPOSE[@]}" logs --no-color --tail=160 "$service" 2>&1 | redact_stream >&2 || true
  done
}

cleanup() {
  rc=$?
  set +e
  if (( rc != 0 )); then
    diagnostics
  fi
  "${COMPOSE[@]}" down --volumes --remove-orphans --timeout 10 >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
  if (( rc != 0 )); then
    echo "DC13_E2E_FAIL" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

wait_healthy() {
  local service="$1"
  local timeout_seconds="${2:-180}"
  local deadline=$((SECONDS + timeout_seconds))
  local cid status

  while (( SECONDS < deadline )); do
    cid="$("${COMPOSE[@]}" ps -q "$service" 2>/dev/null || true)"
    if [[ -n "$cid" ]]; then
      status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
      case "$status" in
        healthy)
          echo "DC13_HEALTH_PASS: $service"
          return 0
          ;;
        unhealthy|exited|dead)
          echo "DC13_HEALTH_FAIL: $service status=$status" >&2
          return 1
          ;;
      esac
    fi
    sleep 2
  done

  echo "DC13_HEALTH_FAIL: $service timeout=${timeout_seconds}s" >&2
  return 1
}

assert_no_published_port() {
  local service="$1"
  local port="$2"
  local cid bindings
  cid="$("${COMPOSE[@]}" ps -q "$service")"
  [[ -n "$cid" ]]
  bindings="$(docker inspect --format '{{json .HostConfig.PortBindings}}' "$cid")"
  python3 - "$service" "$port" "$bindings" <<'PY'
import json
import sys

service = sys.argv[1]
port = sys.argv[2]
bindings = json.loads(sys.argv[3]) or {}
key = f"{port}/tcp"
if bindings.get(key):
    raise SystemExit(
        f"DC13_NETWORK_FAIL: {service}:{port} has Docker host bindings"
    )
PY
  echo "DC13_NETWORK_PASS: $service:$port published=false"
}

expect_stg_policy_failure() {
  local label="$1"
  local expected_message="$2"
  shift 2
  local output_file="$TMP_DIR/policy-${label//[^a-zA-Z0-9]/_}.log"
  local rc

  set +e
  docker run --rm --network none --entrypoint python \
    -e APPLICATION_ENV=stg \
    -e DJANGO_SETTINGS_MODULE=config.settings.stg \
    -e DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY" \
    -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
    -e CELERY_BROKER_URL=redis://127.0.0.1:6379/0 \
    -e CELERY_RESULT_BACKEND=redis://127.0.0.1:6379/1 \
    "$@" \
    "$APP_IMAGE" \
    -c 'import django; django.setup()' \
    >"$output_file" 2>&1
  rc=$?
  set -e

  if (( rc == 0 )); then
    echo "DC13_POLICY_FAIL: $label unexpectedly succeeded" >&2
    return 1
  fi
  if ! grep -Fq "$expected_message" "$output_file"; then
    echo "DC13_POLICY_FAIL: $label failed for an unexpected reason" >&2
    return 1
  fi
  echo "DC13_POLICY_PASS: $label rejected"
}

cat > "$ENV_FILE" <<EOF
APP_IMAGE=$APP_IMAGE
APPLICATION_ENV=stg
APPLICATION_VERSION=0.13.0-stg-e2e
APPLICATION_COMMIT=${GITHUB_SHA:-local}
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=false
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,web,nginx
DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:${HTTP_PORT}
DATABASE_URL=postgresql://django_app:$POSTGRES_PASSWORD@db:5432/django_app
CELERY_BROKER_URL=redis://:$REDIS_PASSWORD@redis:6379/0
CELERY_RESULT_BACKEND=redis://:$REDIS_PASSWORD@redis:6379/1
CELERY_RESULT_EXPIRES=3600
CELERY_BEAT_MAX_LOOP_INTERVAL=2
CELERY_BEAT_SYNC_EVERY=1
CELERY_LOG_LEVEL=INFO
CELERY_BEAT_LOG_LEVEL=INFO
CELERY_CONCURRENCY=2
POSTGRES_DB=django_app
POSTGRES_USER=django_app
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
NGINX_HTTP_PORT=$HTTP_PORT
WEB_CONCURRENCY=2
DOCKER_LOG_MAX_SIZE=10m
DOCKER_LOG_MAX_FILE=3
EOF
chmod 0600 "$ENV_FILE"

cd "$PROJECT_ROOT"

echo "== DC-13 preflight =="
docker info >/dev/null
docker compose version
python3 --version
echo "DC13_ARTIFACT_PASS: digest-pinned APP_IMAGE existed before Compose deployment"

echo "== STG runtime negative policy tests =="
expect_stg_policy_failure \
  "missing DATABASE_URL" \
  "DATABASE_URL is mandatory in staging." \
  -e DJANGO_DEBUG=false
expect_stg_policy_failure \
  "SQLite DATABASE_URL" \
  "DATABASE_URL must use PostgreSQL" \
  -e DJANGO_DEBUG=false \
  -e DATABASE_URL=sqlite:////tmp/forbidden.sqlite3
expect_stg_policy_failure \
  "invalid DATABASE_URL scheme" \
  "DATABASE_URL must use PostgreSQL" \
  -e DJANGO_DEBUG=false \
  -e DATABASE_URL=mysql://user:password@db:3306/app
expect_stg_policy_failure \
  "DJANGO_DEBUG=true" \
  "DJANGO_DEBUG=true is forbidden in staging." \
  -e DJANGO_DEBUG=true \
  -e DATABASE_URL=postgresql://user:password@db:5432/app

echo "== Render STG Compose contract without build =="
"${COMPOSE[@]}" config --format json > "$RENDERED_JSON"
python3 - "$RENDERED_JSON" "$APP_IMAGE" "$HTTP_PORT" <<'PY'
import json
import sys

path, expected_image, public_port = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    config = json.load(handle)
services = config.get("services", {})
expected_services = {"nginx", "web", "db", "redis", "worker", "beat"}
if "minio" in services:
    expected_services.update({"minio", "minio-create-bucket"})
if set(services) != expected_services:
    raise SystemExit("DC13_COMPOSE_FAIL: service set mismatch")
for name in ("web", "worker", "beat"):
    service = services[name]
    if service.get("build"):
        raise SystemExit(f"DC13_COMPOSE_FAIL: {name} contains a build definition")
    if service.get("image") != expected_image:
        raise SystemExit(f"DC13_COMPOSE_FAIL: {name} does not use APP_IMAGE digest")
    environment = service.get("environment", {})
    if environment.get("APPLICATION_ENV") != "stg":
        raise SystemExit(f"DC13_COMPOSE_FAIL: {name} APPLICATION_ENV is not stg")
    if environment.get("DJANGO_SETTINGS_MODULE") != "config.settings.stg":
        raise SystemExit(f"DC13_COMPOSE_FAIL: {name} settings module is not stg")
    if str(environment.get("DJANGO_DEBUG", "")).lower() != "false":
        raise SystemExit(f"DC13_COMPOSE_FAIL: {name} DJANGO_DEBUG is not false")
ports = services["nginx"].get("ports") or []
if not any(str(item.get("published")) == public_port for item in ports if isinstance(item, dict)):
    raise SystemExit("DC13_COMPOSE_FAIL: Nginx public host port mismatch")
PY
echo "DC13_COMPOSE_PASS: STG uses six services, zero Compose builds and one digest-pinned app image"

echo "== Start real PostgreSQL and Redis without pull/build =="
"${COMPOSE[@]}" up -d --no-build --pull never db redis
wait_healthy db 180
wait_healthy redis 120

postgres_probe="$("${COMPOSE[@]}" exec -T db sh -ec 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT 1"')"
[[ "$postgres_probe" == "1" ]]
echo "DC13_POSTGRES_PASS: SELECT 1"

redis_probe="$("${COMPOSE[@]}" exec -T redis sh -ec 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h 127.0.0.1 -p 6379 ping')"
[[ "$redis_probe" == "PONG" ]]
echo "DC13_REDIS_PASS: authenticated PING"

echo "== Positive STG settings snapshot =="
policy_snapshot="$(
  "${COMPOSE[@]}" run --rm --no-deps --pull never web \
    python -c 'import os, django; django.setup(); from django.conf import settings; print("|".join([os.environ.get("APPLICATION_ENV", ""), os.environ.get("DJANGO_SETTINGS_MODULE", ""), str(settings.DEBUG).lower(), settings.DATABASES["default"]["ENGINE"]]))' \
  | tail -n 1 | tr -d '\r'
)"
if [[ "$policy_snapshot" != "stg|config.settings.stg|false|django.db.backends.postgresql" ]]; then
  echo "DC13_POLICY_FAIL: positive STG settings snapshot mismatch" >&2
  exit 1
fi
echo "DC13_POLICY_PASS: stg + config.settings.stg + DEBUG=false + PostgreSQL backend"

echo "== Release phase with immutable image =="
"${COMPOSE[@]}" run --rm --no-deps --pull never web python manage.py migrate --noinput
"${COMPOSE[@]}" run --rm --no-deps --pull never web python manage.py collectstatic --noinput --verbosity 0
beat_schedule_result="$("${COMPOSE[@]}" run --rm --no-deps --pull never web python manage.py ensure_demo_periodic_task --seconds 5 | tail -n 1 | tr -d '\r')"
case "$beat_schedule_result" in
  created|updated|unchanged) ;;
  *)
    echo "DC13_BEAT_FAIL: unexpected schedule command output" >&2
    exit 1
    ;;
esac
echo "DC13_RELEASE_PASS: migrate + collectstatic + periodic schedule"

echo "== Start six-service STG-like runtime with --no-build --pull never =="
"${COMPOSE[@]}" up -d --no-build --pull never web worker beat nginx
for service in db redis web worker beat nginx; do
  wait_healthy "$service" 240
done

service_count="$("${COMPOSE[@]}" ps -q | sed '/^$/d' | wc -l | tr -d ' ')"
[[ "$service_count" == "6" ]]
echo "DC13_SERVICES_PASS: six containers running"

echo "== Immutable application image contract =="
for service in web worker beat; do
  cid="$("${COMPOSE[@]}" ps -q "$service")"
  image_id="$(docker inspect --format '{{.Image}}' "$cid")"
  configured_image="$(docker inspect --format '{{.Config.Image}}' "$cid")"
  if [[ "$image_id" != "$ARTIFACT_IMAGE_ID" || "$configured_image" != "$APP_IMAGE" ]]; then
    echo "DC13_ARTIFACT_FAIL: $service is not running the prepared digest-pinned image" >&2
    exit 1
  fi
done
echo "DC13_ARTIFACT_PASS: web/worker/beat run the exact prebuilt digest-pinned image"

echo "== HTTP, Celery and host-port validation =="
python3 "$SCRIPT_DIR/validate_stg_like_e2e.py" \
  --base-url "http://127.0.0.1:${HTTP_PORT}" \
  --public-port "$HTTP_PORT"

assert_no_published_port web 8000
assert_no_published_port db 5432
assert_no_published_port redis 6379

echo "== Beat periodic execution proof =="
beat_deadline=$((SECONDS + 90))
beat_count=0
beat_log_proof=false
while (( SECONDS < beat_deadline )); do
  beat_count="$("${COMPOSE[@]}" exec -T web python manage.py shell -c "from django_celery_beat.models import PeriodicTask; print(int(PeriodicTask.objects.get(name='datascientest-demo-heartbeat').total_run_count))" 2>/dev/null | tail -n 1 | tr -d '\r' || true)"
  if ! [[ "$beat_count" =~ ^[0-9]+$ ]]; then
    beat_count=0
  fi
  if "${COMPOSE[@]}" logs --no-color worker 2>&1 | grep -E 'tasks_demo\.periodic_heartbeat.*succeeded' >/dev/null; then
    beat_log_proof=true
  fi
  if (( beat_count >= 1 )) && [[ "$beat_log_proof" == "true" ]]; then
    break
  fi
  sleep 2
done

if (( beat_count < 1 )) || [[ "$beat_log_proof" != "true" ]]; then
  echo "DC13_BEAT_FAIL: periodic heartbeat was not both scheduled and consumed" >&2
  exit 1
fi
echo "DC13_BEAT_PASS: total_run_count>=1 and worker logged successful heartbeat"

echo "== Final six-service health snapshot =="
for service in db redis web worker beat nginx; do
  wait_healthy "$service" 30
done

"${COMPOSE[@]}" ps

echo "DC13_PARITY_PASS: STG-like preserves DC-12 functional task/health/Beat behavior with stricter runtime policy"
echo "DC13_STG_LIKE_E2E_PASS"
