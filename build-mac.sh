#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export MACOSX_DEPLOYMENT_TARGET=12.0
mkdir -p build dist 'build/package/CRN Typer.app/Contents/MacOS'
sdk="$(xcrun --sdk macosx --show-sdk-path)"
for architecture in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -O -sdk "$sdk" \
    -target "${architecture}-apple-macos12.0" \
    -framework Cocoa -framework Carbon -framework ApplicationServices \
    src/CRNTyper.swift -o "build/CRNTyper-$architecture"
done
app='build/package/CRN Typer.app'
cp src/Info.plist "$app/Contents/Info.plist"
xcrun lipo -create build/CRNTyper-arm64 build/CRNTyper-x86_64 \
  -output "$app/Contents/MacOS/CRNTyper"
xcrun lipo "$app/Contents/MacOS/CRNTyper" -verify_arch arm64 x86_64
plutil -lint "$app/Contents/Info.plist"
"$app/Contents/MacOS/CRNTyper" --self-test
codesign --force --sign - "$app"
codesign --verify --strict --verbose=2 "$app"
cp MAC-README.txt build/package/README.txt
ditto -c -k --sequesterRsrc --keepParent build/package dist/CRN-Typer-Mac-Universal.zip
shasum -a 256 dist/CRN-Typer-Mac-Universal.zip
printf '\nBuilt universal Mac app (arm64 + x86_64), passed sequence self-tests and verified local signature.\n'
