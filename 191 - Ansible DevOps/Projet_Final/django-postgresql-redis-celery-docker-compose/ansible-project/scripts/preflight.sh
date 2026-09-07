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
VAULT_FILE="inventories/$DEPLOYMENT_ENV/group_vars/vault.yml"
VAULT_ARGS=()
[[ -f .vault_pass ]] && VAULT_ARGS+=(--vault-password-file .vault_pass)

[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 1; }
[[ -f "$VAULT_FILE" ]] || { echo "ERROR: encrypted vault file is missing for $DEPLOYMENT_ENV" >&2; exit 1; }

python3 scripts/secret_hygiene.py repo
ansible-galaxy collection install -r requirements.yml
ansible-inventory -i "$INVENTORY" --graph
ansible -i "$INVENTORY" app -m ansible.builtin.ping
ansible-playbook -i "$INVENTORY" playbooks/site.yml --syntax-check "${VAULT_ARGS[@]}"
ansible-playbook -i "$INVENTORY" playbooks/validate.yml --syntax-check "${VAULT_ARGS[@]}"
