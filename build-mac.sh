#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export MACOSX_DEPLOYMENT_TARGET=12.0
app='build/CRN typer.app'
mkdir -p "$app/Contents/MacOS" dist
sdk="$(xcrun --sdk macosx --show-sdk-path)"
for architecture in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -O -sdk "$sdk" -target "${architecture}-apple-macos12.0" \
    -framework Cocoa -framework Carbon -framework ApplicationServices \
    src/CRNTyper.swift -o "build/CRNTyper-$architecture"
done
cp src/Info.plist "$app/Contents/Info.plist"
xcrun lipo -create build/CRNTyper-arm64 build/CRNTyper-x86_64 -output "$app/Contents/MacOS/CRNTyper"
xcrun lipo "$app/Contents/MacOS/CRNTyper" -verify_arch arm64 x86_64
plutil -lint "$app/Contents/Info.plist"
"$app/Contents/MacOS/CRNTyper" --self-test
codesign --force --sign - "$app"
codesign --verify --strict --verbose=2 "$app"
# Only the application is distributed; instructions live in the repository README.
ditto -c -k --sequesterRsrc --keepParent "$app" 'dist/CRN typer.zip'
shasum -a 256 'dist/CRN typer.zip'