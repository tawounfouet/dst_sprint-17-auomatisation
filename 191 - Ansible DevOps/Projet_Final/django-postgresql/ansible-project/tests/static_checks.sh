#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
DJANGO_DIR="$ROOT_DIR/django-app"
cd "$PROJECT_DIR"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

pass() {
  echo "OK: $*"
}

require_file() {
  [[ -f "$1" ]] || fail "required file missing: $1"
}

require_dir() {
  [[ -d "$1" ]] || fail "required directory missing: $1"
}

echo "== Structure =="
for file in \
  ansible.cfg \
  requirements.yml \
  playbooks/site.yml \
  playbooks/validate.yml \
  inventories/prod/hosts.example.yml \
  inventories/prod/group_vars/all.yml \
  inventories/prod/group_vars/vault.example.yml \
  inventories/prod/host_vars/app1.example.yml \
  inventories/prod/host_vars/db1.example.yml \
  scripts/preflight.sh \
  scripts/deploy.sh \
  scripts/validate_runtime.sh \
  scripts/package.sh; do
  require_file "$file"
done

for role in common postgresql django_app nginx; do
  require_dir "roles/$role"
  require_file "roles/$role/tasks/main.yml"
  require_file "roles/$role/defaults/main.yml"
  require_file "roles/$role/meta/main.yml"
done

for file in \
  roles/postgresql/handlers/main.yml \
  roles/postgresql/templates/99-datascientest.conf.j2 \
  roles/django_app/handlers/main.yml \
  roles/django_app/templates/django.env.j2 \
  roles/django_app/templates/django-gunicorn.service.j2 \
  roles/nginx/handlers/main.yml \
  roles/nginx/templates/django.conf.j2; do
  require_file "$file"
done
pass "Ansible project structure"

echo "== Django scaffold =="
for file in \
  "$DJANGO_DIR/manage.py" \
  "$DJANGO_DIR/requirements.txt" \
  "$DJANGO_DIR/config/__init__.py" \
  "$DJANGO_DIR/config/settings.py" \
  "$DJANGO_DIR/config/urls.py" \
  "$DJANGO_DIR/config/wsgi.py" \
  "$DJANGO_DIR/health/__init__.py" \
  "$DJANGO_DIR/health/apps.py" \
  "$DJANGO_DIR/health/views.py" \
  "$DJANGO_DIR/health/urls.py" \
  "$DJANGO_DIR/tests/test_health.py"; do
  require_file "$file"
done

grep -Fq 'Django>=5.2,<5.3' "$DJANGO_DIR/requirements.txt" || fail "Django dependency contract missing"
grep -Fq 'gunicorn>=23,<24' "$DJANGO_DIR/requirements.txt" || fail "Gunicorn dependency contract missing"
grep -Fq 'psycopg[binary]>=3.2,<4' "$DJANGO_DIR/requirements.txt" || fail "psycopg dependency contract missing"
pass "Django scaffold and dependencies"

echo "== Bash syntax =="
while IFS= read -r -d '' script; do
  bash -n "$script" || fail "invalid Bash syntax: $script"
done < <(find scripts tests -type f -name '*.sh' -print0)
pass "Bash syntax"

echo "== Python syntax =="
python3 - "$DJANGO_DIR" <<'PY'
from pathlib import Path
import ast
import sys

root = Path(sys.argv[1])
for path in sorted(root.rglob("*.py")):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
pass "Python source parses with ast"

echo "== YAML syntax =="
if python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 - "$PROJECT_DIR" <<'PY'
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
  pass "YAML parses with PyYAML"
else
  echo "SKIP: PyYAML is not installed; YAML parse check not executed."
fi

echo "== Runtime configuration invariants =="
grep -Fq 'django_venv_dir: "{{ django_install_dir }}/.venv"' roles/django_app/defaults/main.yml \
  || fail "Django venv must be named .venv"
grep -Fq -- '- venv' roles/django_app/tasks/main.yml \
  || fail "Django role must create the environment with python3 -m venv"
if grep -REn '(^|[[:space:]-])virtualenv([[:space:]]|$)' roles/django_app/defaults roles/django_app/tasks; then
  fail "virtualenv must not be used by the Django runtime role"
fi

grep -Rq 'scram-sha-256' roles/postgresql/defaults roles/postgresql/tasks roles/postgresql/templates \
  || fail "PostgreSQL SCRAM contract missing"
