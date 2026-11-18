#!/usr/bin/env bash
# Frost keyboard shortcuts (no sudo):
#   Meta+Shift+D   toggle Do Not Disturb (the island shows On/Off)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/.local/bin ~/.local/share/applications
ln -sf "$HERE/frost-dnd" ~/.local/bin/frost-dnd
cp "$HERE/frost-dnd.desktop" ~/.local/share/applications/frost-dnd.desktop
python3 - <<'PY'
import dbus
ga = dbus.Interface(dbus.SessionBus().get_object("org.kde.kglobalaccel", "/kglobalaccel"), "org.kde.KGlobalAccel")
aid = ["frost-dnd.desktop", "_launch", "Toggle Do Not Disturb", "Toggle Do Not Disturb"]
ga.doRegister(aid)
ga.setForeignShortcutKeys(aid, dbus.Array([dbus.Struct((dbus.Array([0x10000000 | 0x02000000 | 0x44, 0, 0, 0], signature="i"),))], signature="(ai)"))
PY
echo "Meta+Shift+D toggles Do Not Disturb."
