#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/6] Vérification Ansible"
command -v ansible >/dev/null
command -v ansible-playbook >/dev/null
command -v ansible-galaxy >/dev/null

echo "[2/6] Vérification structure du rôle"
for path in \
  roles/wordpress/defaults/main.yml \
  roles/wordpress/handlers/main.yml \
  roles/wordpress/tasks/main.yml \
  roles/wordpress/tasks/nginx.yaml \
  roles/wordpress/templates/nginx-vhost.j2 \
  roles/wordpress/templates/wp-config.php.j2; do
  test -f "$path" || { echo "Fichier manquant: $path"; exit 1; }
done

echo "[3/6] Vérification syntaxique de l'inventaire exemple"
ansible-inventory -i inventaire.example.yaml --list >/dev/null

echo "[4/6] Vérification syntaxique du playbook"
# Le syntax-check utilise l'inventaire exemple mais ne contacte pas la cible.
ansible-playbook -i inventaire.example.yaml install_wordpress.yaml --syntax-check

echo "[5/6] Vérification des fichiers locaux"
if [[ -f inventaire.yaml ]]; then
  ansible-inventory -i inventaire.yaml --graph
else
  echo "inventaire.yaml absent : copiez inventaire.example.yaml avant exécution réelle."
fi

echo "[6/6] Ping optionnel"
if [[ -f inventaire.yaml && -f host_vars/serveurweb1.yaml ]]; then
  ansible all -i inventaire.yaml -m ping
else
  echo "SKIP ping : inventaire local non configuré."
fi

echo "[OK] Structure et syntaxe du Lab 05 qualifiées"
