#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PARENT_DIR="$(dirname "$PROJECT_DIR")"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_NAME="django-postgresql-ansible-$TIMESTAMP.zip"
ARCHIVE_PATH="$PARENT_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

cd "$PARENT_DIR"
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"

zip -r "$ARCHIVE_PATH" "$PROJECT_NAME" \
  -x "*/inventories/prod/hosts.yml" \
     "*/inventories/prod/host_vars/*.yml" \
     "*/inventories/prod/group_vars/vault.yml" \
     "*/.vault_pass" \
     "*/.vault_pass*" \
     "*/.env" \
     "*/.env.*" \
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

sha256sum "$ARCHIVE_PATH" > "$CHECKSUM_PATH"
printf 'Archive: %s\nChecksum: %s\n' "$ARCHIVE_PATH" "$CHECKSUM_PATH"
cat "$CHECKSUM_PATH"
