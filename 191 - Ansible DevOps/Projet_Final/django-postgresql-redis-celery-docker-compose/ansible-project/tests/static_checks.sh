#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
DJANGO_DIR="$ROOT_DIR/django-app"
DOCKER_DIR="$ROOT_DIR/docker"
TMP_DIR="$(mktemp -d)"
CREATED_VAULTS=()

cleanup() {
  for vault in "${CREATED_VAULTS[@]:-}"; do
    [[ -n "$vault" ]] && rm -f "$vault"
  done
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  echo "STATIC_GATE_FAIL: $*" >&2
  exit 1
}

pass() {
  echo "STATIC_GATE_PASS: $*"
}

require_file() {
  [[ -f "$1" ]] || fail "required file missing: $1"
}

require_dir() {
  [[ -d "$1" ]] || fail "required directory missing: $1"
}

cd "$PROJECT_DIR"

echo "== DC-11 structure =="
for file in \
  ansible.cfg \
  requirements.yml \
  playbooks/site.yml \
  playbooks/docker_engine.yml \
  playbooks/runtime_hardening.yml \
  roles/docker_engine/tasks/main.yml \
  roles/docker_runtime_hardening/tasks/main.yml \
  roles/docker_runtime_hardening/templates/daemon.json.j2 \
  roles/docker_runtime_hardening/templates/docker-user-firewall.sh.j2 \
  roles/compose_stack/tasks/main.yml \
  scripts/secret_hygiene.py \
  tests/validate_compose_config.py \
  "$DJANGO_DIR/Dockerfile" \
  "$DJANGO_DIR/requirements.txt" \
  "$DJANGO_DIR/config/settings/base.py" \
  "$DJANGO_DIR/config/settings/database.py" \
  "$DJANGO_DIR/config/settings/dev.py" \
  "$DJANGO_DIR/config/settings/stg.py" \
  "$DJANGO_DIR/config/settings/prod.py" \
  "$DJANGO_DIR/tests/test_settings_database_policy.py" \
  "$DJANGO_DIR/tests/test_settings_runtime_policy.py" \
  "$DJANGO_DIR/tasks_demo/tests/test_api.py" \
  "$DOCKER_DIR/compose.yml" \
  "$DOCKER_DIR/compose.dev.yml" \
  "$DOCKER_DIR/compose.stg.yml" \
  "$DOCKER_DIR/compose.prod.yml" \
  "$DOCKER_DIR/nginx/default.conf" \
  "$DOCKER_DIR/redis/entrypoint.sh"; do
  require_file "$file"
done

for role in common docker_engine docker_runtime_hardening compose_stack; do
  require_dir "roles/$role"
  require_file "roles/$role/tasks/main.yml"
  require_file "roles/$role/defaults/main.yml"
  require_file "roles/$role/meta/main.yml"
done

for env_name in dev stg prod; do
  require_file "inventories/$env_name/hosts.example.yml"
  require_file "inventories/$env_name/group_vars/all.yml"
  require_file "inventories/$env_name/group_vars/vault.example.yml"
done
pass "project structure"

echo "== Python dependency contract =="
for dependency in \
  'Django>=5.2,<5.3' \
  'djangorestframework>=3.16,<4' \
  'django-environ>=0.12,<1' \
  'gunicorn>=23,<24' \
  'psycopg[binary]>=3.2,<4' \
  'celery>=5.5,<6' \
  'redis>=6,<7' \
  'django-celery-beat>=2.9,<3'; do
  grep -Fq "$dependency" "$DJANGO_DIR/requirements.txt" \
    || fail "Python dependency contract missing: $dependency"
done
pass "Django/DRF/Celery dependency bounds"

echo "== Bash syntax =="
while IFS= read -r -d '' script; do
  bash -n "$script" || fail "invalid Bash syntax: $script"
done < <(find scripts tests "$DOCKER_DIR" -type f -name '*.sh' -print0)
pass "Bash syntax"

echo "== Python syntax =="
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import ast
import sys

root = Path(sys.argv[1])
for path in sorted(root.rglob("*.py")):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
pass "Python AST parse"

echo "== YAML syntax =="
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])
for path in sorted(list(root.rglob("*.yml")) + list(root.rglob("*.yaml"))):
    if path.name == "vault.yml":
        continue
    with path.open(encoding="utf-8") as handle:
        yaml.safe_load(handle)
PY
pass "YAML parse"

echo "== Secret hygiene =="
python3 scripts/secret_hygiene.py repo
pass "repository secret hygiene"

