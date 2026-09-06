#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/7] Vérification des binaires"
command -v ansible >/dev/null
command -v ansible-playbook >/dev/null
command -v ansible-galaxy >/dev/null

echo "[2/7] Vérification de la structure du rôle"
for path in \
  roles/wordpress/defaults/main.yml \
  roles/wordpress/handlers/main.yml \
  roles/wordpress/tasks/main.yml \
  roles/wordpress/tasks/nginx.yml \
  roles/wordpress/templates/nginx-vhost.j2 \
  roles/wordpress/templates/wp-config.php.j2 \
  roles/wordpress/meta/main.yml; do
  test -f "$path" || { echo "[FAIL] Fichier manquant: $path"; exit 1; }
done

echo "[3/7] Vérification de la collection community.mysql"
if ! ansible-galaxy collection list 2>/dev/null | grep -q '^community\.mysql'; then
  echo "[FAIL] community.mysql absente"
  echo "       Exécuter: ansible-galaxy collection install -r requirements.yml"
  exit 1
fi

echo "[4/7] Parsing de l'inventaire"
ansible-inventory -i inventaire.example.yaml --graph >/dev/null

echo "[5/7] Syntax-check du playbook"
ansible-playbook -i inventaire.example.yaml install_wordpress.yaml --syntax-check >/dev/null

echo "[6/7] Syntax-check du harness du rôle"
ansible-playbook -i roles/wordpress/tests/inventory roles/wordpress/tests/test.yml --syntax-check >/dev/null

echo "[7/7] Vérification de la connectivité si host_vars réel présent"
if [[ -f host_vars/serveurweb1.yaml ]]; then
  ansible production -i inventaire.example.yaml -m ansible.builtin.ping
else
  echo "[SKIP] host_vars/serveurweb1.yaml absent. Copier le fichier .example et renseigner l'IP."
fi

echo "[OK] Lab 05 structure/syntax qualifiées"
