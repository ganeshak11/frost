#!/usr/bin/env bash
# Better Blur DX: KWin's blur, plus "force blur" for apps that don't ask for it,
# so GTK apps on the Frost GTK theme (and their menus) become real frosted glass.
# https://github.com/xarblu/kwin-effects-better-blur-dx (pinned below).
#
#   extras/kwin/better-blur.sh            install build tools, build, install, switch on
#   extras/kwin/better-blur.sh --rebuild  after a Plasma update (the effect only works with
#                                         the exact KWin it was built for), then log out / in
#   extras/kwin/better-blur.sh --off      back to KWin's own blur (stays installed)
#
# Asks for your password: the build tools come from apt and the effect goes into /usr.
set -euo pipefail
VER=v2.6.0
SRC=~/.local/src/kwin-effects-better-blur-dx
KW() { kwriteconfig6 --file kwinrc --group "$1" --key "$2" "$3"; }
fx() { qdbus6 org.kde.KWin /Effects "org.kde.kwin.Effects.$1" "$2" >/dev/null 2>&1 || true; }

# apps that draw a see-through background but don't ask KWin for blur (Wayland app ids)
CLASSES=(
  blueman-manager blueman-adapters blueman-services nm-connection-editor
  org.gnome.Loupe org.gnome.gedit gedit org.gnome.SystemMonitor gnome-system-monitor
  qalculate-gtk zenity org.gnome.Zenity yelp org.gnome.Yelp audacious
)

if [ "${1:-}" = "--off" ]; then
  KW Plugins better_blur_dxEnabled false; KW Plugins blurEnabled true
  fx unloadEffect better_blur_dx; fx loadEffect blur
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  echo "Back to KWin's own blur."; exit 0
fi

echo "== build tools (apt)"
sudo apt-get install -y --no-install-recommends git cmake g++ extra-cmake-modules qt6-tools-dev kwin-dev \
  libkf6configwidgets-dev gettext libkf6crash-dev libkf6globalaccel-dev libkf6kio-dev libkf6service-dev \
  libkf6notifications-dev libkf6kcmutils-dev libkdecorations3-dev libxcb-composite0-dev libxcb-randr0-dev \
  libxcb-shm0-dev libxcb-res0-dev libxcb-sync-dev

echo "== source ($VER)"
if [ -d "$SRC/.git" ]; then git -C "$SRC" fetch -q --tags origin; else git clone -q https://github.com/xarblu/kwin-effects-better-blur-dx "$SRC"; fi
git -C "$SRC" -c advice.detachedHead=false checkout -q "$VER"

echo "== build for $(kwin_wayland --version 2>/dev/null | tail -1)"
rm -rf "$SRC/build"
cmake -S "$SRC" -B "$SRC/build" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$SRC/build" -j"$(nproc)" >/dev/null
sudo cmake --install "$SRC/build" >/dev/null

echo "== switch KWin to it"
G=Effect-better-blur-dx
KW "$G" BlurStrength 5
KW "$G" NoiseStrength 0
KW "$G" Saturation 150
KW "$G" CornerRadius 12          # matches the rounded Frost windows
KW "$G" BlurMatching true
KW "$G" BlurNonMatching false
KW "$G" BlurMenus true           # translucent menus and popups get blurred too
KW "$G" BlurDocks false          # the Frost panels already ask for blur
KW "$G" WindowClasses "$(printf '%s\n' "${CLASSES[@]}")"
KW Plugins blurEnabled false     # the two would fight over the same windows
KW Plugins better_blur_dxEnabled true
fx unloadEffect blur; fx loadEffect better_blur_dx
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
if [ "${1:-}" = "--rebuild" ]; then
  echo "Rebuilt. Log out and back in so KWin loads the new build."
else
  echo "Better Blur DX is on. Restart a GTK app (e.g. Bluetooth Manager) to see it as frosted glass."
fi
