#!/bin/zsh
# Builds "Network Compass.app" and installs it in ~/Applications. Needs the Swift command line tools
# (run: xcode-select --install). Xcode itself is not required.
set -e
cd "$(dirname "$0")"
APP="build/Network Compass.app"
BUNDLE_ID="app.networkcompass.mac"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -parse-as-library -target "$(uname -m)-apple-macos14.0" \
  Sources/*.swift -o "$APP/Contents/MacOS/NetworkCompass"

swift tools/make_icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Network Compass</string>
  <key>CFBundleDisplayName</key><string>Network Compass</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>NetworkCompass</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.business</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
[[ -n "$NO_INSTALL" ]] && { echo "Built: $APP"; exit 0; }
# Point the app at this repo's data file, unless you already chose another in Settings
defaults read "$BUNDLE_ID" dataPath >/dev/null 2>&1 || defaults write "$BUNDLE_ID" dataPath "$(cd .. && pwd)/data/crm.json"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Network Compass.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installed: $HOME/Applications/Network Compass.app"
