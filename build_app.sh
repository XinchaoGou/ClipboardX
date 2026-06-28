#!/bin/bash
# Build ClipboardX and package it as a proper .app bundle.
# Usage: ./build_app.sh [debug|release] [version]
# Version defaults to the latest git tag (without the leading "v").
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="ClipboardX"
BUNDLE_ID="com.clipboardx.app"
BUILD_DIR=".build/${CONFIG}"
APP_DIR="build/${APP_NAME}.app"
ZIP_PATH="build/ClipboardX-macos.zip"

VERSION="${2:-}"
if [[ -z "${VERSION}" ]]; then
  if git describe --tags --abbrev=0 &>/dev/null; then
    VERSION="$(git describe --tags --abbrev=0 | sed 's/^v//')"
  else
    VERSION="0.0.0-dev"
  fi
fi

echo "==> Building (${CONFIG}) version ${VERSION}…"
swift build -c "${CONFIG}"

echo "==> Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

INFO_PLIST="$(mktemp)"
cp "Resources/Info.plist" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${INFO_PLIST}"
cp "${INFO_PLIST}" "${APP_DIR}/Contents/Info.plist"
rm -f "${INFO_PLIST}"

# App icon (optional but expected for a real install).
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signature so Accessibility permission sticks across launches.
echo "==> Code signing (ad-hoc)…"
codesign --force --deep --sign - \
  --identifier "${BUNDLE_ID}" \
  "${APP_DIR}" 2>/dev/null || echo "   (codesign skipped/failed; app still runnable)"

if [[ "${CONFIG}" == "release" ]]; then
  echo "==> Packaging ${ZIP_PATH}…"
  rm -f "${ZIP_PATH}"
  ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"
  echo "    Upload ${ZIP_PATH} to GitHub Releases as ${ZIP_PATH##*/}"
fi

echo "==> Done: ${APP_DIR} (v${VERSION})"
echo "    Run with:  open \"${APP_DIR}\""
