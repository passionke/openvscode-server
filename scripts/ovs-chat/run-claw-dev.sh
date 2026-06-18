#!/usr/bin/env bash
# 跑自编译 OVS + claw-vscode。Author: kejiqing
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
CLAW_CODE_ROOT="${CLAW_CODE_ROOT:-${HOME}/work/claw-code}"
SETTINGS_SRC="${CLAW_CODE_ROOT}/deploy/stack/openvscode-settings.json"
if [[ -f "${SETTINGS_SRC}" ]]; then
  cp -f "${SETTINGS_SRC}" "${SD}/Machine/settings.json"
else
  cp -f "${ROOT}/scripts/ovs-chat/openvscode-settings.json" "${SD}/Machine/settings.json"
fi
"${CLAW_CODE_ROOT}/deploy/stack/lib/package-ovs-extension-vsix.sh" \
  "${CLAW_CODE_ROOT}/extensions/claw-vscode" \
  "${ROOT}/.build/claw-vscode.vsix"
VSIX="${ROOT}/.build/claw-vscode.vsix"

HOME="${ROOT}/.build/ovs-home"
mkdir -p "${HOME}"
export HOME

"${OVS_BIN}" --install-extension "${VSIX}" --extensions-dir="${EXT_DIR}" --server-data-dir="${SD}" --force 2>/dev/null || true

echo ">>> http://127.0.0.1:${PORT}/  Chat → @claw ping"
exec "${OVS_BIN}" \
  --host=127.0.0.1 --port="${PORT}" --without-connection-token \
  --extensions-dir="${EXT_DIR}" --server-data-dir="${SD}" \
  --enable-proposed-api=claw.claw-vscode,claw.ovs-chat-demo \
  "${WORKSPACE}"
