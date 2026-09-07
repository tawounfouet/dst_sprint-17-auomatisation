#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-prod}"
case "$DEPLOYMENT_ENV" in
  dev|stg|prod) ;;
  *) echo "ERROR: DEPLOYMENT_ENV must be dev, stg or prod." >&2; exit 1 ;;
esac

INVENTORY="${ANSIBLE_INVENTORY:-inventories/$DEPLOYMENT_ENV/hosts.yml}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="../evidence/logs"
LOG_FILE="$LOG_DIR/deploy-$DEPLOYMENT_ENV-$TIMESTAMP.txt"
VAULT_ARGS=()
[[ -f .vault_pass ]] && VAULT_ARGS+=(--vault-password-file .vault_pass)

mkdir -p "$LOG_DIR"
[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }

set +e
set -o pipefail
ansible-playbook -i "$INVENTORY" playbooks/site.yml "${VAULT_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
ANSIBLE_STATUS=${PIPESTATUS[0]}
set -e

SCAN_ARGS=(tree "$LOG_FILE")
[[ -n "${SECRET_VALUES_FILE:-}" ]] && SCAN_ARGS+=(--secret-values-file "$SECRET_VALUES_FILE")
SCAN_STATUS=0
python3 scripts/secret_hygiene.py "${SCAN_ARGS[@]}" || SCAN_STATUS=$?

printf 'Deployment log: %s\n' "$LOG_FILE"
(( ANSIBLE_STATUS == 0 )) || exit "$ANSIBLE_STATUS"
(( SCAN_STATUS == 0 )) || exit "$SCAN_STATUS"