if grep -REn '(^|[[:space:]])trust([[:space:]]|$)' roles/postgresql/defaults roles/postgresql/tasks roles/postgresql/templates roles/postgresql/handlers; then
  fail "PostgreSQL runtime configuration must not use trust authentication"
fi
if grep -REn '0\.0\.0\.0/0|::/0' roles/postgresql/defaults roles/postgresql/tasks roles/postgresql/templates; then
  fail "PostgreSQL runtime configuration contains a broad CIDR"
fi

grep -Fq 'django_gunicorn_bind: 127.0.0.1:8000' inventories/prod/group_vars/all.yml \
  || fail "Gunicorn must remain bound to 127.0.0.1:8000"
if grep -Eq '^[[:space:]]*django_allowed_hosts:[[:space:]]*"?\*"?[[:space:]]*$' inventories/prod/group_vars/all.yml \
  || grep -Eq "^[[:space:]]*django_allowed_hosts:[[:space:]]*'\\*'[[:space:]]*$" inventories/prod/group_vars/all.yml; then
  fail "DJANGO_ALLOWED_HOSTS wildcard is not accepted"
fi
pass "venv, PostgreSQL, Gunicorn and allowed-host hardening"

echo "== Secret and sensitive-file guards =="
if grep -R -n --exclude='*.md' 'CHANGE_ME_' roles playbooks "$DJANGO_DIR/config" "$DJANGO_DIR/health"; then
  fail "placeholder secret found in runtime implementation"
fi

if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tracked="$(git -C "$PROJECT_DIR" ls-files -- .)"
  if printf '%s\n' "$tracked" | grep -E '(^|/)\.vault_pass[^/]*$|(^|/)inventories/prod/hosts\.yml$|(^|/)inventories/prod/group_vars/vault\.yml$|(^|/)inventories/prod/host_vars/(app1|db1)\.yml$|(^|/)(id_rsa|id_ed25519)[^/]*$|\.(pem|key)$'; then
    fail "sensitive runtime file is tracked by Git"
  fi
  pass "No forbidden sensitive runtime files tracked"
else
  echo "SKIP: Git worktree not available for tracked-file check."
fi

echo "== Ansible syntax =="
TEMP_VAULT_CREATED=0
cleanup() {
  if [[ "$TEMP_VAULT_CREATED" -eq 1 ]]; then
    rm -f inventories/prod/group_vars/vault.yml
  fi
}
trap cleanup EXIT

if command -v ansible-playbook >/dev/null 2>&1; then
  if command -v ansible-galaxy >/dev/null 2>&1 && ! ansible-galaxy collection list community.postgresql >/dev/null 2>&1; then
    fail "community.postgresql is not installed; run ansible-galaxy collection install -r requirements.yml"
  fi

  VAULT_ARGS=()
  CAN_CHECK_SITE=1
  if [[ -f inventories/prod/group_vars/vault.yml ]]; then
    if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
      VAULT_ARGS+=(--vault-password-file "$ANSIBLE_VAULT_PASSWORD_FILE")
    elif [[ -f .vault_pass ]]; then
      VAULT_ARGS+=(--vault-password-file .vault_pass)
    elif head -n 1 inventories/prod/group_vars/vault.yml | grep -q '^\$ANSIBLE_VAULT;'; then
      CAN_CHECK_SITE=0
      echo "SKIP: site.yml syntax-check requires a Vault password for the encrypted vault.yml."
    fi
  else
    umask 077
    cat > inventories/prod/group_vars/vault.yml <<'EOF'
---
vault_postgresql_password: STATIC_CHECK_ONLY_NOT_A_SECRET
vault_django_secret_key: STATIC_CHECK_ONLY_NOT_A_SECRET_0123456789
EOF
    TEMP_VAULT_CREATED=1
  fi

  if [[ "$CAN_CHECK_SITE" -eq 1 ]]; then
    ansible-playbook -i inventories/prod/hosts.example.yml playbooks/site.yml --syntax-check "${VAULT_ARGS[@]}"
    pass "site.yml syntax-check"
  fi
  ansible-playbook -i inventories/prod/hosts.example.yml playbooks/validate.yml --syntax-check
  pass "validate.yml syntax-check"
else
  echo "SKIP: ansible-playbook is not installed; playbook syntax checks not executed."
fi

echo "All available static checks passed."
