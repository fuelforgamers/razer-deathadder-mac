#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="RazerDPI"
BUNDLE="${APP_NAME}.app"

echo "=== Building ${APP_NAME} for macOS ==="

# Stop running instances
killall "${APP_NAME}" 2>/dev/null || true

# 1. Compile native binary
echo "▸ Compiling sources with clang..."
mkdir -p build
clang -fobjc-arc -O2 \
    -mmacosx-version-min=12.0 \
    -framework Cocoa \
    -framework IOKit \
    -framework ServiceManagement \
    src/main.m src/AppDelegate.m src/ControlWindow.m src/RazerDevice.m \
    -o "build/${APP_NAME}"

# 2. Build .app bundle
echo "▸ Assembling ${BUNDLE}..."
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp "build/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"

# App icon
if [ -f "resources/AppIcon.icns" ]; then
    cp "resources/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
elif [ -f "MacRazer/Packaging/AppIcon.icns" ]; then
    cp "MacRazer/Packaging/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Info.plist with Input Monitoring usage description
cat << 'EOF' > "${BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RazerDPI</string>
    <key>CFBundleIdentifier</key>
    <string>com.royce.razer-dpi</string>
    <key>CFBundleName</key>
    <string>Razer DPI</string>
    <key>CFBundleDisplayName</key>
    <string>Razer DPI</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Razer DPI requires Input Monitoring permission to configure DPI sensitivity and lighting effects on your Razer DeathAdder mouse over USB.</string>
</dict>
</plist>
EOF

# 3. Ad-hoc codesign
echo "▸ Codesigning ${BUNDLE}..."
codesign --force --deep --sign - --identifier "com.royce.razer-dpi" "${BUNDLE}"

echo "✓ Build complete: ${BUNDLE}"

if [ "${1:-}" = "--install" ]; then
    echo "▸ Installing to /Applications/${BUNDLE}..."
    rm -rf "/Applications/${BUNDLE}"
    cp -R "${BUNDLE}" "/Applications/${BUNDLE}"
    echo "✓ Installed to /Applications/${BUNDLE}"
fi
