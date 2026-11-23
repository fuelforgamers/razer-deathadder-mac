#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="RazerDPI"
BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DIST_DIR="dist"
STAGING_DIR="build/dmg-staging"

echo "=== Packaging ${APP_NAME} for Distribution ==="

# 1. Build app
./build.sh

# 2. Prepare staging folder
echo "▸ Preparing DMG contents..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
mkdir -p "${DIST_DIR}"

cp -R "${BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# 3. Create DMG
echo "▸ Creating ${DIST_DIR}/${DMG_NAME}..."
rm -f "${DIST_DIR}/${DMG_NAME}"
hdiutil create \
    -volname "Razer DPI" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"

# 4. Cleanup
rm -rf "${STAGING_DIR}"

echo "✓ Created distributable Disk Image: ${DIST_DIR}/${DMG_NAME}"
echo "  File size: $(du -h "${DIST_DIR}/${DMG_NAME}" | cut -f1)"
