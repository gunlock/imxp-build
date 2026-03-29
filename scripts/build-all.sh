#!/usr/bin/env bash
#
# Build MyPlugin for all platforms and produce the final X-Plane plugin directory.
#
# Usage (inside Docker):
#   scripts/build-all.sh
#
# Output:
#   MyPlugin/
#   ├── lin_x64/MyPlugin.xpl
#   ├── win_x64/MyPlugin.xpl
#   └── mac_x64/MyPlugin.xpl   (universal binary: x86_64 + arm64)

set -euo pipefail

PRESETS=(linux-x86 windows-x86 mac-x64 mac-arm64)

echo "=== Configuring and building all presets ==="
for preset in "${PRESETS[@]}"; do
  echo "--- ${preset} ---"
  cmake --preset "$preset"
  cmake --build --preset "$preset"
done

echo "=== Creating macOS universal binary ==="
llvm-lipo-18 -create \
  build/docker/mac-x64/MyPlugin/mac_x64/MyPlugin.xpl \
  build/docker/mac-arm64/MyPlugin/mac_x64/MyPlugin.xpl \
  -output build/docker/mac-x64/MyPlugin/mac_x64/MyPlugin.universal.xpl

mv build/docker/mac-x64/MyPlugin/mac_x64/MyPlugin.universal.xpl \
  build/docker/mac-x64/MyPlugin/mac_x64/MyPlugin.xpl

DEPLOY_DIR=build/docker/deploy

echo "=== Assembling final plugin directory ==="
rm -rf "${DEPLOY_DIR}"
mkdir -p "${DEPLOY_DIR}/MyPlugin/lin_x64" "${DEPLOY_DIR}/MyPlugin/win_x64" "${DEPLOY_DIR}/MyPlugin/mac_x64"

cp build/docker/linux-x86/MyPlugin/lin_x64/MyPlugin.xpl "${DEPLOY_DIR}/MyPlugin/lin_x64/"
cp build/docker/windows-x86/MyPlugin/win_x64/MyPlugin.xpl "${DEPLOY_DIR}/MyPlugin/win_x64/"
cp build/docker/mac-x64/MyPlugin/mac_x64/MyPlugin.xpl "${DEPLOY_DIR}/MyPlugin/mac_x64/"

echo "=== Creating MyPlugin.zip ==="
(cd "${DEPLOY_DIR}" && zip -r MyPlugin.zip MyPlugin/)

echo "=== Done ==="
echo "Plugin directory:"
find "${DEPLOY_DIR}/MyPlugin" -type f | sort
file "${DEPLOY_DIR}"/MyPlugin/*/MyPlugin.xpl 2>/dev/null || true
echo "Archive: ${DEPLOY_DIR}/MyPlugin.zip ($(du -h "${DEPLOY_DIR}/MyPlugin.zip" | cut -f1))"
