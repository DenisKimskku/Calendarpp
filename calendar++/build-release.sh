#!/usr/bin/env bash
set -euo pipefail

# Build and package script for calendar++.
# Usage:
#   ./build-release.sh [version] [method]
# Examples:
#   ./build-release.sh 1.1.0 debugging
#   ./build-release.sh 1.1.0 developer-id

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-1.0.0}"
METHOD="${2:-debugging}" # debugging | developer-id

SCHEME="calendar++"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build}"
WORK_DIR="${WORK_DIR:-/tmp/calendarpp-release-work}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${WORK_DIR}/DerivedData}"
ARCHIVE_PATH="${WORK_DIR}/${SCHEME}.xcarchive"
EXPORT_PATH="${WORK_DIR}/export"
VERIFY_PATH="${WORK_DIR}/verify"
ZIP_NAME="calendar++-v${VERSION}.zip"

DEBUG_EXPORT_OPTIONS="${ROOT_DIR}/calendar++/exportOptions.plist"
DEVELOPER_ID_EXPORT_OPTIONS="${ROOT_DIR}/calendar++/exportOptions-developer-id.plist"

case "${METHOD}" in
  debugging)
    EXPORT_OPTIONS_PATH="${DEBUG_EXPORT_OPTIONS}"
    ;;
  developer-id)
    EXPORT_OPTIONS_PATH="${DEVELOPER_ID_EXPORT_OPTIONS}"
    ;;
  *)
    echo "ERROR: Unsupported export method '${METHOD}'. Use 'debugging' or 'developer-id'."
    exit 1
    ;;
esac

if [[ "${METHOD}" == "developer-id" ]]; then
  if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "ERROR: Developer ID Application certificate not found."
    echo "Install a Developer ID cert in Keychain, or run a local package build with:"
    echo "  ./calendar++/build-release.sh ${VERSION} debugging"
    exit 1
  fi
fi

echo "Building calendar++ v${VERSION} (${METHOD})"
echo "==========================================="

echo "Cleaning previous build outputs..."
rm -rf "${WORK_DIR}" "${BUILD_DIR}/${ZIP_NAME}" "${BUILD_DIR}/build-info.txt"
mkdir -p "${BUILD_DIR}" "${WORK_DIR}"

echo "Archiving Release build..."
xcodebuild archive \
  -project "${ROOT_DIR}/calendar++.xcodeproj" \
  -scheme "${SCHEME}" \
  -archivePath "${ARCHIVE_PATH}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -configuration Release

if [[ ! -d "${ARCHIVE_PATH}" ]]; then
  echo "ERROR: Archive failed (missing ${ARCHIVE_PATH})."
  exit 1
fi

echo "Exporting app (${METHOD})..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PATH}"

APP_PATH="${EXPORT_PATH}/calendar++.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: Export failed (missing ${APP_PATH})."
  exit 1
fi

# Desktop/iCloud can attach metadata that fails strict codesign verification.
xattr -cr "${APP_PATH}" 2>/dev/null || true

echo "Checking bundle resources..."
if find "${APP_PATH}/Contents/Resources" -name "Info.plist" | grep -q .; then
  echo "ERROR: Duplicate Info.plist found in app resources."
  exit 1
fi

echo "Creating ZIP package..."
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${BUILD_DIR}/${ZIP_NAME}"

if [[ ! -f "${BUILD_DIR}/${ZIP_NAME}" ]]; then
  echo "ERROR: ZIP creation failed."
  exit 1
fi

echo "Verifying signed artifact from ZIP..."
mkdir -p "${VERIFY_PATH}"
ditto -x -k "${BUILD_DIR}/${ZIP_NAME}" "${VERIFY_PATH}"
VERIFIED_APP="${VERIFY_PATH}/calendar++.app"

codesign --verify --deep --strict --verbose=2 "${VERIFIED_APP}"

SPCTL_OUTPUT="$(spctl -a -vvv --type execute "${VERIFIED_APP}" 2>&1 || true)"
echo "${SPCTL_OUTPUT}"

if [[ "${METHOD}" == "developer-id" ]] && ! grep -qi "accepted" <<< "${SPCTL_OUTPUT}"; then
  echo "WARNING: Gatekeeper did not accept this build. Notarization may still be required."
fi

SHA256="$(shasum -a 256 "${BUILD_DIR}/${ZIP_NAME}" | awk '{print $1}')"
FILE_SIZE="$(du -h "${BUILD_DIR}/${ZIP_NAME}" | awk '{print $1}')"

echo ""
echo "Build complete"
echo "=============="
echo "Version:  v${VERSION}"
echo "Method:   ${METHOD}"
echo "File:     ${BUILD_DIR}/${ZIP_NAME}"
echo "Size:     ${FILE_SIZE}"
echo "SHA256:   ${SHA256}"

if [[ "${METHOD}" == "developer-id" ]]; then
  if xcrun notarytool history --keychain-profile AC_PASSWORD >/dev/null 2>&1; then
    echo "Notary profile AC_PASSWORD is available."
  else
    echo "WARNING: Notary profile AC_PASSWORD not found. Configure notarytool credentials before notarization."
  fi
fi

cat > "${BUILD_DIR}/build-info.txt" << EOF
Version: v${VERSION}
Method: ${METHOD}
Built: $(date)
SHA256: ${SHA256}
Size: ${FILE_SIZE}

Homebrew Formula Update:
  version "${VERSION}"
  sha256 "${SHA256}"

Release URL:
  https://deniskim1.com/releases/${ZIP_NAME}
EOF

echo "Build info saved to: ${BUILD_DIR}/build-info.txt"
