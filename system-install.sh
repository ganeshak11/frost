#!/usr/bin/env bash
# System-wide part of Frost (needs sudo):
#   - installs the Rufscript, Inter and JetBrains Mono fonts from Ubuntu's own repositories
#   - installs the Frost login (SDDM) theme and makes it the active one
# Usage:  sudo ./system-install.sh          Undo:  sudo ./system-install.sh --undo
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
CONF=/etc/sddm.conf.d/zz-frost.conf

if [ "${1:-}" = "--undo" ]; then
  rm -f "$CONF"; rm -rf /usr/share/sddm/themes/frost
  echo "Login screen back to your previous theme. (Fonts left installed.)"; exit 0
fi

apt-get install -y fonts-rufscript fonts-inter fonts-jetbrains-mono
rm -rf /usr/share/sddm/themes/frost
cp -r "$HERE/sddm/frost" /usr/share/sddm/themes/frost
chmod -R a+rX /usr/share/sddm/themes/frost
cat > "$CONF" <<EOF
# Frost login theme (remove this file to go back)
[Theme]
Current=frost
Font=Rufscript,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
EOF
echo "Done. You'll see the new login screen next time you log out or reboot."
echo "Now run ./install.sh (without sudo) to switch your desktop fonts."
