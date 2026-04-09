#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClipyLite"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
DMG_STAGING_DIR="$DIST_DIR/${APP_NAME}-dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-arm64.dmg"
VOLUME_NAME="$APP_NAME"

cd "$ROOT_DIR"

echo "[1/4] Building app bundle..."
bash "$ROOT_DIR/scripts/package_app.sh"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

echo "[2/4] Preparing DMG staging folder..."
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

echo "[3/4] Creating DMG image..."
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "[4/4] Cleaning temporary files..."
rm -rf "$DMG_STAGING_DIR"

echo
echo "DMG package: $DMG_PATH"
