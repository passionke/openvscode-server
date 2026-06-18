#!/usr/bin/env bash
# 编译 openvscode-server reh-web（本机 Mac arm64）。Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

export PATH="/opt/homebrew/opt/node@22/bin:${PATH}"
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export npm_config_registry="${NPM_REGISTRY:-https://registry.npmmirror.com}"

ARCH="$(uname -m)"
case "${ARCH}" in
  arm64) VSCODE_ARCH=arm64; PLATFORM=darwin ;;
  x86_64) VSCODE_ARCH=x64; PLATFORM=darwin ;;
  *) echo "unsupported: ${ARCH}" >&2; exit 1 ;;
esac

OUT_NAME="vscode-reh-web-${PLATFORM}-${VSCODE_ARCH}"
BUILD_ROOT="$(dirname "${ROOT}")"
OUT="${BUILD_ROOT}/${OUT_NAME}"
VER="$(node -p "require('./package.json').version")"

log() { echo ""; echo ">>> [$1] $(date '+%H:%M:%S')"; }

log "OVS build ${VER} ${PLATFORM}-${VSCODE_ARCH} (node $(node -v))"

if [[ ! -d node_modules ]]; then
  log "npm install build/"
  (cd build && npm ci)
  log "preinstall"
  node build/npm/preinstall.ts
  log "npm ci root (慢，约 10-30 分钟)"
  npm ci
fi

log "gulp core-ci"
npm run gulp core-ci

log "gulp extensions-ci"
npm run gulp extensions-ci

log "gulp minify-vscode-reh-web"
DISABLE_V8_COMPILE_CACHE=1 npm run gulp minify-vscode-reh-web

log "gulp vscode-reh-web-${PLATFORM}-${VSCODE_ARCH}-min-ci"
DISABLE_V8_COMPILE_CACHE=1 npm run gulp "vscode-reh-web-${PLATFORM}-${VSCODE_ARCH}-min-ci"

[[ -d "${OUT}" ]] || { echo "missing ${OUT}" >&2; exit 1; }
log "DONE → ${OUT}"
echo "${OUT}/bin/openvscode-server --version:"
"${OUT}/bin/openvscode-server" --version 2>/dev/null || true
