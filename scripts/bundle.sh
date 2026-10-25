#!/bin/sh
# Build a release binary (Apple Silicon), wrap it in build/gitaffeine.app (ad-hoc signed)
# and zip it as build/gitaffeine-<version>.zip for a GitHub Release.
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
echo "$app"
echo "$zip"
