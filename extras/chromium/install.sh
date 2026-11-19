#!/usr/bin/env bash
# Frost Dark for Brave, Chrome and other Chromium browsers.
# Chromium only takes local themes through its own page, so this copies the
# theme to a fixed place and tells you the three clicks:
#   1. open brave://extensions (or chrome://extensions) in each profile
#   2. switch on "Developer mode" (top right)
#   3. "Load unpacked" -> pick ~/.local/share/frost/chromium-theme
# To go back: brave://settings/appearance -> Theme -> Reset to default.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=~/.local/share/frost/chromium-theme
rm -rf "$DEST"; mkdir -p "$(dirname "$DEST")"; cp -a "$HERE/frost-theme" "$DEST"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$DEST/manifest.json"
sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'
