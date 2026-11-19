#!/usr/bin/env bash
# Frost lock screen: the Frost clock (date above a large time) and the password
# on a glass card in Frost red, built on Plasma's own lock screen so unlocking,
# fingerprint, smartcard, media controls and the on-screen keyboard work as usual.
#
# Plasma 6 takes the lock screen from the Plasma *shell* package, not from the
# global theme. So this installs a small shell package that holds only the lock
# screen (org.frost.lockscreen), and points the screen locker at it through
# PLASMA_DEFAULT_SHELL, set for KWin alone (the screen locker runs inside KWin).
# The desktop itself (plasmashell) is a separate service and keeps Plasma's shell.
#
#   ./install.sh          install (takes effect at your next login)
#   ./install.sh --undo   back to Plasma's own lock screen (next login)
#   ./install.sh --test   show it for 10 s in Plasma's test mode (doesn't lock)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
PKG=org.frost.lockscreen
DEST=${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells/$PKG
DROPIN=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-kwin_wayland.service.d
# (with pipefail, ls failing on the path that isn't there must not end the script)
GREET=$(ls /usr/lib/*/libexec/kscreenlocker_greet /usr/libexec/kscreenlocker_greet 2>/dev/null | head -1 || true)

case "${1:-}" in
  --undo)
    rm -rf "$DEST" "$DROPIN/frost-lockscreen.conf"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Removed. Plasma's own lock screen is back from your next login."
    ;;
  --test)
    [ -n "$GREET" ] || { echo "kscreenlocker_greet not found"; exit 1; }
    timeout 10 "$GREET" --testing --shell "$PKG" || true
    ;;
  *)
    rm -rf "$DEST"; mkdir -p "$(dirname "$DEST")"
    cp -r "$HERE/$PKG" "$DEST"
    mkdir -p "$DROPIN"
    printf '[Service]\nEnvironment=PLASMA_DEFAULT_SHELL=%s\n' "$PKG" > "$DROPIN/frost-lockscreen.conf"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Installed. The Frost lock screen is used from your next login."
    echo "Try it now without locking: $0 --test"
    ;;
esac
