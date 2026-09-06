#!/usr/bin/env bash
set -euo pipefail

INVENTORY="${1:-inventaire.ini}"

if ! command -v ansible >/dev/null 2>&1; then
  echo "[FAIL] ansible introuvable"
  exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
  echo "[FAIL] inventaire introuvable: $INVENTORY"
  echo "Copiez inventaire.example.ini vers inventaire.ini puis renseignez les IPs."
  exit 1
fi

if grep -Eq '<IP_CIBLE[123]>' "$INVENTORY"; then
  echo "[FAIL] remplacez les placeholders <IP_CIBLE1/2/3> dans $INVENTORY"
  exit 1
fi

echo "[1/4] Parsing de l'inventaire"
ansible-inventory -i "$INVENTORY" --list >/dev/null

echo "[2/4] Graphe de l'inventaire"
GRAPH="$(ansible-inventory -i "$INVENTORY" --graph)"
printf '%s\n' "$GRAPH"

for host in client-dev client-test client-prod; do
  if ! grep -q -- "$host" <<<"$GRAPH"; then
    echo "[FAIL] alias absent du graphe: $host"
    exit 1
  fi
done

echo "[3/4] Validation des variables env"
for pair in "client-dev:dev" "client-test:test" "client-prod:prod"; do
  host="${pair%%:*}"
  expected="${pair##*:}"
  if ! ansible-inventory -i "$INVENTORY" --host "$host" | grep -q "\"env\": \"$expected\""; then
    echo "[FAIL] variable env inattendue pour $host"
    exit 1
  fi
done

echo "[4/4] Ping des trois cibles"
ansible all -i "$INVENTORY" -m ping

echo "[OK] Lab 03 qualifié"
