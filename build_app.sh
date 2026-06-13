#!/bin/bash
# Build ClipboardX and package it as a proper .app bundle.
# Usage: ./build_app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="ClipboardX"
BUNDLE_ID="com.clipboardx.app"
BUILD_DIR=".build/${CONFIG}"
APP_DIR="build/${APP_NAME}.app"

echo "==> Building (${CONFIG})…"
swift build -c "${CONFIG}"

echo "==> Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

# App icon (optional but expected for a real install).
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signature so Accessibility permission sticks across launches.
echo "==> Code signing (ad-hoc)…"
codesign --force --deep --sign - \
  --identifier "${BUNDLE_ID}" \
  "${APP_DIR}" 2>/dev/null || echo "   (codesign skipped/failed; app still runnable)"

echo "==> Done: ${APP_DIR}"
echo "    Run with:  open \"${APP_DIR}\""
