#!/usr/bin/env bash
# Tune zram (compressed swap in RAM) for a 6 GB laptop. Needs sudo.
#
# You already have zram via zram-tools, but it was 50% of RAM with lz4 and
# full. This makes it:
#   - 100% of RAM in size (it only uses real RAM for what's stored, ~1/3 of it)
#   - zstd compression (packs roughly 3-4x instead of ~2.7x)
#   - preferred over the disk swapfile, with kernel settings tuned for zram:
#       vm.swappiness=180, vm.page-cluster=0, vm.watermark_boost_factor=0
# The kernel settings apply immediately. The bigger zram applies at next boot
# (or now with --now, which takes a minute while swapped data is moved).
#
# Usage:  sudo extras/system-zram.sh [--now]      Undo:  sudo extras/system-zram.sh --undo
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
CONF=/etc/default/zramswap
SYS=/etc/sysctl.d/99-frost-zram.conf
BAK=/etc/default/zramswap.before-frost

if [ "${1:-}" = "--undo" ]; then
  [ -f "$BAK" ] && mv "$BAK" "$CONF"
  rm -f "$SYS"
  sysctl -q -w vm.swappiness=60 vm.page-cluster=3 vm.watermark_boost_factor=15000
  echo "zram settings restored (takes full effect at next boot)."
  exit 0
fi

[ -f "$BAK" ] || cp "$CONF" "$BAK"
set_kv() { if grep -qE "^#?\s*$1=" "$CONF"; then sed -i -E "s|^#?\s*$1=.*|$1=$2|" "$CONF"; else echo "$1=$2" >> "$CONF"; fi; }
set_kv ALGO zstd
set_kv PERCENT 100
set_kv PRIORITY 100
sed -i -E 's|^SIZE=|#SIZE=|' "$CONF"     # PERCENT decides the size

cat > "$SYS" <<'EOF'
# Frost: kernel settings for zram (compressed swap in RAM)
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
EOF
sysctl -q -p "$SYS"
echo "Kernel settings applied."

if [ "${1:-}" = "--now" ]; then
  echo "Restarting zram (moving swapped data, may take a minute)..."
  systemctl restart zramswap
fi
swapon --show
echo "Done. The larger zstd zram is active $( [ "${1:-}" = "--now" ] && echo now || echo 'from next boot' )."
