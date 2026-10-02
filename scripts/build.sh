#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/swift.sh" build -c release
BIN_DIR="$("$ROOT/scripts/swift.sh" build -c release --show-bin-path)"
APP="$ROOT/build/Fake.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Fake" "$APP/Contents/MacOS/Fake"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
swift -module-cache-path "$ROOT/.build/ModuleCache" "$ROOT/scripts/icon.swift" "$ROOT/build/Fake.iconset"
iconutil -c icns "$ROOT/build/Fake.iconset" -o "$APP/Contents/Resources/Fake.icns"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
