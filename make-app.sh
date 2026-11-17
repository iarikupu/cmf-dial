#!/bin/sh
# Builds "CMF Dial.app" next to this script.
set -e
cd "$(dirname "$0")"
swift build -c release
APP="CMF Dial.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/cmfdial "$APP/Contents/MacOS/cmfdial"
mkdir -p "$APP/Contents/Resources/Images" && cp Resources/Images/* "$APP/Contents/Resources/Images/" 2>/dev/null || true
mkdir -p "$APP/Contents/Resources/Fonts" && cp Resources/Fonts/*.otf "$APP/Contents/Resources/Fonts/" 2>/dev/null || true

rm -rf .build/AppIcon.iconset
swiftc -o .build/make-icon tools/make-icon.swift
.build/make-icon .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>CMF Dial</string>
  <key>CFBundleDisplayName</key><string>CMF Dial</string>
  <key>CFBundleIdentifier</key><string>local.cmfdial.app</string>
  <key>CFBundleExecutable</key><string>cmfdial</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>CMF Dial talks to your CMF earbuds to read the case dial and battery.</string>
</dict></plist>
PLIST

# Sign with the local "CMF Dial Local Signing" identity when present, so macOS keeps granted permissions
# (Accessibility etc.) across rebuilds; otherwise fall back to an ad-hoc signature.
ID=$(security find-identity -p codesigning | grep "CMF Dial Local Signing" | head -1 | awk '{print $2}')
if [ -n "$ID" ]; then codesign --force --sign "$ID" "$APP" && echo "Signed with local identity"; else codesign --force --sign - "$APP"; fi
echo "Built $APP"
