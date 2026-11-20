#!/usr/bin/env bash
# Prints one JSON object describing the network, KDE Connect devices and
# Tailscale. Read-only; called by the Device Ecosystem widget every 20 s.
python3 - <<'PY'
import json, subprocess as sp
def run(*a):
    try: return sp.run(a, capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception: return ""
out = {"net": {}, "phones": [], "tailscale": {"state": "Absent", "peers": []}}
r = run("ip", "-4", "route", "get", "1.1.1.1").split()
if "dev" in r:
    dev = r[r.index("dev") + 1]; ip = r[r.index("src") + 1] if "src" in r else ""
    kind = "Wi-Fi" if dev.startswith("wl") else "Ethernet" if dev.startswith(("en", "eth")) else dev
    ssid = run("nmcli", "-g", "GENERAL.CONNECTION", "device", "show", dev)
    out["net"] = {"dev": dev, "ip": ip, "kind": kind, "name": ssid}
reach = set(run("kdeconnect-cli", "-a", "--id-only").split())
for line in run("kdeconnect-cli", "-l", "--id-name-only").splitlines():
    if " " not in line: continue
    i, name = line.split(" ", 1)
    p = {"id": i, "name": name, "reachable": i in reach, "battery": -1, "charging": False}
    if p["reachable"]:
        base = ["qdbus6", "org.kde.kdeconnect", f"/modules/kdeconnect/devices/{i}/battery"]
        c = run(*base, "org.kde.kdeconnect.device.battery.charge")
        p["battery"] = int(c) if c.lstrip("-").isdigit() else -1
        p["charging"] = run(*base, "org.kde.kdeconnect.device.battery.isCharging") == "true"
    out["phones"].append(p)
try:
    t = json.loads(run("tailscale", "status", "--json") or "{}")
    if t:
        out["tailscale"] = {"state": t.get("BackendState", "?"),
                            "self": (t.get("Self", {}).get("TailscaleIPs") or [""])[0],
                            "peers": [{"name": p.get("HostName", "?"), "os": p.get("OS", ""), "online": p.get("Online", False),
                                       "lastSeen": p.get("LastSeen", ""), "ip": (p.get("TailscaleIPs") or [""])[0]}
                                      for p in (t.get("Peer") or {}).values()]}
except Exception: pass
# what the phone last told Frost Link (battery, music, screen time), if recent
try:
    import os, time
    f = os.path.expanduser("~/.local/share/frost/link/phone.json")
    ph = json.load(open(f))
    ph["fresh"] = time.time() - ph.get("received", 0) < 600
    out["frost"] = ph
except Exception: pass
print(json.dumps(out))
PY
