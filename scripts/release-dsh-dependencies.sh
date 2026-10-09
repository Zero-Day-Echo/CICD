#!/usr/bin/env bash
# Build/export DSH and distribute via the existing OSS uploader. Never deploys.
# SKIP_UPLOAD=1 is for local build checks only. OpenViking uses its official image.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${DSH_SOURCE_DIR:?Path to checked-out dsh-agent-api repository}"
: "${VERSION:?Image version, e.g. v100801}"
[[ "$VERSION" =~ ^v[0-9A-Za-z.]+$ ]] || exit 2
DSH_COMMIT=b24647c6217cfaa5122cb034883bef8f51d668f9
DIST_DIR="${DIST_DIR:-$ROOT/Builder/dist}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
git -C "$DSH_SOURCE_DIR" cat-file -e "$DSH_COMMIT^{commit}"
mkdir -p "$DIST_DIR"
archive="$DIST_DIR/dsh-agent-api-$VERSION.tar.gz"
[[ ! -e "$archive" ]] || { echo "Refusing to overwrite $archive" >&2; exit 1; }
# Archive the pinned commit, excluding any uncommitted local files or secrets.
docker build --platform "$PLATFORM" -t "dsh-agent-api:$VERSION" - \
  < <(git -C "$DSH_SOURCE_DIR" archive "$DSH_COMMIT")
docker save "dsh-agent-api:$VERSION" | gzip > "$archive"
shasum -a 256 "$archive"
if [[ "${SKIP_UPLOAD:-0}" == 0 ]]; then
  bash "$ROOT/Builder/scripts/upload_oss.sh" "$archive" dsh-agent-api "$VERSION"
fi
