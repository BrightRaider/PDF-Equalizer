#!/bin/bash
# Build universal (arm64 + x86_64) binary for PDF Equalizer
# Usage: ./build-universal.sh [release|debug]

set -e

BUILD_CONFIG="${1:-release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
BUILD_ROOT="${SCRIPT_DIR}/build-universal"
ARM64_DIR="${BUILD_ROOT}/arm64"
X86_64_DIR="${BUILD_ROOT}/x86_64"
OUTPUT_DIR="${BUILD_ROOT}/universal"

APP_DIR="${SCRIPT_DIR}/App"
SDK_PATH="$(xcrun --show-sdk-path)"
MIN_MACOS="12.0"

echo "=== PDF Equalizer Universal Build ==="
echo "Config: ${BUILD_CONFIG}"
echo ""

rm -rf "${BUILD_ROOT}"
mkdir -p "${ARM64_DIR}" "${X86_64_DIR}" "${OUTPUT_DIR}"

build_arch() {
    local ARCH="$1"
    local OUT_DIR="$2"

    echo "Building for ${ARCH}..."

    if [ "${BUILD_CONFIG}" = "release" ]; then
        local SWIFT_FLAGS="-O -whole-module-optimization"
    else
        local SWIFT_FLAGS="-Onone -g"
    fi

    local SWIFT_SOURCES
    SWIFT_SOURCES=$(find "${APP_DIR}" -name "*.swift" -type f | sort)

    swiftc \
        ${SWIFT_FLAGS} \
        -target "${ARCH}-apple-macosx${MIN_MACOS}" \
        -sdk "${SDK_PATH}" \
        -module-name PDFEqualizer \
        -o "${OUT_DIR}/PDFEqualizer" \
        ${SWIFT_SOURCES}
}

build_arch "arm64" "${ARM64_DIR}"
build_arch "x86_64" "${X86_64_DIR}"

# Create universal binary with lipo
echo "Creating universal binary..."
lipo -create \
    "${ARM64_DIR}/PDFEqualizer" \
    "${X86_64_DIR}/PDFEqualizer" \
    -output "${OUTPUT_DIR}/PDFEqualizer"

# Create app bundle
APP_BUNDLE="${OUTPUT_DIR}/PDF Equalizer.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${OUTPUT_DIR}/PDFEqualizer" "${APP_BUNDLE}/Contents/MacOS/PDFEqualizer"
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${SCRIPT_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Copy localization files
for LPROJ in "${SCRIPT_DIR}"/Resources/*.lproj; do
    if [ -d "${LPROJ}" ]; then
        cp -R "${LPROJ}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done

echo -n "APPLPDEQ" > "${APP_BUNDLE}/Contents/PkgInfo"

codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "=== Universal Build Complete ==="
lipo -info "${APP_BUNDLE}/Contents/MacOS/PDFEqualizer"
ls -lh "${APP_BUNDLE}/Contents/MacOS/PDFEqualizer"
echo "Output: ${APP_BUNDLE}"
