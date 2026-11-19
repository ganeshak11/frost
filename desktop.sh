#!/usr/bin/env bash
# Obsidian Glass desktop.
#  Top:   the Dynamic Island alone, in a small panel centred at the top edge;
#         windows go below it (they use the full height). It is also the
#         notification centre (there is no system tray, so no other popups).
#  Dock:  one glass bar at the bottom that hides until you push the pointer to
#         the bottom edge:  apps (Frost Dock) | clipboard. The panel draws the
#         bar (Frost theme). Meta+V shows the clipboard history at the pointer.
#         Other panels on the main screen are removed (with their tray and menu).
#  Cards: a bento layout of different-sized cards around the portrait, on a
#         16 px grid, clear of the island and the dock.
#   Left:   Chronos (wide) / Weather + Focus (two small squares) /
#           Device Ecosystem (wide, short) / Music (only while something plays)
#   Right:  System Observatory (extra wide, top) / Calendar & Agenda /
#           Quick Controls (phone-style square, bottom corner)
# Safe to run again. Restarts plasmashell once. Backs up the panel config first;
# ./revert.sh restores the look you had before Frost.
set -euo pipefail
RC=plasma-org.kde.plasma.desktop-appletsrc
CFG=~/.config; STATE=~/.local/share/glass-theme
BK=$STATE/backup-panels-$(date +%Y%m%d-%H%M%S); mkdir -p "$BK"
cp -a "$CFG/$RC" "$CFG/plasmashellrc" "$BK/"
echo "backup: $BK"

# Quit plasmashell and make sure it stays down: it can crash on the way out,
# and KDE's crash handler then starts it again straight away.
quit_shell() {
  for _ in 1 2 3; do
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    for _ in $(seq 40); do pgrep -x plasmashell >/dev/null || break; sleep 0.25; done
    sleep 3
    pgrep -x plasmashell >/dev/null || return 0
  done
  echo "plasmashell keeps running; config left unchanged" >&2; exit 1
}
# Start it through its service, so it gets the Frost OSD bridge (QML_IMPORT_PATH
# set by widgets/install-widgets.sh for plasma-plasmashell.service only).
start_shell() { systemctl --user start plasma-plasmashell.service 2>/dev/null || (setsid kstart plasmashell >/dev/null 2>&1 &); }

read -r top dock apps clip island cont sw sh ids <<<"$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
// ---- bars
const mine = panels().filter(p => p.screen == 0);
const has = (p, t) => p.widgets().some(w => w.type == t);
// keep your app order from any Frost Dock that is already there
let launchers = "";
for (const p of mine) for (const w of p.widgets()) if (w.type == "org.frost.dock") {
  w.currentConfigGroup = ["General"]; launchers = w.readConfig("launchers", "") || launchers; }
let dock = mine.find(p => has(p, "org.frost.dock"));
let top = mine.find(p => p !== dock && has(p, "org.frost.island"));
for (const p of mine) if (p !== top && p !== dock) p.remove();
if (!dock) dock = new Panel;
if (!top) top = new Panel;

// the clipboard applet runs Klipper: copy history, and copied text that
// outlives the app it came from
const DOCK = ["org.frost.dock", "org.kde.plasma.clipboard"];
for (const w of dock.widgets()) if (!DOCK.includes(w.type)) {
  if (w.type == "org.frost.island") w.globalShortcut = "";   // frees Meta+Alt+I for the new island
  w.remove();
}
const [apps, clip] = DOCK.map(t => dock.widgets().find(w => w.type == t) || dock.addWidget(t));
if (launchers) { apps.currentConfigGroup = ["General"]; apps.writeConfig("launchers", launchers); }
clip.globalShortcut = "";                // Meta+V goes to "clipboard at the pointer" (below)
dock.currentConfigGroup = ["General"];
dock.writeConfig("AppletOrder", [apps.id, clip.id].join(";"));   // applied on start
dock.location = "bottom"; dock.floating = true; dock.hiding = "autohide";
dock.lengthMode = "fit"; dock.alignment = "center";
dock.height = 94;                        // 24 px clear band (magnified icons) + the 70 px bar

