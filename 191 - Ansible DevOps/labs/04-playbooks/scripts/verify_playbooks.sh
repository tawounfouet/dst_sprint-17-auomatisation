#!/usr/bin/env bash
set -euo pipefail

INVENTORY="${1:-inventaire.yaml}"
PLAYBOOK="${2:-playbooks/datascientest-playbook.yaml}"

fail() { echo "[FAIL] $*" >&2; exit 1; }
ok() { echo "[OK] $*"; }

command -v ansible >/dev/null 2>&1 || fail "ansible introuvable"
command -v ansible-playbook >/dev/null 2>&1 || fail "ansible-playbook introuvable"
[[ -f "$INVENTORY" ]] || fail "Inventaire absent: $INVENTORY (copier inventaire.example.yaml)"
[[ -f "$PLAYBOOK" ]] || fail "Playbook absent: $PLAYBOOK"

ansible-inventory -i "$INVENTORY" --list >/dev/null
ok "Inventaire parsable"

ansible all -i "$INVENTORY" -m ping >/dev/null
ok "Cibles joignables"

ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --syntax-check >/dev/null
ok "Syntaxe du playbook valide"

ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --list-hosts >/dev/null
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --list-tags >/dev/null
ok "Hôtes et tags inspectables"

if ansible serveurweb1 -i "$INVENTORY" -b -m command -a "systemctl is-active apache2" >/dev/null 2>&1; then
  ok "Apache2 actif"
else
  echo "[INFO] Apache2 non actif ou non encore installé"
fi

if ansible serveurdatabase1 -i "$INVENTORY" -b -m command -a "systemctl is-active postgresql" >/dev/null 2>&1; then
  ok "PostgreSQL actif"
else
  echo "[INFO] PostgreSQL non actif ou non encore installé"
fi

ok "Lab 04 qualifié (contrôles non destructifs)"
