#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/dist/MacPipe Workbench.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BINARY="$ROOT/.build/debug/MacPipeWorkbench"

cd "$ROOT"
swift build --product MacPipeWorkbench -j 1

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BINARY" "$MACOS/MacPipe Workbench"
chmod +x "$MACOS/MacPipe Workbench"
if [[ -f "$ROOT/assets/MacPipeWorkbench.icns" ]]; then
  cp "$ROOT/assets/MacPipeWorkbench.icns" "$RESOURCES/MacPipeWorkbench.icns"
fi

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MacPipe Workbench</string>
  <key>CFBundleIdentifier</key>
  <string>com.ginu.macpipe.workbench</string>
  <key>CFBundleName</key>
  <string>MacPipe</string>
  <key>CFBundleDisplayName</key>
  <string>MacPipe</string>
  <key>CFBundleIconFile</key>
  <string>MacPipeWorkbench</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

printf 'Created %s\n' "$APP_DIR"
printf 'Open with: open %q\n' "$APP_DIR"
