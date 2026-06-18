#!/usr/bin/env bash
# Download linux-arm64 CI artifact from a GitHub Actions run. Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

RUN_ID="${1:-}"
REPO="${GITHUB_REPO:-passionke/openvscode-server}"
ARTIFACT="${ARTIFACT:-linux-arm64}"

die() { echo "ERROR: $*" >&2; exit 1; }
command -v gh >/dev/null || die "gh CLI not found"

if [[ -z "${RUN_ID}" ]]; then
  RUN_ID="$(gh run list --repo "${REPO}" --workflow=ovs-chat-linux-build.yml --status=success --limit 1 --json databaseId -q '.[0].databaseId')"
  [[ -n "${RUN_ID}" && "${RUN_ID}" != "null" ]] || die "no successful linux build run; pass RUN_ID or trigger workflow first"
  echo "Using latest successful run: ${RUN_ID}"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

gh run download "${RUN_ID}" --repo "${REPO}" -n "${ARTIFACT}" -D "${TMP}"

cp "${TMP}"/openvscode-server-v*-linux-arm64.tar.gz ./
cp "${TMP}"/ovs-chat-demo.vsix .build/ovs-chat-demo.vsix 2>/dev/null || cp "${TMP}"/*.vsix .build/ovs-chat-demo.vsix

ls -lh openvscode-server-v*-linux-arm64.tar.gz .build/ovs-chat-demo.vsix
echo "Ready for: bash scripts/ovs-chat/push-acr.sh"
