#!/usr/bin/env bash
# Frost Screen Time (no sudo): the tracker behind the Screen Time card.
#   extras/screentime/install.sh            install, start at login, start it now
#   extras/screentime/install.sh --remove   stop and remove it (your history in ~/.local/share/frost/screentime stays)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
AUTO=~/.config/autostart/frost-screentime.desktop

if [ "${1:-}" = "--remove" ]; then
  "$HERE/frost-screentime" quit 2>/dev/null || true
  rm -f ~/.local/bin/frost-screentime "$AUTO"
  echo "Frost Screen Time removed. History kept in ~/.local/share/frost/screentime/."; exit 0
fi

chmod +x "$HERE/frost-screentime"
mkdir -p ~/.local/bin ~/.config/autostart
ln -sf "$HERE/frost-screentime" ~/.local/bin/frost-screentime
cat > "$AUTO" <<EOF
[Desktop Entry]
Type=Application
Name=Frost Screen Time
Comment=Counts how long each app is in use, for the Screen Time card
Exec=$HOME/.local/bin/frost-screentime daemon
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
EOF

# restart it so a new version takes over
"$HERE/frost-screentime" quit 2>/dev/null || true
setsid "$HOME/.local/bin/frost-screentime" daemon >/dev/null 2>&1 < /dev/null &
echo "Frost Screen Time is running and starts at login."
