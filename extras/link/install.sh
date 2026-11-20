#!/usr/bin/env bash
# Frost Link (no sudo): phone <-> laptop sync over Tailscale, for Frost Mobile.
#   extras/link/install.sh            install, start at login, start it now
#   extras/link/install.sh --remove   stop and remove it (synced notes and screen time stay)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
AUTO=~/.config/autostart/frost-link.desktop

stop() { pkill -f "python3 [^ ]*/frost-link daemon" 2>/dev/null || true; }

if [ "${1:-}" = "--remove" ]; then
  stop
  rm -f ~/.local/bin/frost-link "$AUTO"
  echo "Frost Link removed. Synced notes and phone screen time stay in ~/.local/share."; exit 0
fi

command -v tailscale >/dev/null || { echo "Frost Link needs Tailscale (tailscale up on this laptop and the phone)."; exit 1; }
chmod +x "$HERE/frost-link"
mkdir -p ~/.local/bin ~/.config/autostart
ln -sf "$HERE/frost-link" ~/.local/bin/frost-link
cat > "$AUTO" <<DESK
[Desktop Entry]
Type=Application
Name=Frost Link
Comment=Syncs notes, screen time and status with Frost Mobile over Tailscale
Exec=$HOME/.local/bin/frost-link daemon
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
DESK

stop
setsid "$HOME/.local/bin/frost-link" daemon >/dev/null 2>&1 < /dev/null &
echo "Frost Link is running on $(tailscale ip -4 2>/dev/null | head -1):47830 (Tailscale only) and starts at login."
