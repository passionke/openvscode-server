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
die() { echo "ERROR: $*" >&2; exit 1; }

case "${VSCODE_ARCH}" in
  arm64) PLATFORM="${PLATFORM:-linux/arm64}"; DEFAULT_TAG="${VERSION}-ovs-chat" ;;
  x64)   PLATFORM="${PLATFORM:-linux/amd64}"; DEFAULT_TAG="${VERSION}-ovs-chat-amd64" ;;
  *) die "unsupported VSCODE_ARCH: ${VSCODE_ARCH}" ;;
esac
TAG="${TAG:-${DEFAULT_TAG}}"
TARBALL="${TARBALL:-openvscode-server-v${VERSION}-linux-${VSCODE_ARCH}.tar.gz}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${TAG}"

command -v podman >/dev/null || die "podman not found"

if podman login --get-login "${ACR_REGISTRY}" >/dev/null 2>&1; then
  echo ">>> podman already logged in as $(podman login --get-login "${ACR_REGISTRY}")"
else
  [[ -n "${ACR_USERNAME:-}" && -n "${ACR_PASSWORD:-}" ]] || die "podman not logged in; set ACR_USERNAME and ACR_PASSWORD"
  echo ">>> podman login ${ACR_REGISTRY}"
  echo "${ACR_PASSWORD}" | podman login "${ACR_REGISTRY}" -u "${ACR_USERNAME}" --password-stdin
fi
[[ -f "${TARBALL}" ]] || die "missing tarball: ${TARBALL}"

validate_native_addons() {
  local tmp expected bad_count
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  tar -xzf "${TARBALL}" -C "${tmp}"
  case "${VSCODE_ARCH}" in
    arm64) expected='ELF 64-bit LSB.*ARM aarch64' ;;
    x64) expected='ELF 64-bit LSB.*x86-64' ;;
  esac

  bad_count=0
  while IFS= read -r -d '' addon; do
    case "${addon}" in
      */windows.node|*win32-*) continue ;;
    esac
    if ! file "${addon}" | grep -Eq "${expected}"; then
      echo "bad native addon: ${addon#${tmp}/}"
      file "${addon}"
      bad_count=$((bad_count + 1))
    fi
  done < <(find "${tmp}" -name '*.node' -print0)

  [[ "${bad_count}" -eq 0 ]] || die "native addon validation failed for ${VSCODE_ARCH}"
}

echo ">>> validate native addons (${VSCODE_ARCH})"
validate_native_addons

if [[ ! -f .build/ovs-chat-demo.vsix ]]; then
  bash scripts/ovs-chat/package-ovs-extension-vsix.sh
fi

echo ">>> podman build ${PLATFORM} ${FULL_IMAGE} (no cache)"
podman build --no-cache --platform "${PLATFORM}" \
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
