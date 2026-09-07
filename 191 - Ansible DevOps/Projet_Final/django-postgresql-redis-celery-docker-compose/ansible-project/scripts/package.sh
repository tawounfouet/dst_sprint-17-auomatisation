#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PARENT_DIR="$(dirname "$PROJECT_DIR")"
ANSIBLE_PROJECT_DIR="$PROJECT_DIR/ansible-project"
SCANNER="$ANSIBLE_PROJECT_DIR/scripts/secret_hygiene.py"
OUTPUT_DIR="${PACKAGE_OUTPUT_DIR:-$PARENT_DIR}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_NAME="django-postgresql-redis-celery-docker-compose-ansible-$TIMESTAMP.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

command -v zip >/dev/null 2>&1 || { echo "ERROR: zip is required." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum is required." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required." >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

python3 "$SCANNER" repo

cd "$PARENT_DIR"
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"

zip -r "$ARCHIVE_PATH" "$PROJECT_NAME" \
  -x "*/inventories/*/hosts.yml" \
     "*/inventories/*/host_vars/server1.yml" \
     "*/inventories/*/group_vars/vault.yml" \
     "*/.vault_pass" \
     "*/.vault_pass*" \
     "*/.env" \
     "*/.env.dev" \
     "*/.env.stg" \
     "*/.env.prod" \
     "*/.env.runtime" \
     "*/secret-values.txt" \
     "*/secret-values.*" \
     "*/.venv/*" \
     "*/venv/*" \
     "*/__pycache__/*" \
     "*/.pytest_cache/*" \
     "*/.git/*" \
     "*/.ssh/*" \
     "*/id_rsa" \
     "*/id_rsa.*" \
     "*/id_ed25519" \
     "*/id_ed25519.*" \
     "*.pem" \
     "*.key" \
     "*.zip" \
     "*.zip.sha256"

python3 "$SCANNER" archive "$ARCHIVE_PATH"
sha256sum "$ARCHIVE_PATH" > "$CHECKSUM_PATH"
printf 'Archive: %s\nChecksum: %s\n' "$ARCHIVE_PATH" "$CHECKSUM_PATH"
cat "$CHECKSUM_PATH"
