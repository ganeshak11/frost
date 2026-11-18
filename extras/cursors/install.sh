#!/usr/bin/env bash
# Build and apply the Frost cursor theme for this user (no sudo).
#   extras/cursors/install.sh            build, install, switch to Frost
#   extras/cursors/install.sh --revert   switch back to the cursor you had before
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=~/.icons/Frost-cursors   # Plasma looks for cursor themes in ~/.icons
STATE=~/.local/share/glass-theme/cursor-before-frost

if [ "${1:-}" = "--revert" ]; then
  prev=$(cat "$STATE" 2>/dev/null || echo breeze_cursors)
  plasma-apply-cursortheme "$prev"
  command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface cursor-theme "$prev" || true
  echo "Cursor back to $prev."; exit 0
fi

python3 "$HERE/build_cursors.py"
mkdir -p "$(dirname "$STATE")"
[ -f "$STATE" ] || kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme > "$STATE"
rm -rf "$DEST"; cp -a "$HERE/build/Frost-cursors" "$DEST"
plasma-apply-cursortheme Frost-cursors
command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface cursor-theme Frost-cursors || true
echo "Frost cursors applied. Apps that were already open switch the next time they start."
