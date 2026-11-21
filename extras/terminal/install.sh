#!/usr/bin/env bash
# Frost for the terminal and its tools: kitty, Konsole/Yakuake, Zellij, Neovim,
# Vim, bat, fzf, LS_COLORS, lsd, eza, lazygit, lazydocker, k9s, btop, bottom,
# yazi, ranger, nnn, fastfetch, glow, less/man, cava, cmus, newsboat and git.
# Every colour comes from palette/frost.toml. Only apps that are installed are
# touched; what was there before is kept and comes back with --revert.
#
#   extras/terminal/install.sh            build and install
#   extras/terminal/install.sh --image    also the Frost wallpaper behind kitty and Konsole
#   extras/terminal/install.sh --revert   go back to what you had
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in
    --revert) exec python3 "$HERE/apply.py" revert ;;
    ""|--image) ;;
    *) sed -n '2,11p' "$0"; exit 1 ;;
esac

python3 "$HERE/build_terminal.py"
python3 "$HERE/apply.py" install "$@"
echo "Open a new terminal (or run: exec \$SHELL) to see it. Konsole and Yakuake pick it up in new tabs."
