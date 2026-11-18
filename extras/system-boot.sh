#!/usr/bin/env bash
# Frost boot look (needs sudo):
#   - Plymouth boot splash: black, pulsing red dot, thin red progress line
#   - GRUB menu theme: black, red rounded selection, JetBrains Mono
# Your current choices are saved first; `--undo` puts them back.
#
# Usage:  sudo extras/system-boot.sh          Undo:  sudo extras/system-boot.sh --undo
# Rebuilding the boot image takes about a minute. You'll see it on next boot.
# (Your GRUB menu is set to hidden; hold Shift or press Esc while booting to see it.)
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
STATE=/var/lib/frost-boot
PLY=/usr/share/plymouth/themes
GRUBT=/usr/share/grub/themes/frost
FONT=/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf

if [ "${1:-}" = "--undo" ]; then
  [ -f "$STATE/plymouth" ] || { echo "Nothing to undo."; exit 0; }
  update-alternatives --set default.plymouth "$(cat "$STATE/plymouth")"
  update-alternatives --remove default.plymouth "$PLY/frost/frost.plymouth" || true
  if [ -s "$STATE/grub_theme" ]; then
    sed -i "s|^GRUB_THEME=.*|$(cat "$STATE/grub_theme")|" /etc/default/grub
  else
    sed -i '/^GRUB_THEME=/d' /etc/default/grub
  fi
  rm -rf "$PLY/frost" "$GRUBT" "$STATE"
  update-initramfs -u && update-grub
  echo "Boot splash and GRUB menu restored."
  exit 0
fi

# 1. remember what you have now (only the first time)
if [ ! -d "$STATE" ]; then
  mkdir -p "$STATE"
  update-alternatives --query default.plymouth | awk '/^Value:/{print $2}' > "$STATE/plymouth"
  grep '^GRUB_THEME=' /etc/default/grub > "$STATE/grub_theme" || true
fi

# 2. Plymouth
rm -rf "$PLY/frost"; cp -r "$HERE/plymouth/frost" "$PLY/frost"
update-alternatives --install "$PLY/default.plymouth" default.plymouth "$PLY/frost/frost.plymouth" 150
update-alternatives --set default.plymouth "$PLY/frost/frost.plymouth"

# 3. GRUB theme + fonts
rm -rf "$GRUBT"; cp -r "$HERE/grub/frost" "$GRUBT"
for s in 16 22; do grub-mkfont -s "$s" -o "$GRUBT/jetbrains-$s.pf2" "$FONT" 2>/dev/null; done
if grep -q '^GRUB_THEME=' /etc/default/grub; then
  sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$GRUBT/theme.txt\"|" /etc/default/grub
else
  echo "GRUB_THEME=\"$GRUBT/theme.txt\"" >> /etc/default/grub
fi

# 4. rebuild
update-initramfs -u
update-grub
echo "Done. Reboot to see the Frost boot splash."
