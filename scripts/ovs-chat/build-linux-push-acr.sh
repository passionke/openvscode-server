#!/usr/bin/env bash
# Package linux-arm64 reh-web from existing compile cache (Mac), then push-acr. Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

export PATH="/opt/homebrew/opt/node@22/bin:${PATH}"
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export npm_config_registry="${NPM_REGISTRY:-https://registry.npmmirror.com}"

VERSION="$(node -p "require('./package.json').version")"
NAME="openvscode-server-v${VERSION}-linux-arm64"

log() { echo ""; echo ">>> $*"; }

[[ -d node_modules ]] || { log "need node_modules — run build-ovs.sh once first"; exit 1; }
[[ -d out-build ]] || { log "need out-build — run build-ovs.sh once first"; exit 1; }

log "package ovs-chat-demo VSIX"
bash scripts/ovs-chat/package-ovs-extension-vsix.sh

log "gulp minify-vscode-reh-web"
DISABLE_V8_COMPILE_CACHE=1 npm run gulp minify-vscode-reh-web

log "gulp vscode-reh-web-linux-arm64-min-ci"
DISABLE_V8_COMPILE_CACHE=1 npm run gulp vscode-reh-web-linux-arm64-min-ci

[[ -d ../vscode-reh-web-linux-arm64 ]] || [[ -d "../${NAME}" ]] || { echo "missing linux-arm64 package dir" >&2; exit 1; }

log "tarball ${NAME}.tar.gz"
rm -f "${NAME}.tar.gz"
if [[ -d ../vscode-reh-web-linux-arm64 ]]; then
  rm -rf "../${NAME}"
  mv ../vscode-reh-web-linux-arm64 "../${NAME}"
fi
export COPYFILE_DISABLE=1
tar -czf "${NAME}.tar.gz" -C .. "${NAME}"

log "push ACR"
TARBALL="${NAME}.tar.gz" bash scripts/ovs-chat/push-acr.sh
