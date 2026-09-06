#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="exam-final-ansible-$STAMP.zip"
zip -r "$OUT" . \
  -x '.vault_pass' '*.pem' '*.key' '*.retry' '.ansible/*' \
     'inventories/prod/hosts.yml' \
     'inventories/prod/host_vars/web1.yml' \
     'inventories/prod/host_vars/db1.yml' \
     'inventories/prod/group_vars/vault.yml' \
     'exam-final-*.zip'
echo "$OUT"
