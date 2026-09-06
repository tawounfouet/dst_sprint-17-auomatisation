#!/usr/bin/env bash
set -Eeuo pipefail

ARCHIVE="${1:-}"
[[ -n "$ARCHIVE" ]] || { echo "Usage: $0 <archive.zip>" >&2; exit 2; }
[[ -f "$ARCHIVE" ]] || { echo "ERROR: archive not found: $ARCHIVE" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip is required." >&2; exit 1; }

unzip -tq "$ARCHIVE" >/dev/null
LISTING="$(unzip -Z1 "$ARCHIVE")"

require_entry() {
  local entry="$1"
  printf '%s\n' "$LISTING" | grep -Fxq "$entry" || {
    echo "ERROR: required package entry missing: $entry" >&2
    exit 1
  }
}

for entry in \
  django-postgresql/README.md \
  django-postgresql/django-app/manage.py \
  django-postgresql/ansible-project/playbooks/site.yml \
  django-postgresql/ansible-project/playbooks/validate.yml \
  django-postgresql/ansible-project/tests/e2e/run_first_qualification.sh \
  django-postgresql/ansible-project/inventories/prod/hosts.example.yml \
  django-postgresql/ansible-project/inventories/prod/group_vars/vault.example.yml; do
  require_entry "$entry"
done

if printf '%s\n' "$LISTING" | grep -E '(^|/)\.vault_pass([^/]*$)|(^|/)inventories/prod/hosts\.yml$|(^|/)inventories/prod/group_vars/vault\.yml$|(^|/)inventories/prod/host_vars/(app1|db1)\.yml$|(^|/)(id_rsa|id_ed25519)(\.|$)|\.(pem|key)$|(^|/)\.env($|\.)|(^|/)\.venv/|(^|/)venv/'; then
  echo "ERROR: sensitive or runtime-only content found in package." >&2
  exit 1
fi

echo "PACKAGE SAFETY PASS: $ARCHIVE"
