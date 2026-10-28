#!/bin/sh
# Linux/macOS launcher; spaces and non-ASCII project paths are supported.
set -eu
PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODE=${1:-game}
shift || true
ENGINE=${GODOT_BIN:-}
if [ -z "$ENGINE" ]; then
    for candidate in "$PROJECT"/Godot/Godot.app/Contents/MacOS/Godot \
        "$PROJECT"/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot \
        "$HOME"/Applications/Godot.app/Contents/MacOS/Godot \
        "$PROJECT"/Godot/Godot_v4.7.2-stable_linux.* "$PROJECT"/Godot_v4.7.2-stable_linux.*; do
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then ENGINE=$candidate; break; fi
    done
fi
if [ -z "$ENGINE" ]; then
    for name in godot4 godot; do
        if command -v "$name" >/dev/null 2>&1; then ENGINE=$(command -v "$name"); break; fi
    done
fi
if [ -z "$ENGINE" ] || [ ! -x "$ENGINE" ]; then
    printf '%s\n' 'Godot 4.7.2 Standard was not found.' \
        'Download: https://godotengine.org/download/archive/4.7.2-stable/' \
        'Extract into Godot/ or set GODOT_BIN to the executable path.'
    exit 1
fi
if [ "${1:-}" = '--check' ]; then
    printf 'Godot: %s\nProject: %s\n' "$ENGINE" "$PROJECT"
    exit 0
fi
if [ "$MODE" = editor ]; then exec "$ENGINE" --editor --path "$PROJECT" "$@"; fi
printf '%s\n' 'Preparing game assets. Please wait...'
"$ENGINE" --headless --editor --path "$PROJECT" --import --quit
exec "$ENGINE" --path "$PROJECT" "$@"
