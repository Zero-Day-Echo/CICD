#!/usr/bin/env bash
# 根据 Git tag 构建镜像，导出 tar.gz 并上传阿里云 OSS。
# 用法:
#   ./Builder/scripts/release.sh appbackend-v061201
#   ./Builder/scripts/release.sh all-v061201        # 全量；版本 v[mmdd][no]
#   GIT_TAG=all-v061201 ./Builder/scripts/release.sh
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

[[ -n "$TAG" ]] || die "请提供 tag，例如 appbackend-v061201 或 all-v061201"

build_one() {
  local project_key="$1"
  local version="$2"
  local image_ref="$3"
  local context_rel="$4"
  local dockerfile_rel="$5"

  local context="${ROOT}/${context_rel}"
  local dockerfile_path="${context}/${dockerfile_rel}"
  [[ -d "$context" ]] || die "构建上下文不存在: ${context}"
  [[ -f "$dockerfile_path" ]] || die "Dockerfile 不存在: ${dockerfile_path}"

  local archive_name="${project_key}-${version}.tar.gz"
  local archive_path="${DIST_DIR}/${archive_name}"
  mkdir -p "$DIST_DIR"

  log "project=${project_key} image=${image_ref}"
  local platform="${DOCKER_PLATFORM:-}"
  if [[ -n "$platform" ]]; then
    log "docker build --platform ${platform} -f ${dockerfile_path} -t ${image_ref} ${context}"
    docker build --platform "$platform" -f "$dockerfile_path" -t "$image_ref" "$context"
  else
    log "docker build -f ${dockerfile_path} -t ${image_ref} ${context}"
    docker build -f "$dockerfile_path" -t "$image_ref" "$context"
  fi

  log "导出镜像 → ${archive_path}"
  rm -f "$archive_path"
  docker save "$image_ref" | gzip -9 > "$archive_path"
  ls -lh "$archive_path"

  if [[ "$SKIP_UPLOAD" == "1" ]]; then
    log "SKIP_UPLOAD=1，跳过 OSS 上传: ${project_key}"
    return 0
  fi

  "${BUILDER}/scripts/upload_oss.sh" "$archive_path" "$project_key" "$version"
  log "完成: ${image_ref} → OSS"
}

release_all() {
  local matrix_json
  matrix_json="$("${BUILDER}/scripts/parse_release_matrix.py" "$TAG")" || exit 1
  local count
  count="$(echo "$matrix_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  log "全量构建 tag=${TAG}，共 ${count} 个子项目"

  while IFS=$'\t' read -r project_key version image_ref context_rel dockerfile_rel; do
    log "===== ${project_key}-${version} ====="
    build_one "$project_key" "$version" "$image_ref" "$context_rel" "$dockerfile_rel"
  done < <(
    echo "$matrix_json" | python3 -c '
import json, sys
for item in json.load(sys.stdin):
    print("\t".join([
        item["project_key"],
        item["version"],
        item["image_ref"],
        item["context"],
        item["dockerfile"],
    ]))
'
  )
}

main() {
  require_cmd docker
  require_cmd python3

  local parsed mode
  parsed="$("${BUILDER}/scripts/parse_tag.py" "$TAG")" || exit 1
  mode="$(echo "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin)["mode"])')"

  if [[ "$mode" == "all" ]]; then
    release_all
    log "全量构建完成: ${TAG}"
    return 0
  fi

  build_one \
    "$(echo "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin)["project_key"])')" \
    "$(echo "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')" \
    "$(echo "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin)["image_ref"])')" \
    "$(echo "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin)["context"])')" \
    "$(echo "$parsed" | python3 -c 'import json,sys; print(json.load(sys.stdin)["dockerfile"])')"
}

main "$@"
