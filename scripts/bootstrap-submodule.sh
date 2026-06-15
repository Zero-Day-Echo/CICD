#!/usr/bin/env bash
# 将 Builder/ 目录首次推送到 Zero-Day-Echo/CICD，并在 monorepo 注册为 submodule。
# 在 monorepo 根目录执行: ./Builder/scripts/bootstrap-submodule.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="${ROOT}/Builder"
REMOTE="${CICD_REMOTE:-git@github.com:Zero-Day-Echo/CICD.git}"

log() { echo "[bootstrap-cicd] $*"; }
die() { echo "[bootstrap-cicd] ERROR: $*" >&2; exit 1; }

[[ -d "$BUILDER" ]] || die "未找到 ${BUILDER}"

if [[ -f "${ROOT}/.gitmodules" ]] && grep -q 'path = Builder' "${ROOT}/.gitmodules"; then
  log ".gitmodules 已包含 Builder 子模块"
else
  die "请先在 .gitmodules 中配置 Builder → ${REMOTE}"
fi

if [[ -d "${BUILDER}/.git" ]]; then
  log "Builder 已是 git 仓库，跳过 init"
else
  log "初始化 Builder 并提交到 ${REMOTE}"
  git -C "$BUILDER" init -b main
  git -C "$BUILDER" add .
  git -C "$BUILDER" commit -m "feat: initial CICD docker build and OSS upload scripts"
  git -C "$BUILDER" remote add origin "$REMOTE" 2>/dev/null || git -C "$BUILDER" remote set-url origin "$REMOTE"
  git -C "$BUILDER" push -u origin main
fi

if git -C "$ROOT" config -f .gitmodules --get submodule.Builder.url >/dev/null 2>&1; then
  log "注册 monorepo 子模块指针（若尚未注册）"
  if ! git -C "$ROOT" ls-files --stage Builder | grep -q '^160000'; then
    git -C "$ROOT" submodule absorbgitdirs Builder 2>/dev/null || true
    git -C "$ROOT" submodule add --force "$REMOTE" Builder 2>/dev/null || {
      log "请手动执行: cd ${ROOT} && git submodule add ${REMOTE} Builder"
    }
  fi
fi

log "完成。克隆后请运行: git submodule update --init Builder"
