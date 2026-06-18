#!/usr/bin/env bash
# Package extensions/ovs-chat-demo as VSIX. No node/npm required. Author: kejiqing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
usage() { echo "usage: $0 [extension-src-dir] [out.vsix]" >&2; exit 1; }

SRC_DIR="$(cd "${1:-${ROOT}/extensions/ovs-chat-demo}" && pwd)"
OUT_VSIX="${2:-${ROOT}/.build/ovs-chat-demo.vsix}"
mkdir -p "$(dirname "${OUT_VSIX}")"
OUT_VSIX="$(cd "$(dirname "${OUT_VSIX}")" && pwd)/$(basename "${OUT_VSIX}")"
[[ -f "${SRC_DIR}/package.json" ]] || usage

read -r VERSION EXT_ID PUBLISHER DISPLAY DESC < <(
  python3 - "${SRC_DIR}/package.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
print(p.get("version","0.1.0"), p["name"], p["publisher"],
      p.get("displayName", p["name"]), p.get("description",""))
PY
)

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}/extension"
cp -a "${SRC_DIR}/." "${work}/extension/"

cat >"${work}/extension.vsixmanifest" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="${EXT_ID}" Version="${VERSION}" Publisher="${PUBLISHER}" />
    <DisplayName>${DISPLAY}</DisplayName>
    <Description>${DESC}</Description>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
EOF

cat >"${work}/[Content_Types].xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
  <Default Extension="js" ContentType="application/javascript" />
  <Default Extension="xml" ContentType="text/xml" />
</Types>
EOF

rm -f "${OUT_VSIX}"
( cd "${work}" && zip -qr "${OUT_VSIX}" extension extension.vsixmanifest '[Content_Types].xml' )
echo "wrote ${OUT_VSIX}  (${EXT_ID} v${VERSION})"
