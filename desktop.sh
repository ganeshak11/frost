#!/usr/bin/env bash
# Obsidian Glass desktop: a bento layout of different-sized cards around the
# portrait, all on a 16 px grid.
#   Left:   Chronos (wide) / Weather + Focus (two small squares) /
#           Device Ecosystem (wide, short) / Music (only while something plays)
#   Right:  System Observatory (extra wide, top) / Calendar & Agenda /
#           Quick Controls (tall and narrow, bottom corner)
# Safe to run again. Your previous layout is in the Frost backup (revert.sh).
set -euo pipefail
RC=plasma-org.kde.plasma.desktop-appletsrc

read -r cont sw sh ids <<<"$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
const d = desktops().find(d => d.screen == 0), g = screenGeometry(0);
for (const w of d.widgets())
  if (["com.github.prayag2.modernclock", "org.kde.plasma.systemmonitor", "org.kde.plasma.mediacontroller", "org.kde.plasma.calendar", "org.frost.activity", "org.frost.media"].includes(w.type)) w.remove();
const order = ["org.frost.chronos", "org.frost.weather", "org.frost.devices", "org.frost.focus", "org.frost.observatory", "org.frost.agenda", "org.frost.controls", "org.frost.music"];
const ids = order.map(t => (d.widgets().find(w => w.type == t) || d.addWidget(t, 0, 0, 300, 200)).id);
print([d.id, g.width, g.height, ids.join(",")].join(" "));')"
IFS=, read -r chronos wx dev focus obs cal ctl music <<<"$ids"

kquitapp6 plasmashell >/dev/null 2>&1 || true
sleep 1
M=32; R=$((sw - M))      # left and right edges
B=$((sh - M))            # bottom edge
python3 - "$HOME/.config/$RC" "$cont" "${sw}x${sh}" <<PY
import re, sys
path, cont, res = sys.argv[1:]
place = {   # applet: x, y, w, h
    "$chronos": ($M,              $M,              560, 208),
    "$wx":      ($M,              256,             272, 256),
    "$focus":   ($((M + 288)),    256,             272, 256),
    "$dev":     ($M,              528,             560, 176),
    "$music":   ($M,              $((B - 288)),    560, 288),
    "$obs":     ($((R - 640)),    $M,              640, 224),
    "$cal":     ($((R - 400)),    272,             400, 352),
    "$ctl":     ($((R - 288)),    $((B - 416)),    288, 416),
}
txt = open(path).read()
hdr = f"[Containments][{cont}]\n"
start = txt.index(hdr) + len(hdr); end = txt.find("\n[", start)
block = txt[start:end]
key = f"ItemGeometries-{res}="
m = re.search(rf"^{re.escape(key)}(.*)$", block, re.M)
keep = [i for i in (m.group(1).split(";") if m else []) if i and i.split(":")[0] not in {f"Applet-{a}" for a in place}]
line = key + ";".join(keep + [f"Applet-{a}:{x},{y},{w},{h},0" for a, (x, y, w, h) in place.items()]) + ";"
block = re.sub(rf"^{re.escape(key)}.*$", line, block, flags=re.M) if m else block.rstrip("\n") + "\n" + line + "\n"
open(path, "w").write(txt[:start] + block + txt[end:])
PY
(setsid kstart plasmashell >/dev/null 2>&1 &)
echo "desktop $cont: chronos=$chronos devices=$dev weather=$wx focus=$focus observatory=$obs agenda=$cal controls=$ctl music=$music"
