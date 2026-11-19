#!/usr/bin/env bash
# Frost installer (dark only).  Usage:  ./install.sh
# Backs up your current look first; ./revert.sh puts it back.
set -euo pipefail
MODE=dark; V=Dark; ICONS=Frost
HERE=$(cd "$(dirname "$0")" && pwd)
DATA=~/.local/share; CFG=~/.config; STATE=$DATA/glass-theme
kw() { kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }

python3 "$HERE/build.py"

# 1. Back up (only once: the first backup is the real "before Frost" state)
if [ ! -f "$STATE/LATEST_BACKUP" ]; then
  BK=$STATE/backup-$(date +%Y%m%d-%H%M%S); mkdir -p "$BK"
  for f in kdeglobals kwinrc plasmarc plasma-org.kde.plasma.desktop-appletsrc plasmashellrc gtk-3.0 gtk-4.0 Kvantum; do
    [ -e "$CFG/$f" ] && cp -a "$CFG/$f" "$BK/"
  done
  echo "$BK" > "$STATE/LATEST_BACKUP"
fi

# 2. Install files (icon themes are Papirus with red folders, built here)
[ -d ~/.local/share/icons/Papirus-Dark ] && "$HERE/extras/icons/install.sh" >/dev/null
"$HERE/extras/lockscreen/install.sh" >/dev/null   # Frost lock screen (from the next login)
mkdir -p $DATA/plasma $DATA/aurorae/themes $DATA/color-schemes $CFG/Kvantum
cp -r "$HERE/build/plasma/."          $DATA/plasma/
cp -r "$HERE/build/aurorae/themes/."  $DATA/aurorae/themes/
cp -r "$HERE/build/color-schemes/."   $DATA/color-schemes/
cp -r "$HERE/build/Kvantum/."         $CFG/Kvantum/

# 3. Turn off the heavy / gimmick effects, keep blur + rounded corners
for e in wobblywindows kwin6_effect_glitch magiclamp mouseclick mousemark trackmouse thumbnailaside snaphelper; do
  kw kwinrc Plugins "${e}Enabled" false
done
kw kwinrc Plugins blurEnabled true
kw kwinrc Plugins contrastEnabled true
kw kwinrc Effect-blur BlurStrength 3
kw kwinrc Effect-blur NoiseStrength 0
kw kdeglobals KDE AnimationDurationFactor 0.7

# 4. Apply the look
kw Kvantum/kvantum.kvconfig General theme "Frost$V"
kw kdeglobals KDE widgetStyle kvantum
# use the theme's own accent instead of an older custom one
kwriteconfig6 --file kdeglobals --group General --key AccentColor --delete
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper --delete
plasma-apply-colorscheme "Frost$V" >/dev/null
plasma-apply-desktoptheme Frost >/dev/null
kw kdeglobals Icons Theme "$ICONS"
kw kwinrc org.kde.kdecoration2 library org.kde.kwin.aurorae.v2
kw kwinrc org.kde.kdecoration2 theme "__aurorae__svg__Frost$V"
kw kwinrc org.kde.kdecoration2 ButtonsOnLeft ""
kw kwinrc org.kde.kdecoration2 ButtonsOnRight IAX
kw kwinrc org.kde.kdecoration2 BorderSize None
kw kwinrc org.kde.kdecoration2 BorderSizeAuto false

# Fonts: Rufscript (handwritten) for the interface, JetBrains Mono for code.
# Falls back to Inter if Rufscript isn't installed. Override with UI_FONT="Name" ./install.sh
UI_FONT=${UI_FONT:-Rufscript}; UI_SIZE=${UI_SIZE:-11}
fc-list : family | grep -x "$UI_FONT" >/dev/null || UI_FONT=Inter
if fc-list : family | grep -x "$UI_FONT" >/dev/null; then
  qf() { echo "$UI_FONT,$1,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"; }
  for k in font menuFont toolBarFont; do kw kdeglobals General "$k" "$(qf $UI_SIZE)"; done
  kw kdeglobals General smallestReadableFont "$(qf 9)"
  kw kdeglobals WM activeFont "$(qf $UI_SIZE)"
  if fc-list : family | grep -i "JetBrains Mono" >/dev/null; then
    kw kdeglobals General fixed "JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface monospace-font-name "JetBrains Mono 10" || true
  fi
  command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface font-name "$UI_FONT $UI_SIZE" || true
else
  echo "Neither Rufscript nor Inter is installed: run 'sudo ./system-install.sh' first."
fi

# Login splash (Frost look-and-feel package)
kw ksplashrc KSplash Engine KSplashQML
kw ksplashrc KSplash Theme "org.frost.${MODE}"
kw kdeglobals KDE LookAndFeelPackage "org.frost.${MODE}"   # shown as the active Global Theme

# GTK apps (Firefox, etc.) follow the Plasma colours through Breeze-GTK
# (unless extras/gtk/install.sh has switched them to the Frost GTK theme: keep that)
if command -v gsettings >/dev/null; then
  [ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" = "'Frost'" ] \
    || gsettings set org.gnome.desktop.interface gtk-theme Breeze || true
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$MODE" || true
fi

# 5. Panels: slimmer top bar, compact dock (layout and widgets untouched).
#    The Frost bars from ./panels.sh (island / dock) size themselves: left alone.
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
for (const p of panels()) {
  if (p.widgets().some(w => ["org.frost.island", "org.frost.dock"].includes(w.type))) continue;
  if (p.location == "top") p.height = 30;
  if (p.location == "bottom") { p.height = 56; p.floating = true; }
}' >/dev/null || true

# 6. Reload. Panels (and the popups they open) go translucent so the glass shows;
#    that setting is only read when plasmashell starts, so restart it.
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null || true
# reconfigure doesn't unload effects that are already running
for e in wobblywindows kwin6_effect_glitch magiclamp mouseclick mousemark trackmouse thumbnailaside snaphelper; do
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$e" >/dev/null 2>&1 || true
done
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect blur >/dev/null 2>&1 || true
# The Dynamic Island's panel stays opaque (desktop.sh): a translucent one gets its
# whole box blurred, which shows as a grey box around the pill.
island_panels=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'print(panels().filter(p => p.widgets().some(w => w.type == "org.frost.island")).map(p => p.id).join(" "))' 2>/dev/null || true)
kquitapp6 plasmashell >/dev/null 2>&1 || true
for _ in $(seq 40); do pgrep -x plasmashell >/dev/null || break; sleep 0.25; done
for g in $(grep -oE '^\[PlasmaViews\]\[Panel [0-9]+\]$' $CFG/plasmashellrc 2>/dev/null | grep -oE '[0-9]+'); do
  case " $island_panels " in *" $g "*) continue ;; esac
  kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $g" --key panelOpacity 2
done
rm -f ~/.cache/ksvg-elements ~/.cache/plasma_theme_Frost*.kcache 2>/dev/null || true
# through its service, so it gets the Frost OSD bridge (widgets/install-widgets.sh)
systemctl --user start plasma-plasmashell.service 2>/dev/null || (setsid kstart plasmashell >/dev/null 2>&1 &)
/usr/lib/x86_64-linux-gnu/libexec/plasma-changeicons "$ICONS" >/dev/null 2>&1 || true
echo "Frost $V applied. Apps that were already open pick up the new style after a restart."
