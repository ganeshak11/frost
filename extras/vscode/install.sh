#!/usr/bin/env bash
# Frost Dark for VS Code, Cursor and Antigravity (whichever are installed). No sudo.
#   extras/vscode/install.sh            build the theme, install it, switch to it
#   extras/vscode/install.sh --revert   switch each editor back to its previous theme
# Open editor windows switch straight away. settings.json is backed up first
# (~/.local/share/glass-theme/editor-backups/).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BK=~/.local/share/glass-theme/editor-backups
# editor command | its settings.json
EDITORS=(
  "code|$HOME/.config/Code/User/settings.json"
  "cursor|$HOME/.config/Cursor/User/settings.json"
  "/opt/antigravity-ide/bin/antigravity-ide|$HOME/.config/Antigravity IDE/User/settings.json"
)

[ "${1:-}" = "--revert" ] || python3 "$HERE/build_theme.py" >/dev/null
for e in "${EDITORS[@]}"; do
  cli=${e%%|*}; cfg=${e#*|}
  command -v "$cli" >/dev/null || continue
  if [ "${1:-}" = "--revert" ]; then
    [ -f "$cfg" ] && python3 "$HERE/frost_settings.py" "$cfg" revert; continue
  fi
  "$cli" --install-extension "$HERE/build/frost-theme.vsix" --force >/dev/null 2>&1 \
    && echo "$(basename "$cli"): Frost Dark installed" || echo "$(basename "$cli"): could not install the theme"
  mkdir -p "$BK" "$(dirname "$cfg")"
  [ -f "$cfg" ] && cp -a "$cfg" "$BK/$(basename "$cli")-settings-$(date +%Y%m%d-%H%M%S).json"
  python3 "$HERE/frost_settings.py" "$cfg" apply
done
