#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
INVENTORY="${INVENTORY:-inventories/prod/hosts.yml}"
VAULT_ARGS=()
if [[ -n "${VAULT_PASSWORD_FILE:-}" ]]; then
  VAULT_ARGS+=(--vault-password-file "$VAULT_PASSWORD_FILE")
else
  VAULT_ARGS+=(--ask-vault-pass)
fi
ansible-inventory -i "$INVENTORY" --graph
ansible all -i "$INVENTORY" -m ansible.builtin.ping
ansible-playbook -i "$INVENTORY" playbooks/site.yml --syntax-check "${VAULT_ARGS[@]}"
