#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PARENT_DIR="$(dirname "$PROJECT_DIR")"
ANSIBLE_PROJECT_DIR="$PROJECT_DIR/ansible-project"
SCANNER="$ANSIBLE_PROJECT_DIR/scripts/secret_hygiene.py"
OUTPUT_DIR="${PACKAGE_OUTPUT_DIR:-$PARENT_DIR}"
TIMESTAMP="${PACKAGE_TIMESTAMP:-$(date -u +%Y%m%d-%H%M%S)}"
DEFAULT_ARCHIVE_NAME="django-postgresql-redis-celery-docker-compose-ansible-$TIMESTAMP.zip"
ARCHIVE_NAME="${PACKAGE_ARCHIVE_NAME:-$DEFAULT_ARCHIVE_NAME}"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
MANIFEST_PATH="$ARCHIVE_PATH.manifest.json"
SOURCE_COMMIT="$(git -C "$PROJECT_DIR" rev-parse HEAD)"
SOURCE_REF="${GITHUB_REF_NAME:-$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)}"
GENERATED_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$ARCHIVE_NAME" in
  *.zip) ;;
  *) echo "ERROR: PACKAGE_ARCHIVE_NAME must end with .zip" >&2; exit 2 ;;
esac

command -v zip >/dev/null 2>&1 || { echo "ERROR: zip is required." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum is required." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required." >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

# Repository scan happens before any package bytes are created.
python3 "$SCANNER" repo

cd "$PARENT_DIR"
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH" "$MANIFEST_PATH"

# -X strips extra ZIP metadata. Runtime secrets, private keys, caches and prior
# package artifacts are excluded explicitly. The resulting archive is scanned
# again before a checksum is issued.
LC_ALL=C zip -X -r "$ARCHIVE_PATH" "$PROJECT_NAME" \
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
     "*/.mypy_cache/*" \
     "*/.ruff_cache/*" \
     "*/.git/*" \
     "*/.ssh/*" \
     "*/id_rsa" \
     "*/id_rsa.*" \
     "*/id_ed25519" \
     "*/id_ed25519.*" \
     "*/evidence/logs/*" \
     "*/artifacts/*" \
     "*/dist/*" \
     "*/build/*" \
     "*/mediafiles/*" \
     "*/.DS_Store" \
     "*.pem" \
     "*.key" \
     "*.log" \
     "*.pid" \
     "*.zip" \
     "*.zip.sha256" \
     "*.zip.manifest.json"

python3 "$SCANNER" archive "$ARCHIVE_PATH"

(
  cd "$OUTPUT_DIR"
  sha256sum "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

ARCHIVE_SHA256="$(awk '{print $1}' "$CHECKSUM_PATH")"
ARCHIVE_SIZE_BYTES="$(python3 -c 'import os,sys; print(os.path.getsize(sys.argv[1]))' "$ARCHIVE_PATH")"

python3 - "$MANIFEST_PATH" "$PROJECT_NAME" "$ARCHIVE_NAME" "$ARCHIVE_SHA256" "$ARCHIVE_SIZE_BYTES" "$SOURCE_COMMIT" "$SOURCE_REF" "$GENERATED_AT_UTC" <<'PY'
import json
import sys
from pathlib import Path

(
    manifest_path,
    project_name,
    archive_name,
    archive_sha256,
    archive_size_bytes,
    source_commit,
    source_ref,
    generated_at_utc,
) = sys.argv[1:]

payload = {
    "schema_version": 1,
    "project": project_name,
    "archive": archive_name,
    "sha256": archive_sha256,
    "size_bytes": int(archive_size_bytes),
    "source_commit": source_commit,
    "source_ref": source_ref,
    "generated_at_utc": generated_at_utc,
}
Path(manifest_path).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

# Scan the sidecar metadata too. The archive itself has already passed archive mode.
python3 "$SCANNER" tree "$CHECKSUM_PATH"
python3 "$SCANNER" tree "$MANIFEST_PATH"

printf 'Archive: %s\nChecksum: %s\nManifest: %s\n' \
  "$ARCHIVE_PATH" "$CHECKSUM_PATH" "$MANIFEST_PATH"
cat "$CHECKSUM_PATH"
