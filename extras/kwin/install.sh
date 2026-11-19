#!/usr/bin/env bash
# Install the Frost window switcher (Alt+Tab) for this user and select it (no sudo).
#   extras/kwin/install.sh            install / update, switch to Frost
#   extras/kwin/install.sh --revert   switch back to the switcher you had before
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=~/.local/share/kwin-wayland/tabbox/frost   # where KWin (Wayland) looks for window switchers
STATE=~/.local/share/glass-theme/tabbox-before-frost

reload() { qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; }

if [ "${1:-}" = "--revert" ]; then
  prev=$(cat "$STATE" 2>/dev/null || echo thumbnail_grid)
  kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "$prev"
  reload; echo "Window switcher back to $prev."; exit 0
fi

mkdir -p "$(dirname "$STATE")" "$(dirname "$DEST")"
[ -f "$STATE" ] || kreadconfig6 --file kwinrc --group TabBox --key LayoutName --default thumbnail_grid > "$STATE"
rm -rf "$DEST"; cp -a "$HERE/tabbox/frost" "$DEST"
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName frost
reload
echo "Frost window switcher installed and selected (Alt+Tab)."
