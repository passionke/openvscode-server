#!/usr/bin/env bash
# Package linux reh-web from compile cache (Mac), tarball, push ACR. Author: kejiqing
# Usage: bash scripts/ovs-chat/build-linux-push-acr.sh [arm64|x64]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

VSCODE_ARCH="${1:-arm64}"
case "${VSCODE_ARCH}" in
  arm64|x64) ;;
  amd64|x86_64) VSCODE_ARCH=x64 ;;
  *) echo "unsupported arch: ${VSCODE_ARCH}" >&2; exit 1 ;;
esac

export PATH="/opt/homebrew/opt/node@22/bin:${PATH}"
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export npm_config_registry="${NPM_REGISTRY:-https://registry.npmmirror.com}"

VERSION="$(node -p "require('./package.json').version")"
NAME="openvscode-server-v${VERSION}-linux-${VSCODE_ARCH}"
PKG_DIR="../vscode-reh-web-linux-${VSCODE_ARCH}"

log() { echo ""; echo ">>> $*"; }

[[ -d node_modules ]] || { log "need node_modules — run build-ovs.sh once first"; exit 1; }
[[ -d out-build ]] || { log "need out-build — run build-ovs.sh once first"; exit 1; }

log "package ovs-chat-demo VSIX"
bash scripts/ovs-chat/package-ovs-extension-vsix.sh

log "gulp minify-vscode-reh-web"
DISABLE_V8_COMPILE_CACHE=1 npm run gulp minify-vscode-reh-web

log "gulp vscode-reh-web-linux-${VSCODE_ARCH}-min-ci"
DISABLE_V8_COMPILE_CACHE=1 npm run gulp "vscode-reh-web-linux-${VSCODE_ARCH}-min-ci"

[[ -d "${PKG_DIR}" ]] || [[ -d "../${NAME}" ]] || { echo "missing ${PKG_DIR}" >&2; exit 1; }

log "tarball ${NAME}.tar.gz"
rm -f "${NAME}.tar.gz"
if [[ -d "${PKG_DIR}" ]]; then
  rm -rf "../${NAME}"
  mv "${PKG_DIR}" "../${NAME}"
fi
export COPYFILE_DISABLE=1
tar -czf "${NAME}.tar.gz" -C .. "${NAME}"

log "push ACR (${VSCODE_ARCH})"
VSCODE_ARCH="${VSCODE_ARCH}" TARBALL="${NAME}.tar.gz" bash scripts/ovs-chat/push-acr.sh
