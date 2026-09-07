#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
APP_DIR="$PROJECT_ROOT/django-app"
REGISTRY_PORT="${DC13_REGISTRY_PORT:-5005}"
REGISTRY_NAME="datascientest-dc13-registry-${GITHUB_RUN_ID:-local}-${RANDOM}"
SOURCE_IMAGE="datascientest-django:dc13-build-${GITHUB_SHA:-local}"
REGISTRY_REPOSITORY="127.0.0.1:${REGISTRY_PORT}/datascientest-django"
MUTABLE_REFERENCE="${REGISTRY_REPOSITORY}:dc13-${GITHUB_SHA:-local}"
REGISTRY_STARTED=false

cleanup() {
  set +e
  if [[ "$REGISTRY_STARTED" == "true" ]]; then
    docker rm -f "$REGISTRY_NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log() {
  printf '%s\n' "$*" >&2
}

log "== DC-13 immutable image preparation =="
docker info >/dev/null

log "Building application image outside Docker Compose"
docker build \
  --pull \
  --tag "$SOURCE_IMAGE" \
  --build-arg "APPLICATION_VERSION=0.13.0-stg-e2e" \
  --build-arg "APPLICATION_COMMIT=${GITHUB_SHA:-local}" \
  "$APP_DIR" >&2

log "Starting ephemeral localhost registry for immutable promotion"
docker run -d \
  --name "$REGISTRY_NAME" \
  -p "127.0.0.1:${REGISTRY_PORT}:5000" \
  registry:2 >/dev/null
REGISTRY_STARTED=true

for _ in $(seq 1 30); do
  if python3 - "$REGISTRY_PORT" <<'PY' >/dev/null 2>&1
import sys
import urllib.request

port = int(sys.argv[1])
with urllib.request.urlopen(f"http://127.0.0.1:{port}/v2/", timeout=1) as response:
    if response.status != 200:
        raise SystemExit(1)
PY
  then
    break
  fi
  sleep 1
done

python3 - "$REGISTRY_PORT" <<'PY' >/dev/null
import sys
import urllib.request

port = int(sys.argv[1])
with urllib.request.urlopen(f"http://127.0.0.1:{port}/v2/", timeout=2) as response:
    if response.status != 200:
        raise SystemExit("DC13_ARTIFACT_FAIL: local registry is not ready")
PY

docker tag "$SOURCE_IMAGE" "$MUTABLE_REFERENCE"
log "Pushing image to ephemeral registry to obtain a repository digest"
docker push "$MUTABLE_REFERENCE" >&2

IMMUTABLE_REFERENCE="$(
  docker image inspect "$MUTABLE_REFERENCE" \
    --format '{{range .RepoDigests}}{{println .}}{{end}}' \
  | grep -E "^127\\.0\\.0\\.1:${REGISTRY_PORT}/datascientest-django@sha256:[0-9a-f]{64}$" \
  | head -n 1
)"

if [[ -z "$IMMUTABLE_REFERENCE" ]]; then
  log "Repository digest not attached yet; refreshing local registry metadata"
  docker pull "$MUTABLE_REFERENCE" >&2
  IMMUTABLE_REFERENCE="$(
    docker image inspect "$MUTABLE_REFERENCE" \
      --format '{{range .RepoDigests}}{{println .}}{{end}}' \
    | grep -E "^127\\.0\\.0\\.1:${REGISTRY_PORT}/datascientest-django@sha256:[0-9a-f]{64}$" \
    | head -n 1
  )"
fi

if ! [[ "$IMMUTABLE_REFERENCE" =~ @sha256:[0-9a-f]{64}$ ]]; then
  log "DC13_ARTIFACT_FAIL: immutable repository digest was not produced"
  exit 1
fi

log "Removing promotion registry before STG-like deployment"
docker rm -f "$REGISTRY_NAME" >/dev/null
REGISTRY_STARTED=false

if ! docker image inspect "$IMMUTABLE_REFERENCE" >/dev/null 2>&1; then
  log "DC13_ARTIFACT_FAIL: digest-pinned image is not locally resolvable after registry removal"
  exit 1
fi

log "DC13_ARTIFACT_PASS: image built once, promoted, digest-pinned and locally resolvable"
printf '%s\n' "$IMMUTABLE_REFERENCE"
