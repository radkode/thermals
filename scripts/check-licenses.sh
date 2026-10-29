#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="${1:?usage: scripts/check-licenses.sh <Thermals.app>}/Contents/Resources"
cmp "$ROOT/LICENSE" "$RESOURCES/LICENSE"
cmp "$ROOT/Thermals/Notices/Sparkle-LICENSE.txt" "$RESOURCES/Sparkle-LICENSE.txt"
cmp "$ROOT/Thermals/Fonts/OFL.txt" "$RESOURCES/OFL.txt"
echo "Distribution license notices match their sources."
