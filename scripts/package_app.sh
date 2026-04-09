#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClipyLite"
BUNDLE_ID="com.clipylite.app"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
RELEASE_BIN="$ROOT_DIR/.build/arm64-apple-macosx/release/clipy"
ZIP_PATH="$ROOT_DIR/dist/${APP_NAME}-arm64.zip"
ICON_PNG="$ROOT_DIR/dist/AppIcon-1024.png"
ICON_PNG_NORMALIZED="$ROOT_DIR/dist/AppIcon-1024-normalized.png"
ICON_ICNS="$ROOT_DIR/dist/AppIcon.icns"
ICONSET_DIR="$ROOT_DIR/dist/AppIcon.iconset"

cd "$ROOT_DIR"

echo "[1/6] Building arm64 release binary..."
# Avoid stale module cache path conflicts when the project directory name changes.
rm -rf "$ROOT_DIR/.build/arm64-apple-macosx/release/ModuleCache"
swift build -c release --arch arm64

echo "[2/6] Creating app bundle layout..."
rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$RELEASE_BIN" "$BIN_DIR/clipy"
chmod +x "$BIN_DIR/clipy"

echo "[3/6] Preparing app icon..."
if [[ -f "$ICON_PNG" ]]; then
  echo "Using existing icon source: $ICON_PNG"
else
  swift "$ROOT_DIR/scripts/generate_icon.swift" "$ICON_PNG"
fi
sips -z 1024 1024 "$ICON_PNG" --out "$ICON_PNG_NORMALIZED" >/dev/null
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG_NORMALIZED" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
cp "$ICON_ICNS" "$RES_DIR/AppIcon.icns"

echo "[4/6] Writing Info.plist..."
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>clipy</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "[5/6] Applying ad-hoc code signature..."
codesign --force --deep -s - "$APP_DIR"

echo "[6/6] Creating distributable zip..."
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo

echo "App bundle: $APP_DIR"
echo "Zip package: $ZIP_PATH"
