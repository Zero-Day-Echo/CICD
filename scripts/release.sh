#!/usr/bin/env bash
# 根据 Git tag 构建单个子项目镜像，导出 tar.gz 并上传阿里云 OSS。
# 用法: ./Builder/scripts/release.sh <tag>   或   GIT_TAG=appbackend-v0615 ./Builder/scripts/release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-${GIT_TAG:-}}"
DIST_DIR="${DIST_DIR:-${BUILDER}/dist}"
SKIP_UPLOAD="${SKIP_UPLOAD:-0}"

log() { echo "[builder] $*"; }
die() { echo "[builder] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

[[ -n "$TAG" ]] || die "请提供 tag，例如 appbackend-v0615"

PARSED="$("${BUILDER}/scripts/parse_tag.py" "$TAG")" || exit 1
PROJECT_KEY="$(echo "$PARSED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["project_key"])')"
VERSION="$(echo "$PARSED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
IMAGE_REF="$(echo "$PARSED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["image_ref"])')"
CONTEXT_REL="$(echo "$PARSED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["context"])')"
DOCKERFILE_REL="$(echo "$PARSED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["dockerfile"])')"

CONTEXT="${ROOT}/${CONTEXT_REL}"
DOCKERFILE_PATH="${CONTEXT}/${DOCKERFILE_REL}"
[[ -d "$CONTEXT" ]] || die "构建上下文不存在: ${CONTEXT}"
[[ -f "$DOCKERFILE_PATH" ]] || die "Dockerfile 不存在: ${DOCKERFILE_PATH}"

ARCHIVE_NAME="${PROJECT_KEY}-${VERSION}.tar.gz"
ARCHIVE_PATH="${DIST_DIR}/${ARCHIVE_NAME}"
mkdir -p "$DIST_DIR"

log "tag=${TAG} project=${PROJECT_KEY} image=${IMAGE_REF}"
log "docker build -f ${DOCKERFILE_PATH} -t ${IMAGE_REF} ${CONTEXT}"
docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_REF" "$CONTEXT"

log "导出镜像 → ${ARCHIVE_PATH}"
rm -f "$ARCHIVE_PATH"
docker save "$IMAGE_REF" | gzip -9 > "$ARCHIVE_PATH"
ls -lh "$ARCHIVE_PATH"

if [[ "$SKIP_UPLOAD" == "1" ]]; then
  log "SKIP_UPLOAD=1，跳过 OSS 上传"
  exit 0
fi

"${BUILDER}/scripts/upload_oss.sh" "$ARCHIVE_PATH" "$PROJECT_KEY" "$VERSION"
log "完成: ${IMAGE_REF} → OSS"
