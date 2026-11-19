#!/usr/bin/env python3
"""Beat bars for the Frost Music widget and the Dynamic Island.

Runs `cava` (reads the audio going to your speakers, nothing is recorded or
stored) and serves the latest bar heights as JSON on 127.0.0.1 only. Exits on
its own after a minute without a request, so it only runs while a widget is
showing music (and a pause of under a minute never needs a restart). Starting
it twice is harmless: the second copy can't bind the port and quits.

A short log of starts, stops and requests goes to ~/.cache/frost-beats.log.
"""
import http.server, os, socketserver, subprocess, tempfile, threading, time

PORT, BARS, IDLE = 47821, 28, 60
LOG = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "frost-beats.log")
latest = "[]"
last_hit = time.time()
hits = 0
frames = 0


def log(msg):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        if os.path.exists(LOG) and os.path.getsize(LOG) > 200_000:
            os.replace(LOG, LOG + ".old")
        with open(LOG, "a") as f:
            f.write(f"{time.strftime('%F %T')} [{os.getpid()}] {msg}\n")
    except OSError:
        pass


class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global last_hit, hits
        last_hit = time.time()
        hits += 1
        body = latest.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True      # rebind at once after a previous copy stopped
    daemon_threads = True


try:
    srv = Server(("127.0.0.1", PORT), H)
except OSError as e:
    log(f"not starting: port {PORT} busy ({e.strerror}); another copy is running")
    raise SystemExit(0)

conf = tempfile.NamedTemporaryFile("w", suffix=".cava", delete=False)
conf.write(f"""[general]
bars = {BARS}
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
[smoothing]
noise_reduction = 70
""")
conf.close()

try:
    cava = subprocess.Popen(["cava", "-p", conf.name], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
except OSError as e:
    log(f"cava could not start: {e}")
    os.unlink(conf.name)
    raise SystemExit(1)
log("started, cava running")


def reader():
    global latest, frames
    for line in cava.stdout:
        vals = [v for v in line.strip().split(";") if v]
        latest = "[" + ",".join(vals) + "]"
        frames += 1


def watchdog():
    seen_hits, seen_frames = 0, 0
    while time.time() - last_hit < IDLE and cava.poll() is None:
        time.sleep(5)
        # every 5 s: how many requests the widgets made and frames cava sent
        if hits != seen_hits or frames == seen_frames:
            log(f"requests {hits - seen_hits}, cava frames {frames - seen_frames}")
        seen_hits, seen_frames = hits, frames
    if cava.poll() is not None:
        log(f"cava exited with {cava.returncode}")
    else:
        log(f"no requests for {IDLE} s, stopping")
        cava.terminate()
    try:
        os.unlink(conf.name)
    except OSError:
        pass
    srv.shutdown()


threading.Thread(target=reader, daemon=True).start()
threading.Thread(target=watchdog, daemon=True).start()
srv.serve_forever()
srv.server_close()
log("stopped")
