#!/usr/bin/env python3
"""Live sound and brightness levels for the Frost widgets.

Watches PipeWire (`pactl subscribe`) and KDE's screen brightness (D-Bus
signals) and serves the current state as JSON on 127.0.0.1 only:

    GET /state?since=N   answers as soon as the state is newer than version N
                         (or after 20 s with the same state), so the widgets
                         update the moment something changes, without polling.

State: volume / mute of the default output and input, brightness, the list of
outputs and inputs (which one is the default, which are Bluetooth) and the apps
playing sound. Changes are made by the widgets themselves (wpctl / pactl).

Exits on its own after a minute without a request. Starting it twice is
harmless: the second copy can't bind the port and quits.
"""
import http.server, json, os, socketserver, subprocess, threading, time
from urllib.parse import urlparse, parse_qs

PORT, IDLE, WAIT = 47822, 60, 20
BD = ["qdbus6", "org.kde.ScreenBrightness", "/org/kde/ScreenBrightness/display0", "org.kde.ScreenBrightness.Display."]

state = {"ver": 0}
cond = threading.Condition()
last_hit = time.time()
dirty = threading.Event()


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def plist(kind):
    try:
        return json.loads(run("pactl", "-f", "json", "list", kind) or "[]")
    except ValueError:
        return []


def level(x):
    vols = [v.get("value", 0) for v in (x.get("volume") or {}).values()]
    return round(sum(vols) / len(vols) / 65536, 3) if vols else 0


def device(x, default, output):
    p = x.get("properties", {})
    desc = x.get("description") or p.get("node.description") or x.get("name", "")
    # the built-in sound card has a long chip name: call it what it is
    if p.get("device.bus") == "pci" and "analog" in x.get("name", "") and "HDMI" not in desc:
        desc = "Laptop speakers" if output else "Laptop microphone"
    return {"name": x.get("name", ""), "desc": desc,
            "bt": p.get("device.bus") == "bluetooth", "icon": p.get("device.icon_name", ""),
            "default": x.get("name") == default, "vol": level(x), "muted": bool(x.get("mute"))}


def collect():
    dsink = run("pactl", "get-default-sink").strip()
    dsrc = run("pactl", "get-default-source").strip()
    sinks = [device(x, dsink, True) for x in plist("sinks")
             if x.get("properties", {}).get("media.class") == "Audio/Sink"]
    sources = [device(x, dsrc, False) for x in plist("sources")
               if x.get("properties", {}).get("media.class") == "Audio/Source"]
    apps = []
    for x in plist("sink-inputs"):
        p = x.get("properties", {})
        name = p.get("application.name") or p.get("node.name") or "App"
        if name.startswith("PipeWire ALSA"):           # e.g. "PipeWire ALSA [mechkeys]"
            name = name.split("[", 1)[-1].rstrip("]") or name
        apps.append({"index": x.get("index"), "name": name, "vol": level(x), "muted": bool(x.get("mute")),
                     "icon": p.get("application.icon_name") or (p.get("application.process.binary") or name).lower(),
                     "playing": not x.get("corked")})
    out = next((s for s in sinks if s["default"]), None)
    inp = next((s for s in sources if s["default"]), None)
    light, lmax = run(*BD[:3], BD[3] + "Brightness").strip(), run(*BD[:3], BD[3] + "MaxBrightness").strip()
    try:
        light = int(light) / max(1, int(lmax))
    except ValueError:
        light = -1
    return {"vol": out["vol"] if out else 0, "volMuted": out["muted"] if out else False,
            "mic": inp["vol"] if inp else 0, "micMuted": inp["muted"] if inp else False,
            "output": out["desc"] if out else "", "input": inp["desc"] if inp else "",
            "light": light, "lightMax": int(lmax) if lmax.isdigit() else 1,
            "sinks": sinks, "sources": sources, "apps": apps}


def refresher():
    """Re-read everything when told something changed (bursts are merged)."""
    while True:
        dirty.wait()
        time.sleep(0.04)
        dirty.clear()
        new = collect()
        with cond:
            if any(state.get(k) != v for k, v in new.items()):
                state.update(new)
                state["ver"] += 1
                cond.notify_all()


def watch(cmd, match):
    while True:
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            for line in p.stdout:
                if match(line):
                    dirty.set()
        except OSError:
            pass
        time.sleep(3)          # pipewire or the bus restarted: start watching again
        dirty.set()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global last_hit
        last_hit = time.time()
        q = parse_qs(urlparse(self.path).query)
        since = int((q.get("since") or ["-1"])[0] or -1)
        with cond:
            cond.wait_for(lambda: state["ver"] > since and state["ver"] > 0, timeout=WAIT)
            body = json.dumps(state).encode()
        last_hit = time.time()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


try:
    srv = Server(("127.0.0.1", PORT), Handler)
except OSError:
    raise SystemExit(0)        # already running

threading.Thread(target=refresher, daemon=True).start()
threading.Thread(target=watch, args=(["pactl", "subscribe"],
                 lambda l: any(w in l for w in ("sink", "source", "server", "card"))), daemon=True).start()
threading.Thread(target=watch, args=(["dbus-monitor", "--session",
                 "type='signal',interface='org.kde.ScreenBrightness'",
                 "type='signal',interface='org.kde.ScreenBrightness.Display'"],
                 lambda l: "member=" in l), daemon=True).start()

def safety_net():          # in case an event was missed
    while True:
        time.sleep(30)
        dirty.set()


threading.Thread(target=safety_net, daemon=True).start()
dirty.set()


def idle():
    while time.time() - last_hit < IDLE:
        time.sleep(5)
    srv.shutdown()


threading.Thread(target=idle, daemon=True).start()
srv.serve_forever()
