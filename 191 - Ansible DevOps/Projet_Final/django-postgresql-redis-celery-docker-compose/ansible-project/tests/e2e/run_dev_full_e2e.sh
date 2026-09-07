#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"
TMP_DIR="$(mktemp -d)"
ENV_FILE="$TMP_DIR/dev-full.env"
PROJECT_NAME="datascientest-dc12-${GITHUB_RUN_ID:-local}-${RANDOM}"
APP_IMAGE="datascientest-django:dc12-${GITHUB_SHA:-local}"
HTTP_PORT="8080"

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
  -f "$DOCKER_DIR/compose.dev.yml"
)

redact_stream() {
  sed \
    -e "s/${POSTGRES_PASSWORD}/[REDACTED_POSTGRES]/g" \
    -e "s/${REDIS_PASSWORD}/[REDACTED_REDIS]/g" \
    -e "s/${DJANGO_SECRET_KEY}/[REDACTED_DJANGO]/g"
}

diagnostics() {
  echo "== DC-12 diagnostics ==" >&2
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
    echo "DC12_E2E_FAIL" >&2
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
          echo "DC12_HEALTH_PASS: $service"
          return 0
          ;;
        unhealthy|exited|dead)
          echo "DC12_HEALTH_FAIL: $service status=$status" >&2
          return 1
          ;;
      esac
    fi
    sleep 2
  done

  echo "DC12_HEALTH_FAIL: $service timeout=${timeout_seconds}s" >&2
  return 1
}

assert_no_published_port() {
  local service="$1"
  local port="$2"
  local mapping
  mapping="$("${COMPOSE[@]}" port "$service" "$port" 2>/dev/null || true)"
  if [[ -n "$mapping" ]]; then
    echo "DC12_NETWORK_FAIL: $service:$port unexpectedly published as $mapping" >&2
    return 1
  fi
  echo "DC12_NETWORK_PASS: $service:$port published=false"
}

cat > "$ENV_FILE" <<EOF
APP_IMAGE=$APP_IMAGE
APPLICATION_ENV=dev
APPLICATION_VERSION=0.12.0-dev-e2e
APPLICATION_COMMIT=${GITHUB_SHA:-local}
DJANGO_SETTINGS_MODULE=config.settings.dev
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=false
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,web,nginx
DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8080
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

echo "== DC-12 preflight =="
docker info >/dev/null
docker compose version
python3 --version

echo "== Build application image once =="
"${COMPOSE[@]}" build web
built_image_id="$(docker image inspect "$APP_IMAGE" --format '{{.Id}}')"
[[ -n "$built_image_id" ]]
echo "DC12_BUILD_PASS: application image built once"

echo "== Start real PostgreSQL and Redis =="
"${COMPOSE[@]}" up -d db redis
wait_healthy db 180
wait_healthy redis 120

echo "== PostgreSQL real SELECT 1 =="
postgres_probe="$("${COMPOSE[@]}" exec -T db sh -ec 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT 1"')"
[[ "$postgres_probe" == "1" ]]
echo "DC12_POSTGRES_PASS: SELECT 1"

echo "== Redis authenticated PING =="
redis_probe="$("${COMPOSE[@]}" exec -T redis sh -ec 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h 127.0.0.1 -p 6379 ping')"
[[ "$redis_probe" == "PONG" ]]
echo "DC12_REDIS_PASS: authenticated PING"

echo "== Release phase: migrations, static files, Beat schedule =="
"${COMPOSE[@]}" run --rm --no-deps web python manage.py migrate --noinput
"${COMPOSE[@]}" run --rm --no-deps web python manage.py collectstatic --noinput --verbosity 0
beat_schedule_result="$("${COMPOSE[@]}" run --rm --no-deps web python manage.py ensure_demo_periodic_task --seconds 5 | tail -n 1 | tr -d '\r')"
case "$beat_schedule_result" in
  created|updated|unchanged) ;;
  *)
    echo "DC12_BEAT_FAIL: unexpected schedule command output" >&2
    exit 1
    ;;
esac
echo "DC12_RELEASE_PASS: migrate + collectstatic + periodic schedule"

echo "== Start web, worker, beat and nginx without rebuilding =="
"${COMPOSE[@]}" up -d --no-build web worker beat nginx
for service in db redis web worker beat nginx; do
  wait_healthy "$service" 240
done

service_count="$("${COMPOSE[@]}" ps -q | sed '/^$/d' | wc -l | tr -d ' ')"
[[ "$service_count" == "6" ]]
echo "DC12_SERVICES_PASS: six containers running"

echo "== Shared application image contract =="
web_image="$(docker inspect --format '{{.Image}}' "$("${COMPOSE[@]}" ps -q web)")"
worker_image="$(docker inspect --format '{{.Image}}' "$("${COMPOSE[@]}" ps -q worker)")"
beat_image="$(docker inspect --format '{{.Image}}' "$("${COMPOSE[@]}" ps -q beat)")"
[[ "$web_image" == "$worker_image" && "$worker_image" == "$beat_image" ]]
[[ "$web_image" == "$built_image_id" ]]
echo "DC12_IMAGE_PASS: web/worker/beat share the one built image"

echo "== HTTP, async task and host-port validation =="
python3 "$SCRIPT_DIR/validate_dev_full_e2e.py" --base-url "http://127.0.0.1:${HTTP_PORT}" --public-port "$HTTP_PORT"

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
  echo "DC12_BEAT_FAIL: periodic heartbeat was not both scheduled and consumed" >&2
  exit 1
fi
echo "DC12_BEAT_PASS: total_run_count>=1 and worker logged successful heartbeat"

echo "== Final six-service health snapshot =="
for service in db redis web worker beat nginx; do
  wait_healthy "$service" 30
done

"${COMPOSE[@]}" ps

echo "DC12_DEV_FULL_E2E_PASS"
