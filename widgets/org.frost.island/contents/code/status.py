#!/usr/bin/env python3
"""One read-only snapshot for the Dynamic Island, printed as JSON:
battery, microphone in use (by anything except cava), camera in use, screen
being recorded or shared, connected Bluetooth devices, browser downloads in
progress (Firefox .part / Chromium .crdownload files in ~/Downloads), the
Frost Focus timer's state and the Frost Weather location (from widget settings)."""
import configparser, glob, json, os, subprocess

def run(*a, t=3):
    try: return subprocess.run(a, capture_output=True, text=True, timeout=t).stdout
    except Exception: return ""

out = {"battery": None, "mic": [], "cam": [], "rec": [], "bt": [], "dl": [], "recent": [], "focus": None, "loc": None}

bat = (glob.glob("/sys/class/power_supply/BAT*") or [None])[0]
if bat:
    rd = lambda f: open(os.path.join(bat, f)).read().strip()
    try: out["battery"] = {"pct": int(rd("capacity")), "status": rd("status")}
    except Exception: pass
    # charger plugged in? Ask the adapter: a full battery's status flips between
    # "Full", "Charging" and "Not charging" on some laptops
    for ps in glob.glob("/sys/class/power_supply/*"):
        try:
            if open(os.path.join(ps, "type")).read().strip() == "Mains" and out["battery"]:
                out["battery"]["ac"] = open(os.path.join(ps, "online")).read().strip() == "1"
        except Exception: pass

try:
    sources = {s["index"]: s["name"] for s in json.loads(run("pactl", "-f", "json", "list", "sources", "short") or "[]")}
    for o in json.loads(run("pactl", "-f", "json", "list", "source-outputs") or "[]"):
        app = o.get("properties", {}).get("application.name", "") or ""
        if not sources.get(o.get("source"), "").endswith(".monitor") and app.lower() != "cava":
            out["mic"].append(app or "An app")
except Exception: pass

# camera: processes holding a /dev/video* device open
for fd in glob.glob("/proc/[0-9]*/fd/*"):
    try:
        if os.readlink(fd).startswith("/dev/video"):
            pid = fd.split("/")[2]
            name = open(f"/proc/{pid}/comm").read().strip()
            if name not in out["cam"] and name not in ("pipewire", "wireplumber"): out["cam"].append(name)
    except Exception: pass

# screen recording / sharing: a running PipeWire video stream made by KWin or
# the screen-cast portal (webcams are v4l2/libcamera nodes and are skipped)
try:
    for o in json.loads(run("pw-dump", t=2) or "[]"):
        i = o.get("info") or {}; p = i.get("props") or {}
        if p.get("media.class") != "Video/Source" or i.get("state") != "running": continue
        who = " ".join(str(p.get(k, "")) for k in ("node.name", "application.name", "media.name", "node.description")).lower()
        if any(w in who for w in ("kwin", "screencast", "xdg-desktop-portal", "screen")) and not who.startswith(("v4l2", "libcamera")):
            out["rec"].append(p.get("application.name") or p.get("media.name") or "Screen")
except Exception: pass

# browser downloads in progress: partial files written to in the last 20 s
import time
for pat, browser in (("*.part", "Firefox"), ("*.crdownload", "Browser")):
    for f in glob.glob(os.path.expanduser("~/Downloads/" + pat)):
        try:
            st = os.stat(f)
            if time.time() - st.st_mtime < 20:
                name = os.path.basename(f).rsplit(".", 1)[0]
                if name.startswith("Unconfirmed "): name = "Download"
                out["dl"].append({"name": name, "bytes": st.st_size, "from": browser, "path": f})
        except Exception: pass
# finished files from the last 15 s (to tell a finished download from a cancelled one)
out["recent"] = [os.path.basename(f) for f in glob.glob(os.path.expanduser("~/Downloads/*"))
                 if not f.endswith((".part", ".crdownload")) and time.time() - os.path.getmtime(f) < 15]

for line in run("bluetoothctl", "devices", "Connected").splitlines():
    parts = line.split(" ", 2)
    if len(parts) == 3 and parts[0] == "Device": out["bt"].append(parts[2])

cfg = configparser.RawConfigParser(strict=False, interpolation=None)
cfg.optionxform = str
try:
    cfg.read(os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc"))
    # section names lose their outer brackets: "Containments][139][Applets][208"
    for sec in cfg.sections():
        if cfg.get(sec, "plugin", fallback="") == "org.frost.focus":
            name = sec + "][Configuration][General"
            g = cfg[name] if cfg.has_section(name) else {}
            num = lambda k, d: int(g.get(k, d) or d)
            phase = g.get("phase", "idle")
            left = num("pausedLeft", 0)
            # full length of the current phase, for the progress ring
            total = num("focusMinutes", 25) * 60 if phase.endswith("focus") else num("breakMinutes", 5) * 60
            if phase.endswith("break") and left > total: total = num("longBreakMinutes", 15) * 60
            out["focus"] = {"phase": phase, "endsAt": num("endsAt", 0), "pausedLeft": left,
                            "total": total, "project": g.get("project", "")}
        elif cfg.get(sec, "plugin", fallback="") == "org.frost.weather":
            name = sec + "][Configuration][General"
            g = cfg[name] if cfg.has_section(name) else {}
            out["loc"] = {"lat": float(g.get("latitude", 12.2958)), "lon": float(g.get("longitude", 76.6394)),
                          "city": g.get("city", "Mysuru")}
except Exception: pass

print(json.dumps(out))
