#!/usr/bin/env bash
# DEPRECATED — Mac cache build produces Mach-O .node addons. Do not use for ACR.
# Author: kejiqing
set -euo pipefail
echo "ERROR: build-linux-push-acr.sh is deprecated (native addons would be Mach-O)." >&2
echo "Use: bash scripts/ovs-chat/build-and-push-acr.sh x64" >&2
exit 1
