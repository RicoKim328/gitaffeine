#!/bin/sh
# Build a release binary and wrap it in build/gitaffeine.app (ad-hoc signed).
set -eu
cd "$(dirname "$0")/.."

swift build -c release
app=build/gitaffeine.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/gitaffeine" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
echo "$app"
