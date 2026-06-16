#!/usr/bin/env bash
# 删除 OSS 上同一子项目的旧版本目录，仅保留 KEEP_VERSION。
# 对象布局: {OSS_PREFIX}/{project}/{version}/{project}-{version}.tar.gz
#
# 用法:
#   OSSUTIL_CONFIG=/tmp/oss.cfg ./cleanup_oss_images.sh <project_key> <keep_version>
#
# 环境变量:
#   OSS_CLEANUP_DRY_RUN=1  只打印将删除的路径，不执行 rm
set -euo pipefail

PROJECT_KEY="${1:?project key}"
KEEP_VERSION="${2:?keep version}"

OSS_ENDPOINT="${OSS_ENDPOINT:?OSS_ENDPOINT}"
OSS_BUCKET="${OSS_BUCKET:?OSS_BUCKET}"
OSS_ACCESS_KEY_ID="${OSS_ACCESS_KEY_ID:?OSS_ACCESS_KEY_ID}"
OSS_ACCESS_KEY_SECRET="${OSS_ACCESS_KEY_SECRET:?OSS_ACCESS_KEY_SECRET}"
OSS_PREFIX="${OSS_PREFIX:-aiexam/docker-images}"
[[ -n "$OSS_PREFIX" ]] || OSS_PREFIX="aiexam/docker-images"

log() { echo "[builder/oss-cleanup] $*"; }
warn() { echo "[builder/oss-cleanup] WARN: $*" >&2; }
die() { echo "[builder/oss-cleanup] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

is_version_dir() {
  [[ "$1" =~ ^v[0-9A-Za-z.]+$ ]]
}

require_cmd ossutil

CFG="${OSSUTIL_CONFIG:-}"
if [[ -z "$CFG" || ! -f "$CFG" ]]; then
  CFG="$(mktemp)"
  trap 'rm -f "$CFG"' EXIT
  cat >"$CFG" <<EOF
[Credentials]
language=CH
endpoint=${OSS_ENDPOINT}
accessKeyID=${OSS_ACCESS_KEY_ID}
accessKeySecret=${OSS_ACCESS_KEY_SECRET}
EOF
  chmod 600 "$CFG"
fi

PROJECT_PREFIX="${OSS_PREFIX%/}/${PROJECT_KEY}/"
PROJECT_URI="oss://${OSS_BUCKET}/${PROJECT_PREFIX}"

log "扫描 ${PROJECT_URI}，保留 ${KEEP_VERSION}"

listing="$(ossutil ls "${PROJECT_URI}" -d --short -c "$CFG" 2>/dev/null || true)"
if [[ -z "${listing// }" ]]; then
  log "无历史版本目录，跳过清理"
  exit 0
fi

deleted=0
while IFS= read -r line; do
  [[ -z "${line// }" ]] && continue
  version="${line%/}"
  version="${version##*/}"
  [[ -z "$version" ]] && continue
  is_version_dir "$version" || continue
  [[ "$version" == "$KEEP_VERSION" ]] && continue

  old_uri="${PROJECT_URI}${version}/"
  if [[ "${OSS_CLEANUP_DRY_RUN:-0}" == "1" ]]; then
    log "[dry-run] 将删除 ${old_uri}"
    deleted=$((deleted + 1))
    continue
  fi

  log "删除旧版本 ${old_uri}"
  ossutil rm -r -f "${old_uri}" -c "$CFG"
  deleted=$((deleted + 1))
done <<<"$listing"

if [[ "$deleted" -eq 0 ]]; then
  log "无需清理（仅存在 ${KEEP_VERSION} 或无其它版本目录）"
else
  log "已清理 ${PROJECT_KEY} 下 ${deleted} 个旧版本目录"
fi