echo "== Source invariants =="
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import ast
import sys
import yaml

root = Path(sys.argv[1])
django = root / "django-app"
docker = root / "docker"
ansible = root / "ansible-project"

def require(condition, message):
    if not condition:
        raise SystemExit(f"STATIC_GATE_FAIL: {message}")

requirements = (django / "requirements.txt").read_text(encoding="utf-8")
require("djangorestframework" in requirements, "DRF dependency missing")
require("django-environ" in requirements, "django-environ dependency missing")

base = (django / "config/settings/base.py").read_text(encoding="utf-8")
database = (django / "config/settings/database.py").read_text(encoding="utf-8")
stg = (django / "config/settings/stg.py").read_text(encoding="utf-8")
prod = (django / "config/settings/prod.py").read_text(encoding="utf-8")
require('"rest_framework"' in base, "rest_framework missing from INSTALLED_APPS")
require('"django_celery_beat"' in base, "django_celery_beat missing from INSTALLED_APPS")
require("DATABASE_URL must use PostgreSQL" in database, "PostgreSQL-only policy missing")
require("django.db.backends.sqlite3" in database, "DEV SQLite fallback missing")
require("required_postgresql_database" in stg and "required_postgresql_database" in prod, "STG/PROD PostgreSQL enforcement missing")
require("DJANGO_DEBUG=true is forbidden" in stg and "DJANGO_DEBUG=true is forbidden" in prod, "STG/PROD DEBUG fail-fast missing")
database_tree = ast.parse(database, filename="config/settings/database.py")
require(
    not any(isinstance(node, (ast.Try, ast.TryStar)) for node in ast.walk(database_tree)),
    "database policy must not use exception-driven PostgreSQL-to-SQLite fallback",
)

api_views = (django / "tasks_demo/views.py").read_text(encoding="utf-8")
serializers = (django / "tasks_demo/serializers.py").read_text(encoding="utf-8")
require("@api_view" in api_views and "Response" in api_views, "task API must use DRF views")
require("serializers.Serializer" in serializers, "DRF serializers missing")

Dockerfile = (django / "Dockerfile").read_text(encoding="utf-8")
require(Dockerfile.count("FROM ") >= 2, "Dockerfile must remain multi-stage")
require("USER app" in Dockerfile, "Docker runtime must be non-root")
require("STOPSIGNAL SIGTERM" in Dockerfile, "Dockerfile SIGTERM contract missing")
require("ENTRYPOINT" in Dockerfile, "Docker entrypoint contract missing")
require("DJANGO_SECRET_KEY=" not in Dockerfile and "POSTGRES_PASSWORD=" not in Dockerfile and "REDIS_PASSWORD=" not in Dockerfile, "Dockerfile must not embed secrets")

compose_raw = yaml.safe_load((docker / "compose.yml").read_text(encoding="utf-8"))
services = compose_raw.get("services", {})
require(set(services) == {"nginx", "web", "db", "redis", "worker", "beat", "minio", "minio-create-bucket"}, "base Compose must define expected services including minio")
require(compose_raw.get("networks", {}).get("backend", {}).get("internal") is True, "backend network must be internal")
for name in ("web", "db", "redis", "worker", "beat", "minio"):
    require(not services[name].get("ports"), f"{name} must not publish ports in base Compose")
for name in ("web", "worker", "beat", "redis", "nginx"):
    require(services[name].get("read_only") is True, f"{name} read_only hardening missing")
for name in ("web", "worker", "beat", "redis", "nginx", "minio"):
    require("ALL" in (services[name].get("cap_drop") or []), f"{name} cap_drop ALL missing")
for name, service in services.items():
    if name == "minio-create-bucket":
        continue
    require(service.get("healthcheck"), f"{name} healthcheck missing")
    require(service.get("logging", {}).get("driver") == "json-file" or name in {"web", "worker", "beat"}, f"{name} json-file logging missing")

worker_command = " ".join(map(str, services["worker"].get("command") or []))
beat_command = " ".join(map(str, services["beat"].get("command") or []))
require("worker" in worker_command and "-B" not in worker_command and "--beat" not in worker_command, "worker/Beat separation broken")
require("beat" in beat_command and "DatabaseScheduler" in beat_command, "Beat DatabaseScheduler contract missing")

site = (ansible / "playbooks/site.yml").read_text(encoding="utf-8")
markers = [
    "- role: common",
    "- role: docker_engine",
    "- role: docker_runtime_hardening",
    "- role: compose_stack",
]
positions = []
for marker in markers:
    pos = site.find(marker)
    require(pos >= 0, f"site.yml missing active role {marker}")
    positions.append(pos)
