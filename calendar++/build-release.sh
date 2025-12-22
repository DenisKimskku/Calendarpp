#!/bin/bash

# Build and Release Script for calendar++
# Usage: ./build-release.sh [version]
# Example: ./build-release.sh 1.0.0

set -e

VERSION=${1:-"1.0.0"}
SCHEME="calendar++"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
ZIP_NAME="calendar++-v$VERSION.zip"

echo "🚀 Building calendar++ v$VERSION"
echo "================================"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build archive
echo "🔨 Building archive..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -archivePath "$ARCHIVE_PATH" \
  -configuration Release

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "❌ Archive failed!"
  exit 1
fi

echo "✅ Archive created successfully"

# Export app
echo "📦 Exporting app..."
mkdir -p "$EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist calendar++/exportOptions.plist

if [ ! -d "$EXPORT_PATH/calendar++.app" ]; then
  echo "❌ Export failed!"
  exit 1
fi

echo "✅ App exported successfully"

# Create ZIP
echo "🗜️  Creating ZIP archive..."
cd "$EXPORT_PATH"
ditto -c -k --sequesterRsrc --keepParent "calendar++.app" "../$ZIP_NAME"
cd ../..

if [ ! -f "$BUILD_DIR/$ZIP_NAME" ]; then
  echo "❌ ZIP creation failed!"
  exit 1
fi

echo "✅ ZIP created: $BUILD_DIR/$ZIP_NAME"

# Calculate SHA256
echo ""
echo "🔐 SHA256 Checksum:"
echo "==================="
SHA256=$(shasum -a 256 "$BUILD_DIR/$ZIP_NAME" | awk '{print $1}')
echo "$SHA256"
echo ""

# Get file size
FILE_SIZE=$(du -h "$BUILD_DIR/$ZIP_NAME" | awk '{print $1}')

# Summary
echo "✅ Build Complete!"
echo "==================="
echo "Version:  v$VERSION"
echo "File:     $BUILD_DIR/$ZIP_NAME"
echo "Size:     $FILE_SIZE"
echo "SHA256:   $SHA256"
echo ""

# Next steps
echo "📝 Next Steps:"
echo "=============="
echo ""
echo "1. Test the app:"
echo "   open $BUILD_DIR/export/calendar++.app"
echo ""
echo "2. Create git tag:"
echo "   git tag -a v$VERSION -m \"Release version $VERSION\""
echo "   git push origin v$VERSION"
echo ""
echo "3. Upload to https://deniskim1.com/releases/:"
echo "   - Upload $BUILD_DIR/$ZIP_NAME to your website"
echo "   - Ensure it's accessible at: https://deniskim1.com/releases/$ZIP_NAME"
echo ""
echo "4. Update Homebrew formula in homebrew-tap:"
echo "   version \"$VERSION\""
echo "   sha256 \"$SHA256\""
echo ""
echo "5. Test Homebrew installation:"
echo "   brew tap DenisKimskku/tap"
echo "   brew install --cask calendar-plus-plus"
echo ""
echo "6. Test URL scheme:"
echo "   open \"calendarplusplus://show-date?timestamp=\$(date +%s)\""
echo ""

# Save build info
cat > "$BUILD_DIR/build-info.txt" << EOF
Version: v$VERSION
Built: $(date)
SHA256: $SHA256
Size: $FILE_SIZE

Homebrew Formula Update:
  version "$VERSION"
  sha256 "$SHA256"

Release URL:
  https://deniskim1.com/releases/$ZIP_NAME

Test Installation:
  brew tap DenisKimskku/tap
  brew install --cask calendar-plus-plus

Test URL Scheme:
  open "calendarplusplus://show-date?timestamp=\$(date +%s)"
EOF

echo "ℹ️  Build info saved to: $BUILD_DIR/build-info.txt"
