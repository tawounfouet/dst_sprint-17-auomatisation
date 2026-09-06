#!/usr/bin/env bash
set -euo pipefail

INVENTORY="${1:-inventaire.ini}"

if ! command -v ansible >/dev/null 2>&1; then
  echo "[ERROR] ansible introuvable dans le PATH" >&2
  exit 1
fi

if ! command -v ansible-inventory >/dev/null 2>&1; then
  echo "[ERROR] ansible-inventory introuvable dans le PATH" >&2
  exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
  echo "[ERROR] inventaire absent : $INVENTORY" >&2
  echo "Copiez inventaire.example.ini vers inventaire.ini puis remplacez les placeholders IP." >&2
  exit 1
fi

if grep -q '<IP_CIBLE' "$INVENTORY"; then
  echo "[ERROR] placeholders IP encore présents dans $INVENTORY" >&2
  exit 1
fi

echo "[1/4] Version Ansible"
ansible --version | head -n 1

echo "[2/4] Validation de l'inventaire"
ansible-inventory -i "$INVENTORY" --list >/dev/null

echo "[3/4] Ping des cibles"
ansible all -i "$INVENTORY" -m ping

echo "[4/4] Fact minimal sur cible1"
ansible cible1 -i "$INVENTORY" -m setup -a 'filter=ansible_virtualization_type'

echo "[OK] Lab 02 qualifié : connectivité et facts opérationnels."