for (const w of top.widgets()) if (!["org.frost.island", "org.frost.spotlight", "org.frost.controlcentre"].includes(w.type)) w.remove();
const island = top.widgets().find(w => w.type == "org.frost.island") || top.addWidget("org.frost.island");
if (!island.globalShortcut) island.globalShortcut = "Meta+Alt+I";   // open / close the island
// Spotlight: a 1 px widget beside the island; it's the "launcher", so the Meta
// key on its own opens its search bar (Meta+Space stays with KRunner)
const spot = top.widgets().find(w => w.type == "org.frost.spotlight") || top.addWidget("org.frost.spotlight");
// Control Centre: another 1 px widget; Meta+Alt+C, or right-click / scroll down on the island
const cc = top.widgets().find(w => w.type == "org.frost.controlcentre") || top.addWidget("org.frost.controlcentre");
if (!cc.globalShortcut) cc.globalShortcut = "Meta+Alt+C";
top.currentConfigGroup = ["General"];
top.writeConfig("AppletOrder", [island.id, spot.id, cc.id].join(";"));
top.location = "top"; top.height = 40; top.hiding = "windowsgobelow"; top.floating = false;
top.lengthMode = "fit"; top.alignment = "center"; top.offset = 0;
// ---- cards
const d = desktops().find(d => d.screen == 0), g = screenGeometry(0);
for (const w of d.widgets())
  if (["com.github.prayag2.modernclock", "org.kde.plasma.systemmonitor", "org.kde.plasma.mediacontroller", "org.kde.plasma.calendar", "org.frost.activity", "org.frost.media"].includes(w.type)) w.remove();
const order = ["org.frost.chronos", "org.frost.weather", "org.frost.devices", "org.frost.focus", "org.frost.observatory", "org.frost.agenda", "org.frost.controls", "org.frost.music"];
const ids = order.map(t => (d.widgets().find(w => w.type == t) || d.addWidget(t, 0, 0, 300, 200)).id);
print([top.id, dock.id, apps.id, clip.id, island.id, d.id, g.width, g.height, ids.join(",")].join(" "));')"
IFS=, read -r chronos wx dev focus obs cal ctl music <<<"$ids"

# Let Plasma finish removing widgets and panels and write its config before
# quitting (quitting mid-removal can crash it and lose part of the layout).
# Meta+V: Klipper's "Show Clipboard Items at Mouse Position" (Plasma's default;
# the dock is usually hidden, so the dock icon's own popup isn't much use)
python3 - <<'PY' || echo "note: set Meta+V for 'Show Clipboard Items at Mouse Position' in System Settings > Shortcuts"
import dbus
ga = dbus.Interface(dbus.SessionBus().get_object("org.kde.kglobalaccel", "/kglobalaccel"), "org.kde.KGlobalAccel")
meta_v = dbus.Struct((dbus.Array([0x10000000 | 0x56, 0, 0, 0], signature="i"),))   # Qt::META | Qt::Key_V
ga.setForeignShortcutKeys(["plasmashell", "show-on-mouse-pos", "", ""], dbus.Array([meta_v], signature="(ai)"))
PY
echo "letting Plasma settle..."; sleep 12
# a brand-new panel ignores some settings until its window exists: set them again
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
const t = panelById($top), d = panelById($dock);
t.hiding = 'windowsgobelow'; t.lengthMode = 'fit'; t.alignment = 'center'; t.height = 40;
d.hiding = 'autohide'; d.lengthMode = 'fit'; d.alignment = 'center'; d.height = 94; d.floating = true;" >/dev/null
sleep 2
quit_shell
# Card positions are measured from the free area, which Plasma starts 8 px
# below the 40 px island panel: y = screen y - 48.
M=32; R=$((sw - M))      # left and right edges
T=$((56 - 48))           # screen y 56: 16 px under the island panel
B=$((sh - 96 - 48))      # screen y sh-96: clear of the dock
if ! python3 - "$HOME/.config/$RC" "$cont" "${sw}x${sh}" "$dock" "$apps" "$clip" "$top" "$island" <<PY
import re, sys
path, cont, res, dock, apps, clip, top, island = sys.argv[1:]
place = {   # applet: x, y, w, h
    "$chronos": ($M,              $T,              560, 208),
    "$wx":      ($M,              $((T + 224)),    272, 240),
    "$focus":   ($((M + 288)),    $((T + 224)),    272, 240),
    "$dev":     ($M,              $((T + 480)),    560, 160),
    "$music":   ($M,              $((B - 272)),    560, 272),
    "$obs":     ($((R - 640)),    $T,              640, 208),
    "$cal":     ($((R - 400)),    $((T + 224)),    400, 320),
    "$ctl":     ($((R - 288)),    $((B - 288)),    288, 288),
}
# the file as [header, body] sections (body keeps its trailing newlines)
secs = [[m.group(1), m.group(2)] for m in re.finditer(r"^(\[[^\n]*\])\n((?:(?!\[)[^\n]*\n)*)", open(path).read(), re.M)]
def body(h):
    return next((x for x in secs if x[0] == h), None)
