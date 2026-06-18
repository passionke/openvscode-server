#!/usr/bin/env bash
# Smoke-check ovs-chat-demo in a running OVS container. Author: kejiqing
set -euo pipefail

CONTAINER="${OVS_CONTAINER:-ovs-chat-demo}"
EXT_DIR="${OVS_EXT_DIR:-/opt/claw-extensions}"
SD="${OVS_SERVER_DATA:-/opt/claw-ovs/server-data}"
OVS_BIN="${OVS_BIN:-/home/.openvscode-server/bin/openvscode-server}"
PORT="${OVS_PORT:-13001}"
BASE_URL="${OVS_BASE_URL:-http://127.0.0.1:${PORT}/}"

fail() { echo "verify-ovs-chat-demo: $*" >&2; exit 1; }

podman container exists "${CONTAINER}" >/dev/null 2>&1 || fail "container ${CONTAINER} not running"

echo "==> list-extensions"
podman exec "${CONTAINER}" "${OVS_BIN}" \
  --list-extensions --extensions-dir="${EXT_DIR}" --server-data-dir="${SD}" \
  | grep -q '^claw\.ovs-chat-demo$' || fail "claw.ovs-chat-demo not installed"

echo "==> HTTP"
code="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}" 2>/dev/null || echo 000)"
[[ "${code}" == "200" || "${code}" == "302" ]] || fail "OVS HTTP ${code}"

echo "OK: ovs-chat-demo installed; HTTP ${code}"
echo "Manual E2E: Chat → @demo ping → expect demo ok (agent mode)"
echo "Logs: podman exec ${CONTAINER} sh -c 'tail -20 \$(ls -t ${SD}/data/logs/*/exthost*/remoteexthost.log | head -1)' | grep OVS-CHAT"
