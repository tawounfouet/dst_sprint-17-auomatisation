#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-group_vars/production.yaml}"

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo "[ERROR] ansible-vault introuvable"
  exit 1
fi

echo "[OK] ansible-vault disponible"

if [[ ! -f "$TARGET" ]]; then
  echo "[ERROR] fichier Vault absent: $TARGET"
  echo "        Copiez group_vars/production.example.yaml vers group_vars/production.yaml puis chiffrez-le."
  exit 1
fi

if ! head -n 1 "$TARGET" | grep -q '^\$ANSIBLE_VAULT;'; then
  echo "[ERROR] $TARGET n'est pas chiffré avec Ansible Vault"
  exit 1
fi

echo "[OK] en-tête Vault détecté dans $TARGET"

if [[ -f "$HOME/.vault_pass" ]]; then
  perms="$(stat -c '%a' "$HOME/.vault_pass")"
  if [[ "$perms" == "600" ]]; then
    echo "[OK] ~/.vault_pass est en mode 600"
  else
    echo "[WARN] ~/.vault_pass a les permissions $perms ; le support recommande chmod 600 ~/.vault_pass"
  fi
fi

if [[ -n "${VAULT_PASSWORD_FILE:-}" ]]; then
  ansible-vault view "$TARGET" --vault-password-file "$VAULT_PASSWORD_FILE" >/dev/null
  echo "[OK] lecture Vault validée avec VAULT_PASSWORD_FILE"
else
  echo "[INFO] VAULT_PASSWORD_FILE non défini : vérification de lecture non interactive ignorée"
fi

echo "[OK] Lab 06 qualifié"
