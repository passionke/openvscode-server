#!/usr/bin/env bash
# Build linux reh-web inside a Linux container so native .node addons are ELF. Author: kejiqing
# Usage: bash scripts/ovs-chat/build-linux-in-podman.sh [arm64|x64]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

VSCODE_ARCH="${1:-arm64}"
case "${VSCODE_ARCH}" in
  arm64) PLATFORM=linux/arm64; NPM_ARCH=arm64 ;;
  x64|amd64|x86_64) VSCODE_ARCH=x64; PLATFORM=linux/amd64; NPM_ARCH=x64 ;;
  *) echo "unsupported arch: ${VSCODE_ARCH}" >&2; exit 1 ;;
esac

IMAGE="${BUILD_IMAGE:-docker.1ms.run/buildpack-deps:22.04-curl}"
NAME="ovs-linux-build-${VSCODE_ARCH}"
SRC_TAR="$(mktemp -t ovs-src.XXXXXX.tar)"
OUT_DIR="/tmp/ovs-build-out-${VSCODE_ARCH}"

cleanup() {
  rm -f "${SRC_TAR}"
  rm -rf "${OUT_DIR}"
}
trap cleanup EXIT

echo ">>> removing old container ${NAME}"
podman rm -f "${NAME}" >/dev/null 2>&1 || true

echo ">>> archive source"
export COPYFILE_DISABLE=1
tar \
  --exclude=.git \
  --exclude=node_modules \
  --exclude=out \
  --exclude=out-build \
  --exclude=.build \
  --exclude="openvscode-server-v*.tar.gz" \
  -cf "${SRC_TAR}" .

echo ">>> create ${PLATFORM} container in ${IMAGE}"
podman create --name "${NAME}" --platform "${PLATFORM}" \
  -e VSCODE_ARCH="${VSCODE_ARCH}" \
  -e NPM_ARCH="${NPM_ARCH}" \
  -e npm_config_arch="${NPM_ARCH}" \
  -e NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}" \
  -e PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
  -e ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
  -e DISABLE_V8_COMPILE_CACHE=1 \
  "${IMAGE}" \
  bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg pkg-config dbus xvfb libgtk-3-0 libxkbfile-dev libkrb5-dev libgbm1 python3 make g++ jq patch
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y --no-install-recommends nodejs
apt-get install -y --no-install-recommends python-is-python3 || ln -sf python3 /usr/bin/python
node --version
npm --version

mkdir -p /work
tar -C /work -xf /tmp/ovs-src.tar

cd /work
export npm_config_arch="${NPM_ARCH}"
export VSCODE_ARCH="${VSCODE_ARCH}"
npm config set registry "${NPM_REGISTRY}"
cd build && npm ci && cd ..
source ./build/azure-pipelines/linux/setup-env.sh
node build/npm/preinstall.ts
npm ci

npm run gulp core-ci
npm run gulp extensions-ci
npm run gulp minify-vscode-reh-web
npm run gulp "vscode-reh-web-linux-${VSCODE_ARCH}-min-ci"

chmod +x scripts/ovs-chat/package-ovs-extension-vsix.sh
bash scripts/ovs-chat/package-ovs-extension-vsix.sh

version="$(node -p "require(\"./package.json\").version")"
pkg="openvscode-server-v${version}-linux-${VSCODE_ARCH}"
mv "vscode-reh-web-linux-${VSCODE_ARCH}" "${pkg}"
mkdir -p /tmp/ovs-out/.build
tar -czf "/tmp/ovs-out/${pkg}.tar.gz" "${pkg}"
cp .build/ovs-chat-demo.vsix /tmp/ovs-out/.build/ovs-chat-demo.vsix
echo "DONE ${pkg}.tar.gz"
'

echo ">>> copy source into container"
podman cp "${SRC_TAR}" "${NAME}:/tmp/ovs-src.tar"

echo ">>> start build"
podman start -a "${NAME}"

echo ">>> copy artifacts out"
mkdir -p "${OUT_DIR}"
podman cp "${NAME}:/tmp/ovs-out/." "${OUT_DIR}/"
cp "${OUT_DIR}"/openvscode-server-v*-linux-"${VSCODE_ARCH}".tar.gz "${ROOT}/"
mkdir -p "${ROOT}/.build"
cp "${OUT_DIR}/.build/ovs-chat-demo.vsix" "${ROOT}/.build/ovs-chat-demo.vsix"

echo ">>> done: openvscode-server-v$(node -p "require('./package.json').version")-linux-${VSCODE_ARCH}.tar.gz"
