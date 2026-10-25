#!/bin/sh
# Build a release binary (Apple Silicon), wrap it in build/gitaffeine.app (ad-hoc signed)
# and package it as build/gitaffeine-<version>.zip and .dmg (with an Applications link) for a GitHub Release.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
app=build/gitaffeine.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/gitaffeine" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
rm -rf build/AppIcon.iconset
swift scripts/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
zip="build/gitaffeine-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
dmg="build/gitaffeine-$version.dmg"
rm -rf build/dmg
mkdir build/dmg
ditto "$app" build/dmg/gitaffeine.app
ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname gitaffeine -srcfolder build/dmg -ov -format UDZO "$dmg"
rm -rf build/dmg
echo "$app"
echo "$zip"
echo "$dmg"
