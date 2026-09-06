#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INVENTORY="${ANSIBLE_INVENTORY:-inventories/prod/hosts.yml}"
VAULT_ARGS=()
[[ -f .vault_pass ]] && VAULT_ARGS+=(--vault-password-file .vault_pass)

[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }
[[ -f inventories/prod/group_vars/vault.yml ]] || { echo "ERROR: encrypted vault file is missing" >&2; exit 1; }

ansible-galaxy collection install -r requirements.yml
ansible-inventory -i "$INVENTORY" --graph
ansible -i "$INVENTORY" app:database -m ansible.builtin.ping
ansible-playbook -i "$INVENTORY" playbooks/site.yml --syntax-check "${VAULT_ARGS[@]}"
ansible-playbook -i "$INVENTORY" playbooks/validate.yml --syntax-check
