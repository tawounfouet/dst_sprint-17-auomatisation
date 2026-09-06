#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
INVENTORY="${INVENTORY:-inventories/prod/hosts.yml}"
LOG_DIR="../evidence/logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/validation-$STAMP.txt"
VAULT_ARGS=()
if [[ -n "${VAULT_PASSWORD_FILE:-}" ]]; then
  VAULT_ARGS+=(--vault-password-file "$VAULT_PASSWORD_FILE")
else
  VAULT_ARGS+=(--ask-vault-pass)
fi
ansible-playbook -i "$INVENTORY" playbooks/validate.yml "${VAULT_ARGS[@]}" | tee "$LOG_FILE"
echo "Validation log: $LOG_FILE"
