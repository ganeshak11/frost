#!/usr/bin/env bash
# Put back the look you had before Frost was first installed.
set -euo pipefail
STATE=~/.local/share/glass-theme; CFG=~/.config
BK=$(cat "$STATE/LATEST_BACKUP" 2>/dev/null) || { echo "No backup found in $STATE"; exit 1; }
echo "Restoring from $BK"
for f in kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc; do
  [ -e "$BK/$f" ] && cp -a "$BK/$f" "$CFG/$f"
done
for d in gtk-3.0 gtk-4.0; do [ -e "$BK/$d" ] && { rm -rf "$CFG/$d"; cp -a "$BK/$d" "$CFG/$d"; }; done
[ -f "$BK/Kvantum/kvantum.kvconfig" ] && cp -a "$BK/Kvantum/kvantum.kvconfig" "$CFG/Kvantum/kvantum.kvconfig"

scheme=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)
theme=$(kreadconfig6 --file plasmarc --group Theme --key name)
[ -n "$scheme" ] && plasma-apply-colorscheme "$scheme" >/dev/null || true
[ -n "$theme" ] && plasma-apply-desktoptheme "$theme" >/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null || true
# plasmashell must restart to reload the restored panel layout
kquitapp6 plasmashell >/dev/null 2>&1 || true
(setsid kstart plasmashell >/dev/null 2>&1 &)
echo "Reverted. Frost files stay installed (pick them again any time in System Settings)."
