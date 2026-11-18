#!/usr/bin/env python3
"""Beat bars for the Frost Music widget.

Runs `cava` (reads the audio going to your speakers, nothing is recorded or
stored) and serves the latest bar heights as JSON on 127.0.0.1 only. Exits on
its own after 10 seconds without a request, so it only runs while the widget
is showing music. Starting it twice is harmless: the second copy can't bind
the port and quits.
"""
import http.server, os, socketserver, subprocess, tempfile, threading, time

PORT, BARS, IDLE = 47821, 28, 10
latest = "[]"
last_hit = time.time()

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

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global last_hit
        last_hit = time.time()
        body = latest.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass

try:
    srv = socketserver.TCPServer(("127.0.0.1", PORT), H)
except OSError:
    raise SystemExit(0)          # already running

cava = subprocess.Popen(["cava", "-p", conf.name], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

def reader():
    global latest
    for line in cava.stdout:
        vals = [v for v in line.strip().split(";") if v]
        latest = "[" + ",".join(vals) + "]"

def watchdog():
    while time.time() - last_hit < IDLE and cava.poll() is None:
        time.sleep(1)
    cava.terminate(); os.unlink(conf.name); srv.shutdown()

threading.Thread(target=reader, daemon=True).start()
threading.Thread(target=watchdog, daemon=True).start()
srv.serve_forever()
