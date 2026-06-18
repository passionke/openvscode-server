#!/usr/bin/env bash
# 跑自编译 OVS + ovs-chat-demo。Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="$(uname -m)"
case "${ARCH}" in arm64) VSCODE_ARCH=arm64; PLATFORM=darwin ;; x86_64) VSCODE_ARCH=x64; PLATFORM=darwin ;; esac

BUILD_ROOT="$(dirname "${ROOT}")"
REH="${BUILD_ROOT}/vscode-reh-web-${PLATFORM}-${VSCODE_ARCH}"
OVS_BIN="${REH}/bin/openvscode-server"
EXT_DIR="${ROOT}/.build/ovs-extensions"
SD="${ROOT}/.build/ovs-server-data"
PORT="${OVS_PORT:-3100}"
WORKSPACE="${OVS_WORKSPACE:-${ROOT}/.build/ovs-workspace}"

[[ -x "${OVS_BIN}" ]] || { echo "先编译: bash scripts/ovs-chat/build-ovs.sh" >&2; exit 1; }

mkdir -p "${EXT_DIR}" "${SD}/Machine" "${WORKSPACE}"
cp -f "${ROOT}/scripts/ovs-chat/openvscode-settings.json" "${SD}/Machine/settings.json"
"${ROOT}/scripts/ovs-chat/package-ovs-extension-vsix.sh"
VSIX="${ROOT}/.build/ovs-chat-demo.vsix"

HOME="${ROOT}/.build/ovs-home"
mkdir -p "${HOME}"
export HOME

"${OVS_BIN}" --install-extension "${VSIX}" --extensions-dir="${EXT_DIR}" --server-data-dir="${SD}" --force 2>/dev/null || true

echo ">>> http://127.0.0.1:${PORT}/  Chat → @demo ping"
exec "${OVS_BIN}" \
  --host=127.0.0.1 --port="${PORT}" --without-connection-token \
  --extensions-dir="${EXT_DIR}" --server-data-dir="${SD}" \
  --enable-proposed-api=claw.ovs-chat-demo \
  "${WORKSPACE}"
