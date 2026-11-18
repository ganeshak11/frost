#!/usr/bin/env bash
# Build the Frost icon themes (Papirus with red folders) and install them for
# this user. Needs Papirus-Dark / Papirus-Light in ~/.local/share/icons.
#   extras/icons/install.sh          build + install (doesn't switch icons)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
python3 "$HERE/build_icons.py"
for t in Frost Frost-Light; do
  rm -rf ~/.local/share/icons/$t
  cp -a "$HERE/build/$t" ~/.local/share/icons/$t
done
echo "Installed Frost and Frost-Light icon themes."