def setkey(sec, k, v):
    lines = [l for l in sec[1].rstrip("\n").split("\n") if l]
    lines = [f"{k}={v}" if l.startswith(k + "=") else l for l in lines]
    if not any(l.startswith(k + "=") for l in lines): lines.append(f"{k}={v}")
    sec[1] = "\n".join(lines) + "\n\n"
def getkey(sec, k):
    m = re.search(rf"^{re.escape(k)}=(.*)$", sec[1], re.M)
    return m.group(1) if m else None

# only touch a config that really holds the new layout
want = [f"[Containments][{dock}][Applets][{a}]" for a in (apps, clip)] + [f"[Containments][{top}][Applets][{island}]"]
missing = [h for h in want if not body(h)]
if missing:
    sys.exit("layout not saved as expected (missing " + ", ".join(missing) + "); config left unchanged. "
             "Restore it with: cp $BK/* ~/.config/  (while plasmashell is stopped)")

# dock order: apps, clipboard (plasmashell saves its own order on exit)
o = body(f"[Containments][{dock}][General]")
if o: setkey(o, "AppletOrder", f"{apps};{clip}")

# card positions
c = body(f"[Containments][{cont}]")
key = f"ItemGeometries-{res}"
keep = [i for i in (getkey(c, key) or "").split(";") if i and i.split(":")[0] not in {f"Applet-{a}" for a in place}]
setkey(c, key, ";".join(keep + [f"Applet-{a}:{x},{y},{w},{h},0" for a, (x, y, w, h) in place.items()]) + ";")

txt = "".join(h + "\n" + b for h, b in secs)
open(path, "w").write(txt)
PY
then
  start_shell
  exit 1
fi
# Dock translucent, so its bar and the popups it opens are glass (the theme
# blurs just the bar). Island panel opaque: a translucent
# panel gets its whole box blurred, which shows as a grey box around the pill.
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $dock" --key panelOpacity 2
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $top" --key panelOpacity 1
# drop old custom-length limits left on a reused panel (they would cap its width)
python3 - "$CFG/plasmashellrc" "$top" "$dock" <<'PY'
import re, sys
path, *ids = sys.argv[1:]
out, grp = [], ""
for line in open(path).read().split("\n"):
    if line.startswith("["): grp = line
    if any(grp.startswith(f"[PlasmaViews][Panel {i}]") for i in ids) and re.match(r"(min|max)Length=", line): continue
    out.append(line)
open(path, "w").write("\n".join(out))
PY
rm -f ~/.cache/ksvg-elements ~/.cache/plasma_theme_Frost*.kcache 2>/dev/null || true   # pick up theme changes
start_shell
echo "island panel $top, dock panel $dock (apps $apps, clipboard $clip)"
echo "desktop $cont: chronos=$chronos devices=$dev weather=$wx focus=$focus observatory=$obs agenda=$cal controls=$ctl music=$music"
