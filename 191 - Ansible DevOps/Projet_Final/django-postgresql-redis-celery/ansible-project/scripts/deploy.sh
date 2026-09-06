#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INVENTORY="${ANSIBLE_INVENTORY:-inventories/prod/hosts.yml}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="../evidence/logs"
LOG_FILE="$LOG_DIR/deploy-$TIMESTAMP.txt"
VAULT_ARGS=()
[[ -f .vault_pass ]] && VAULT_ARGS+=(--vault-password-file .vault_pass)

mkdir -p "$LOG_DIR"
[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }

set -o pipefail
ansible-playbook -i "$INVENTORY" playbooks/site.yml "${VAULT_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
printf 'Deployment log: %s\n' "$LOG_FILE"
