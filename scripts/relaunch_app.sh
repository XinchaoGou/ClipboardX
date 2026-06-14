#!/usr/bin/env bash
# Quit any running ClipboardX, rebuild the .app bundle, and open it (for local smoke tests).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
killall ClipboardX 2>/dev/null || true
./build_app.sh release
open "$ROOT/build/ClipboardX.app"
echo "Relaunched: $ROOT/build/ClipboardX.app"
