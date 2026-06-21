#!/usr/bin/env bash
# 上传构建产物到阿里云 OSS。
# 对象路径: {OSS_PREFIX}/{project}/{version}/{filename}
set -euo pipefail

ARCHIVE_PATH="${1:?archive path}"
PROJECT_KEY="${2:?project key}"
VERSION="${3:?version}"

OSS_ENDPOINT="${OSS_ENDPOINT:?请设置 OSS_ENDPOINT，例如 oss-cn-hangzhou.aliyuncs.com}"
OSS_BUCKET="${OSS_BUCKET:?请设置 OSS_BUCKET}"
OSS_ACCESS_KEY_ID="${OSS_ACCESS_KEY_ID:?请设置 OSS_ACCESS_KEY_ID}"
OSS_ACCESS_KEY_SECRET="${OSS_ACCESS_KEY_SECRET:?请设置 OSS_ACCESS_KEY_SECRET}"
OSS_PREFIX="${OSS_PREFIX:-aiexam}"
[[ -n "$OSS_PREFIX" ]] || OSS_PREFIX="aiexam"

FILENAME="$(basename "$ARCHIVE_PATH")"
OBJECT_KEY="${OSS_PREFIX%/}/${PROJECT_KEY}/${VERSION}/${FILENAME}"

log() { echo "[builder/oss] $*"; }
die() { echo "[builder/oss] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1（CI 中可安装 ossutil64）"
}

require_cmd ossutil

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

DEST="oss://${OSS_BUCKET}/${OBJECT_KEY}"
log "上传 ${ARCHIVE_PATH} → ${DEST}"
ossutil cp -f "$ARCHIVE_PATH" "$DEST" -c "$CFG"

log "上传成功: ${DEST}"

if [[ "${OSS_CLEANUP_OLD:-1}" != "0" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  OSSUTIL_CONFIG="$CFG" "${SCRIPT_DIR}/cleanup_oss_images.sh" "$PROJECT_KEY" "$VERSION"
fi
