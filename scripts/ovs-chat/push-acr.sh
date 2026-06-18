#!/usr/bin/env bash
# Build linux/arm64 image from CI tarball + push to Aliyun ACR. Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

ACR_REGISTRY="${ACR_REGISTRY:-crpi-cf9vxpq3n8or17mw.cn-hangzhou.personal.cr.aliyuncs.com}"
ACR_NAMESPACE="${ACR_NAMESPACE:-passionke}"
IMAGE_NAME="${IMAGE_NAME:-openvscode-server}"
VERSION="$(node -p "require('./package.json').version")"
VSCODE_ARCH="${VSCODE_ARCH:-arm64}"
case "${VSCODE_ARCH}" in
  arm64) PLATFORM="${PLATFORM:-linux/arm64}"; DEFAULT_TAG="${VERSION}-ovs-chat" ;;
  x64)   PLATFORM="${PLATFORM:-linux/amd64}"; DEFAULT_TAG="${VERSION}-ovs-chat-amd64" ;;
  *) die "unsupported VSCODE_ARCH: ${VSCODE_ARCH}" ;;
esac
TAG="${TAG:-${DEFAULT_TAG}}"
TARBALL="${TARBALL:-openvscode-server-v${VERSION}-linux-${VSCODE_ARCH}.tar.gz}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${TAG}"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v podman >/dev/null || die "podman not found"

if podman login --get-login "${ACR_REGISTRY}" >/dev/null 2>&1; then
  echo ">>> podman already logged in as $(podman login --get-login "${ACR_REGISTRY}")"
else
  [[ -n "${ACR_USERNAME:-}" && -n "${ACR_PASSWORD:-}" ]] || die "podman not logged in; set ACR_USERNAME and ACR_PASSWORD"
  echo ">>> podman login ${ACR_REGISTRY}"
  echo "${ACR_PASSWORD}" | podman login "${ACR_REGISTRY}" -u "${ACR_USERNAME}" --password-stdin
fi
[[ -f "${TARBALL}" ]] || die "missing tarball: ${TARBALL}"

if [[ ! -f .build/ovs-chat-demo.vsix ]]; then
  bash scripts/ovs-chat/package-ovs-extension-vsix.sh
fi

echo ">>> podman build ${PLATFORM} ${FULL_IMAGE}"
podman build --platform "${PLATFORM}" \
  -f scripts/ovs-chat/Dockerfile.ci \
  --build-arg "TARBALL=${TARBALL}" \
  -t "${FULL_IMAGE}" \
  .

echo ">>> podman push ${FULL_IMAGE}"
podman push "${FULL_IMAGE}"

# optional rolling tag
if [[ -n "${ALSO_TAG:-}" ]]; then
  EXTRA="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${ALSO_TAG}"
  podman tag "${FULL_IMAGE}" "${EXTRA}"
  podman push "${EXTRA}"
  echo "ALSO: ${EXTRA}"
fi

echo ""
echo "DONE: ${FULL_IMAGE}"
echo "Pull: podman pull ${FULL_IMAGE}"