require(positions == sorted(positions), "site.yml active role ordering is invalid")
for legacy in ("postgresql", "redis", "django_app", "celery", "celery_beat", "nginx"):
    require(f"- role: {legacy}" not in site, f"legacy native role {legacy} must not be active")

hardening_tasks = (ansible / "roles/docker_runtime_hardening/tasks/main.yml").read_text(encoding="utf-8")
firewall_template = (ansible / "roles/docker_runtime_hardening/templates/docker-user-firewall.sh.j2").read_text(encoding="utf-8")
daemon_template = (ansible / "roles/docker_runtime_hardening/templates/daemon.json.j2").read_text(encoding="utf-8")
require("dockerd" in hardening_tasks and "--validate" in hardening_tasks, "dockerd validation gate missing")
require("DOCKER-USER" in firewall_template and "conntrack" in firewall_template and "ctorigdstport" in firewall_template, "DOCKER-USER original-port policy missing")
require(
    '"live-restore"' in daemon_template
    and '"iptables": true' in daemon_template
    and '"ip6tables": true' in daemon_template,
    "portable iptables Docker daemon hardening template incomplete",
)

for env_name in ("stg", "prod"):
    overlay = (docker / f"compose.{env_name}.yml").read_text(encoding="utf-8")
    require("build:" not in overlay, f"{env_name} overlay must not build application")
    require("config.settings." + env_name in overlay, f"{env_name} settings module missing")
    require("DJANGO_DEBUG: \"false\"" in overlay, f"{env_name} DEBUG must be false")

print("STATIC_SOURCE_INVARIANTS_PASS")
PY
pass "source invariants"

echo "== Django unit and API tests =="
(
  cd "$DJANGO_DIR"
  env -u DATABASE_URL \
    APPLICATION_ENV=dev \
    DJANGO_SETTINGS_MODULE=config.settings.dev \
    DJANGO_SECRET_KEY=STATIC_CHECK_ONLY_DJANGO_SECRET_KEY_0123456789abcdefghijklmnopqrstuvwxyzABCDEFG \
    python manage.py test tests tasks_demo.tests --verbosity 1
)
pass "Django settings, health, tasks and DRF tests"

echo "== Ansible collection contract =="
command -v ansible-playbook >/dev/null 2>&1 || fail "ansible-playbook is required for DC-11"
command -v ansible-galaxy >/dev/null 2>&1 || fail "ansible-galaxy is required for DC-11"
ansible-galaxy collection list community.docker >/dev/null 2>&1 \
  || fail "community.docker is not installed; run ansible-galaxy collection install -r requirements.yml"
pass "Ansible + community.docker available"

prepare_static_vault() {
  local env_name="$1"
  local vault="inventories/$env_name/group_vars/vault.yml"
  if [[ -f "$vault" ]]; then
    return 0
  fi
  umask 077
  cat > "$vault" <<EOF
---
vault_environment: $env_name
vault_secret_generation: 1
vault_django_secret_key: STATIC_CHECK_ONLY_DJANGO_SECRET_KEY_0123456789abcdefghijklmnopqrstuvwxyzABCDEFG
vault_postgresql_password: STATIC_CHECK_ONLY_POSTGRES_1234567890abcdef
vault_redis_password: STATIC_CHECK_ONLY_REDIS_1234567890abcdefghi
vault_minio_root_user: STATIC_CHECK_ONLY_MINIO_USER
vault_minio_root_password: STATIC_CHECK_ONLY_MINIO_PASSWORD_123456789
vault_aws_access_key_id: STATIC_CHECK_ONLY_AWS_KEY
vault_aws_secret_access_key: STATIC_CHECK_ONLY_AWS_SECRET_1234567890abcdef
vault_smtp_user: STATIC_CHECK_ONLY_SMTP_USER
vault_smtp_password: STATIC_CHECK_ONLY_SMTP_PASSWORD_123456789
vault_resend_api_key: STATIC_CHECK_ONLY_RESEND_KEY_123456789
EOF
  CREATED_VAULTS+=("$vault")
}

