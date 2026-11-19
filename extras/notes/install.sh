#!/usr/bin/env bash
# Frost Notes (no sudo): a global notes window on Meta+Alt+N, same key closes it.
#   extras/notes/install.sh            install, bind the key, start the background process
#   extras/notes/install.sh --remove   undo all of it (your notes in ~/.local/share/frost-notes stay)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RULE=frost-notes
reload() { qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; }

rules() { kreadconfig6 --file kwinrulesrc --group General --key rules; }
set_rules() { # $1 = comma list
  kwriteconfig6 --file kwinrulesrc --group General --key rules "$1"
  kwriteconfig6 --file kwinrulesrc --group General --key count "$(awk -F, '{print ($0==""?0:NF)}' <<<"$1")"
}

if [ "${1:-}" = "--remove" ]; then
  "$HERE/frost-notes" quit 2>/dev/null || true
  rm -f ~/.local/bin/frost-notes ~/.local/share/applications/frost-notes.desktop ~/.config/autostart/frost-notes.desktop
  kwriteconfig6 --file kwinrulesrc --group "$RULE" --delete 2>/dev/null || true
  set_rules "$(rules | tr ',' '\n' | grep -vx "$RULE" | paste -sd, || true)"
  python3 - <<'PY'
import dbus
ga = dbus.Interface(dbus.SessionBus().get_object("org.kde.kglobalaccel", "/kglobalaccel"), "org.kde.KGlobalAccel")
try: ga.unregister("frost-notes.desktop", "_launch")
except Exception: pass
PY
  reload; echo "Frost Notes removed."; exit 0
fi

mkdir -p ~/.local/bin ~/.local/share/applications ~/.config/autostart
ln -sf "$HERE/frost-notes" ~/.local/bin/frost-notes
cp "$HERE/frost-notes.desktop" ~/.local/share/applications/frost-notes.desktop
sed 's/^Exec=.*/Exec=frost-notes daemon/; /GlobalAccel/d; s/^NoDisplay.*//; $a X-GNOME-Autostart-enabled=true\nNoDisplay=true' \
  "$HERE/frost-notes.desktop" > ~/.config/autostart/frost-notes.desktop

# KWin window rule: centred, above other windows, not in the taskbar, and allowed to take focus
# when the shortcut shows it (otherwise Wayland's focus-stealing prevention keeps typing elsewhere)
G="$RULE"
w() { kwriteconfig6 --file kwinrulesrc --group "$G" --key "$@"; }
w Description "Frost Notes"
w wmclass frost-notes;           w wmclassmatch 1
w placement centered;            w placementrule 2
w above true;                    w aboverule 2
w skiptaskbar true;              w skiptaskbarrule 2
w skippager true;                w skippagerrule 2
w skipswitcher true;             w skipswitcherrule 2
w fsplevel 0;                    w fsplevelrule 2
case ",$(rules)," in *",$RULE,"*) ;; *) set_rules "$(rules | sed "s/^\$/$RULE/; t; s/\$/,$RULE/")";; esac

# Better Blur DX only frosts windows it knows about: add ours
cur=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses || true)
if [ "$(kreadconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled)" = true ] && ! grep -qx frost-notes <<<"$cur"; then
  kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses "${cur:+$cur
}frost-notes"
fi
reload

# Meta+Alt+N
python3 - <<'PY'
import dbus
ga = dbus.Interface(dbus.SessionBus().get_object("org.kde.kglobalaccel", "/kglobalaccel"), "org.kde.KGlobalAccel")
aid = ["frost-notes.desktop", "_launch", "Frost Notes", "Frost Notes"]
ga.doRegister(aid)
ga.setForeignShortcutKeys(aid, dbus.Array([dbus.Struct((dbus.Array([0x10000000 | 0x08000000 | 0x4E, 0, 0, 0], signature="i"),))], signature="(ai)"))
PY

# start the background process now, hidden, so the first press is instant too
if ! ~/.local/bin/frost-notes hide 2>/dev/null; then :; fi
pgrep -f "frost-notes daemon" >/dev/null || (setsid -f ~/.local/bin/frost-notes daemon >/dev/null 2>&1 || true)
echo "Frost Notes installed. Meta+Alt+N shows it; the same key (or Esc) hides it."
echo "Notes are plain .md files in ~/.local/share/frost-notes/."
