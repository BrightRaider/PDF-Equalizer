#!/bin/bash
# Build script for PDF Equalizer
# Usage: ./build.sh [release|debug]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
BUILD_DIR="${SCRIPT_DIR}/build"
BUILD_CONFIG="${1:-debug}"

APP_DIR="${SCRIPT_DIR}/App"
APP_BUNDLE="${BUILD_DIR}/PDF Equalizer.app"

SDK_PATH="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
MIN_MACOS="12.0"

echo "=== PDF Equalizer Build ==="
echo "Config: ${BUILD_CONFIG}"
echo "Arch:   ${ARCH}"
echo ""

if [ "${BUILD_CONFIG}" = "release" ]; then
    SWIFT_FLAGS="-O -whole-module-optimization"
else
    SWIFT_FLAGS="-Onone -g"
fi

mkdir -p "${BUILD_DIR}"

SWIFT_SOURCES=$(find "${APP_DIR}" -name "*.swift" -type f | sort)

echo "Compiling..."
swiftc \
    ${SWIFT_FLAGS} \
    -target "${ARCH}-apple-macosx${MIN_MACOS}" \
    -sdk "${SDK_PATH}" \
    -module-name PDFEqualizer \
    -o "${BUILD_DIR}/PDFEqualizer" \
    ${SWIFT_SOURCES}

# Create app bundle
echo "Creating app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/PDFEqualizer" "${APP_BUNDLE}/Contents/MacOS/PDFEqualizer"
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${SCRIPT_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Copy localization files
for LPROJ in "${SCRIPT_DIR}"/Resources/*.lproj; do
    if [ -d "${LPROJ}" ]; then
        cp -R "${LPROJ}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done

echo -n "APPLPDEQ" > "${APP_BUNDLE}/Contents/PkgInfo"

# Ad-hoc code sign
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "=== Build complete ==="
echo "App: ${APP_BUNDLE}"
file "${APP_BUNDLE}/Contents/MacOS/PDFEqualizer"
