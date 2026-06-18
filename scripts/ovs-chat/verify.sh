#!/usr/bin/env bash
# 前台逐步验证，每步都有输出。Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${OVS_PORT:-13001}"
CONTAINER="${OVS_CONTAINER:-ovs-chat-demo}"
BASE="http://127.0.0.1:${PORT}/"

step() { echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo "  $*"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

step "1/5 打包 demo VSIX"
"${ROOT}/scripts/ovs-chat/package-ovs-extension-vsix.sh"

step "2/5 容器 ${CONTAINER}"
podman ps --filter "name=${CONTAINER}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
if ! podman container exists "${CONTAINER}" 2>/dev/null; then
  echo "容器不存在。先跑: cd scripts/ovs-chat && podman compose up -d"
  exit 1
fi

step "3/5 已装扩展"
podman exec "${CONTAINER}" /home/.openvscode-server/bin/openvscode-server \
  --list-extensions --extensions-dir=/opt/claw-extensions --server-data-dir=/opt/claw-ovs/server-data

step "4/5 HTTP ${BASE}"
code="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE}")"
echo "HTTP ${code}"
[[ "${code}" == "200" || "${code}" == "302" ]] || exit 1

step "5/5 Demo Output 日志（需先浏览器打开过 ${BASE}）"
log="$(podman exec "${CONTAINER}" sh -c 'find /opt/claw-ovs -name "*OVS Chat Demo*" -type f 2>/dev/null | head -1' || true)"
if [[ -n "${log}" ]]; then
  podman exec "${CONTAINER}" cat "${log}"
else
  echo "(空) 请浏览器打开 ${BASE} 后再跑本脚本"
fi

echo ""
echo "手动 E2E: 打开 ${BASE} → Chat → @demo ping"
echo "成功标准: Output 出现 handler prompt=... 且 Chat 显示 demo ok"