echo "== Ansible syntax-check =="
for env_name in dev stg prod; do
  prepare_static_vault "$env_name"
  vault="inventories/$env_name/group_vars/vault.yml"
  vault_args=()
  if head -n 1 "$vault" | grep -q '^\$ANSIBLE_VAULT;'; then
    if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
      vault_args+=(--vault-password-file "$ANSIBLE_VAULT_PASSWORD_FILE")
    elif [[ -f .vault_pass ]]; then
      vault_args+=(--vault-password-file .vault_pass)
    else
      echo "STATIC_GATE_SKIP: encrypted $env_name vault present without password; site.yml syntax-check skipped for this environment"
      continue
    fi
  fi
  ansible-playbook \
    -i "inventories/$env_name/hosts.example.yml" \
    playbooks/site.yml \
    --syntax-check \
    -e "deployment_environment=$env_name" \
    ${vault_args[@]+"${vault_args[@]}"}
done
ansible-playbook -i inventories/dev/hosts.example.yml playbooks/docker_engine.yml --syntax-check
ansible-playbook -i inventories/dev/hosts.example.yml playbooks/runtime_hardening.yml --syntax-check -e deployment_environment=dev
pass "Ansible syntax-check"

echo "== Docker Compose rendered configuration =="
command -v docker >/dev/null 2>&1 || fail "docker CLI is required for DC-11"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 plugin is required for DC-11"

write_compose_env() {
  local env_name="$1"
  local env_file="$2"
  local image settings debug bind port
  if [[ "$env_name" == "dev" ]]; then
    image="datascientest-django:static-gate"
    settings="config.settings.dev"
    debug="false"
    bind="127.0.0.1"
    port="8080"
  else
    image="registry.example.invalid/datascientest-django@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    settings="config.settings.$env_name"
    debug="false"
    bind="0.0.0.0"
    port="80"
  fi
  cat > "$env_file" <<EOF
APP_IMAGE=$image
APPLICATION_ENV=$env_name
APPLICATION_VERSION=0.0.0-static
APPLICATION_COMMIT=STATIC_CHECK_ONLY_COMMIT
DJANGO_SETTINGS_MODULE=$settings
DJANGO_SECRET_KEY=STATIC_CHECK_ONLY_DJANGO_SECRET_KEY_0123456789abcdefghijklmnopqrstuvwxyzABCDEFG
DJANGO_DEBUG=$debug
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,web,nginx
DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost
DATABASE_URL=postgresql://django_app:STATIC_CHECK_ONLY_POSTGRES_1234567890abcdef@db:5432/django_app
CELERY_BROKER_URL=redis://:STATIC_CHECK_ONLY_REDIS_1234567890abcdefghi@redis:6379/0
CELERY_RESULT_BACKEND=redis://:STATIC_CHECK_ONLY_REDIS_1234567890abcdefghi@redis:6379/1
POSTGRES_DB=django_app
POSTGRES_USER=django_app
POSTGRES_PASSWORD=STATIC_CHECK_ONLY_POSTGRES_1234567890abcdef
REDIS_PASSWORD=STATIC_CHECK_ONLY_REDIS_1234567890abcdefghi
NGINX_HTTP_BIND_ADDRESS=$bind
NGINX_HTTP_PORT=$port
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=STATIC_CHECK_ONLY_MINIO_1234567890abcdef
AWS_STORAGE_BUCKET_NAME=dst-media
AWS_ACCESS_KEY_ID=STATIC_CHECK_ONLY_MINIO_KEY
AWS_SECRET_ACCESS_KEY=STATIC_CHECK_ONLY_MINIO_SECRET
EOF
}

for env_name in dev stg prod; do
  env_file="$TMP_DIR/$env_name.env"
  rendered="$TMP_DIR/compose-$env_name.yml"
  write_compose_env "$env_name" "$env_file"
  docker compose \
    --env-file "$env_file" \
    -f "$DOCKER_DIR/compose.yml" \
    -f "$DOCKER_DIR/compose.$env_name.yml" \
    config --quiet
  docker compose \
    --env-file "$env_file" \
    -f "$DOCKER_DIR/compose.yml" \
    -f "$DOCKER_DIR/compose.$env_name.yml" \
    config > "$rendered"
  python3 tests/validate_compose_config.py "$env_name" "$rendered"
done
pass "Compose config DEV/STG/PROD"

echo "== Docker daemon config validation =="
if command -v dockerd >/dev/null 2>&1; then
  cat > "$TMP_DIR/daemon.json" <<'EOF'
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "iptables": true,
  "ip6tables": true
}
EOF
  dockerd --validate --config-file "$TMP_DIR/daemon.json"
  pass "dockerd --validate"
else
  echo "STATIC_GATE_SKIP: dockerd not available; daemon config runtime validation deferred"
fi

echo "DC11_STATIC_GATE_PASS"
