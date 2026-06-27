#!/usr/bin/env bash
# Linux container build (correct ELF) + push ACR. Single entry. Author: kejiqing
# Usage: bash scripts/ovs-chat/build-and-push-acr.sh [arm64|x64] [tag-suffix]
# Example: bash scripts/ovs-chat/build-and-push-acr.sh x64 elf
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

ARCH="${1:-x64}"
TAG_SUFFIX="${2:-${TAG_SUFFIX:-elf}}"
case "${ARCH}" in
  x64|amd64|x86_64) ARCH=x64 ;;
  arm64) ;;
  *) echo "unsupported: ${ARCH}" >&2; exit 1 ;;
esac

bash scripts/ovs-chat/build-linux-in-podman.sh "${ARCH}"

VERSION="$(node -p "require('./package.json').version")"
case "${ARCH}" in
  x64) TAG="${VERSION}-ovs-chat-amd64-${TAG_SUFFIX}" ;;
  arm64) TAG="${VERSION}-ovs-chat-${TAG_SUFFIX}" ;;
esac

VSCODE_ARCH="${ARCH}" \
TAG="${TAG}" \
TARBALL="openvscode-server-v${VERSION}-linux-${ARCH}.tar.gz" \
bash scripts/ovs-chat/push-acr.sh
