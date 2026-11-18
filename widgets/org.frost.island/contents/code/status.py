#!/usr/bin/env python3
"""One read-only snapshot for the Dynamic Island, printed as JSON:
battery, microphone in use (by anything except cava), connected Bluetooth
devices, and the Frost Focus timer's state (read from its widget settings)."""
import configparser, glob, json, os, subprocess

def run(*a, t=3):
    try: return subprocess.run(a, capture_output=True, text=True, timeout=t).stdout
    except Exception: return ""

out = {"battery": None, "mic": [], "bt": [], "focus": None}

bat = (glob.glob("/sys/class/power_supply/BAT*") or [None])[0]
if bat:
    rd = lambda f: open(os.path.join(bat, f)).read().strip()
    try: out["battery"] = {"pct": int(rd("capacity")), "status": rd("status")}
    except Exception: pass

try:
    sources = {s["index"]: s["name"] for s in json.loads(run("pactl", "-f", "json", "list", "sources", "short") or "[]")}
    for o in json.loads(run("pactl", "-f", "json", "list", "source-outputs") or "[]"):
        app = o.get("properties", {}).get("application.name", "") or ""
        if not sources.get(o.get("source"), "").endswith(".monitor") and app.lower() != "cava":
            out["mic"].append(app or "An app")
except Exception: pass

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
            break
except Exception: pass

print(json.dumps(out))
