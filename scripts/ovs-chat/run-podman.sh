#!/usr/bin/env bash
# Podman 一键构建并启动 OVS + ovs-chat-demo。Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}/scripts/ovs-chat"

RELEASE_ORG="${RELEASE_ORG:-gitpod-io}"
RELEASE_TAG="${RELEASE_TAG:-openvscode-server-v1.109.5}"

echo "==> package demo VSIX"
"${ROOT}/scripts/ovs-chat/package-ovs-extension-vsix.sh"

echo "==> podman compose build (RELEASE_ORG=${RELEASE_ORG} RELEASE_TAG=${RELEASE_TAG})"
RELEASE_ORG="${RELEASE_ORG}" RELEASE_TAG="${RELEASE_TAG}" \
  podman compose -f podman-compose.yml build \
    --build-arg RELEASE_ORG="${RELEASE_ORG}" \
    --build-arg RELEASE_TAG="${RELEASE_TAG}"

echo "==> podman compose up -d"
podman compose -f podman-compose.yml up -d

echo "==> smoke"
sleep 3
"${ROOT}/scripts/ovs-chat/verify-ovs-chat-demo.sh"

echo ""
echo "Open: http://127.0.0.1:13000/"
echo "E2E:  Chat → @demo ping → expect demo ok"
echo "Logs: podman logs -f ovs-chat-demo"
