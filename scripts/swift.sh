#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT/.build/ModuleCache}"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
COMMAND="$1"
shift

# Command Line Tools ship Swift Testing but do not always put it on SwiftPM's search path.
DEVELOPER_DIR_PATH="$(xcode-select -p)"
FRAMEWORKS="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
FLAGS=()
if [ "$COMMAND" = test ]; then
    FLAGS+=(--disable-xctest --enable-swift-testing)
    if [ -d "$FRAMEWORKS/Testing.framework" ]; then
        FLAGS+=(-Xswiftc -F -Xswiftc "$FRAMEWORKS" -Xlinker -rpath -Xlinker "$FRAMEWORKS"
                -Xlinker -rpath -Xlinker "$DEVELOPER_DIR_PATH/Library/Developer/usr/lib")
    fi
fi
exec swift "$COMMAND" --package-path "$ROOT" --disable-sandbox \
    --cache-path "$ROOT/.build/cache" --config-path "$ROOT/.build/config" \
    --security-path "$ROOT/.build/security" --scratch-path "$ROOT/.build" \
    -debug-info-format none "${FLAGS[@]}" "$@"
