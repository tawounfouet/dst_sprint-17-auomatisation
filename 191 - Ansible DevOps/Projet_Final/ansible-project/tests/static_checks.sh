#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
required=(
  ansible.cfg
  requirements.yml
  playbooks/site.yml
  playbooks/validate.yml
  roles/mysql/tasks/main.yml
  roles/prestashop/tasks/main.yml
  inventories/prod/hosts.example.yml
  inventories/prod/group_vars/vault.example.yml
)
for f in "${required[@]}"; do
  [[ -f "$f" ]] || { echo "[FAIL] missing $f"; exit 1; }
  echo "[OK] $f"
done
if command -v ansible-playbook >/dev/null 2>&1 && [[ -f inventories/prod/hosts.yml ]]; then
  ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --syntax-check --ask-vault-pass
else
  echo "[INFO] Ansible runtime syntax-check skipped: ansible-playbook or local inventory unavailable"
fi
