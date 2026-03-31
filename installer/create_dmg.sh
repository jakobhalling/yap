#!/bin/bash
# Creates a macOS DMG installer with drag-to-Applications support.
# Usage: ./installer/create_dmg.sh [version]
# If version is omitted, reads from pubspec.yaml.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/yap.app"
VERSION="${1:-$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | sed 's/version: \([^+]*\).*/\1/')}"
DMG_NAME="Yap-${VERSION}-macOS.dmg"
DMG_DIR="$PROJECT_DIR/build/macos/dmg"
STAGING_DIR="$PROJECT_DIR/build/macos/dmg-staging"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: $APP_PATH not found. Run 'flutter build macos --release' first."
  exit 1
fi

echo "Creating DMG: $DMG_NAME"

# Clean previous staging/output
rm -rf "$STAGING_DIR" "$DMG_DIR/$DMG_NAME"
mkdir -p "$STAGING_DIR" "$DMG_DIR"

# Copy app and create Applications symlink for drag-and-drop install
cp -R "$APP_PATH" "$STAGING_DIR/Yap.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Create the DMG
hdiutil create \
  -volname "Yap" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_DIR/$DMG_NAME"

# Clean up staging
rm -rf "$STAGING_DIR"

echo "DMG created: $DMG_DIR/$DMG_NAME"
