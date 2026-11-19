#!/usr/bin/env bash
# Frost for GTK apps (GTK 3, GTK 4, libadwaita, and Flatpak apps). No sudo.
#   extras/gtk/install.sh            build, install, switch GTK apps to Frost
#   extras/gtk/install.sh --revert   switch back to the GTK theme you had before
# Apps that are already open pick it up the next time they start.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
STATE=~/.local/share/glass-theme/gtk-before-frost
ADW=~/.config/gtk-4.0/gtk.css           # libadwaita apps only read this file

set_theme() {
  qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme "$1" >/dev/null 2>&1 || true   # Plasma's GTK sync
  command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface gtk-theme "$1" || true
}
strip_adw() { [ -f "$ADW" ] && sed -i '/\/\* FROST >>> \*\//,/\/\* <<< FROST \*\//d' "$ADW" || true; }

if [ "${1:-}" = "--revert" ]; then
  prev=$(cat "$STATE" 2>/dev/null || echo Breeze)
  set_theme "$prev"; strip_adw
  flatpak override --user --unset-env=GTK_THEME 2>/dev/null || true
  echo "GTK apps back to $prev."; exit 0
fi

python3 "$HERE/build_gtk.py" >/dev/null
mkdir -p "$(dirname "$STATE")" ~/.themes
[ -f "$STATE" ] || { cur=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'"); echo "${cur:-Breeze}" > "$STATE"; }
rm -rf ~/.themes/Frost; cp -a "$HERE/build/Frost" ~/.themes/Frost    # ~/.themes: Flatpak apps can read it too
set_theme Frost
command -v gsettings >/dev/null && { gsettings set org.gnome.desktop.interface color-scheme prefer-dark; \
                                     gsettings set org.gnome.desktop.interface accent-color red 2>/dev/null; } || true

# libadwaita: Frost colours appended to the user stylesheet, between markers
mkdir -p "$(dirname "$ADW")"; touch "$ADW"; strip_adw
[ -s "$ADW" ] && [ -n "$(tail -c1 "$ADW")" ] && echo >> "$ADW"    # Plasma writes its @import without a newline
{ echo "/* FROST >>> */"; cat "$HERE/build/libadwaita.css"; echo "/* <<< FROST */"; } >> "$ADW"

# Flatpak apps: use Frost (was forced to Flat-Remix blue) and see the colour files
if command -v flatpak >/dev/null; then
  flatpak override --user --env=GTK_THEME=Frost --unset-env=ICON_THEME \
    --filesystem=~/.themes:ro --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
fi
echo "Frost GTK theme installed. GTK apps that are open now switch the next time they start."
