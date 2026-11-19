#!/usr/bin/env python3
"""Developer sources for Frost Spotlight. Prints JSON.
  dev.py projects        folders in ~/dev (and one level below) that look like projects, newest first
  dev.py files QUERY     file / folder names in your home matching QUERY (plocate's daily index)
  dev.py repos           your GitHub repositories (gh CLI)
  dev.py info TARGET     details for the preview pane: a path, a file:// URL or an app's .desktop
"""
import glob, json, mimetypes, os, subprocess, sys, time, urllib.parse

HOME = os.path.expanduser("~")
DEV = os.path.join(HOME, "dev")
MARKS = (".git", "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "pom.xml",
         "build.gradle", "CMakeLists.txt", "Makefile", "requirements.txt", "pubspec.yaml")
SKIP = ("/.cache/", "/.local/", "/node_modules/", "/.git/", "/snap/", "/.mozilla/", "/.config/",
        "/__pycache__/", "/.venv/", "/venv/", "/.gradle/", "/.npm/", "/.cargo/", "/.rustup/",
        "/.vscode/", "/.android/", "/Trash/")


def is_project(p):
    return any(os.path.exists(os.path.join(p, m)) for m in MARKS)


def recent(p):
    g = os.path.join(p, ".git")
    try:
        return max(os.path.getmtime(p), os.path.getmtime(g) if os.path.isdir(g) else 0)
    except OSError:
        return 0


def projects():
    found = []
    for a in sorted(os.listdir(DEV)) if os.path.isdir(DEV) else []:
        p = os.path.join(DEV, a)
        if a.startswith(".") or not os.path.isdir(p):
            continue
        subs = [os.path.join(p, b) for b in os.listdir(p)
                if not b.startswith(".") and os.path.isdir(os.path.join(p, b)) and is_project(os.path.join(p, b))]
        found += subs
        if is_project(p) or not subs:
            found.append(p)
    out = [{"name": os.path.basename(x), "rel": os.path.relpath(x, DEV), "path": x,
            "git": os.path.isdir(os.path.join(x, ".git")), "t": recent(x)} for x in found]
    out.sort(key=lambda r: -r["t"])
    return out


def files(q):
    """Name matches in your home, skipping hidden folders, SDKs and build output;
    exact / prefix name matches and your usual folders first."""
    ql = q.lower()
    fav = [os.path.join(HOME, d) + "/" for d in ("dev", "Documents", "Downloads", "Desktop", "Pictures", "Videos", "Music")]
    scored = []
    # stream every match (short queries match mostly hidden folders first) and
    # stop once there are plenty of good candidates
    try:
        proc = subprocess.Popen(["plocate", "-i", "-b", q], stdout=subprocess.PIPE, text=True, errors="replace")
    except Exception:
        return []
    for f in proc.stdout:
        f = f.rstrip("\n")
        if len(scored) >= 400:
            break
        if not f.startswith(HOME + "/"):
            continue
        rel = f[len(HOME) + 1:]
        if any(part.startswith(".") for part in rel.split("/")) or any(s in f + "/" for s in SKIP) \
                or "/Android/Sdk/" in f or rel.startswith(("snap/", "Android/", "go/pkg/")):
            continue
        name = os.path.basename(f).lower()
        score = (0 if name == ql else 1 if name.startswith(ql) else 2) * 10 \
                + (0 if any(f.startswith(d) for d in fav) else 5) + min(rel.count("/"), 4)
        scored.append((score, f))
    proc.kill()
    out = []
    for _, f in sorted(scored)[:40]:
        if os.path.exists(f):
            out.append({"name": os.path.basename(f), "path": f, "dir": os.path.isdir(f)})
        if len(out) >= 8:
            break
    return out


def repos():
    try:
        r = subprocess.run(["gh", "repo", "list", "--limit", "200", "--json", "nameWithOwner,description,url"],
                           capture_output=True, text=True, timeout=15)
        return json.loads(r.stdout or "[]")
    except Exception:
        return []


def when(t):
    d = time.time() - t
    if d < 60: return "just now"
    if d < 3600: return f"{int(d // 60)} min ago"
    if d < 86400: return f"{int(d // 3600)} h ago"
    if d < 7 * 86400: return f"{int(d // 86400)} days ago"
    return time.strftime("%-d %b %Y", time.localtime(t))


def human(n):
    for u in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or u == "TB":
            return f"{n:.0f} {u}" if u == "B" else f"{n:.1f} {u}"
        n /= 1024


def desktop_file(name):
    """applications:foo.desktop / foo.desktop -> the file in the XDG data dirs"""
    name = name.split(":", 1)[-1].lstrip("/")
    dirs = [os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))] \
        + os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") + ["/var/lib/flatpak/exports/share"]
    for d in dirs:
        for f in [os.path.join(d, "applications", name)] + glob.glob(os.path.join(d, "applications", "**", name), recursive=True):
            if os.path.isfile(f):
                return f
    return None


def app(path):
    e, sec = {}, None
    for line in open(path, errors="replace"):
        line = line.strip()
        if line.startswith("["):
            sec = line
        elif sec == "[Desktop Entry]" and "=" in line:
            k, v = line.split("=", 1)
            e.setdefault(k, v)
    rows = [["Kind", e.get("GenericName") or "Application"]]
    if e.get("Exec"): rows.append(["Runs", " ".join(w for w in e["Exec"].split() if not w.startswith("%"))])
    if e.get("Categories"): rows.append(["Categories", ", ".join(c for c in e["Categories"].split(";") if c)[:80]])
    rows.append(["Desktop file", path.replace(HOME, "~")])
    return {"kind": "app", "about": e.get("Comment", ""), "rows": rows}


def git(path, *a):
    try:
        return subprocess.run(["git", "-C", path, *a], capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        return ""


def info(target):
    if target.startswith("file://"):
        target = urllib.parse.unquote(urllib.parse.urlparse(target).path)
    if target.startswith("applications:") or (target.endswith(".desktop") and not os.path.isabs(target)):
        f = desktop_file(target)
        return app(f) if f else {}
    if target.endswith(".desktop") and os.path.isfile(target):
        return app(target)
    if not os.path.exists(target):
        return {}
    st = os.stat(target)
    where = os.path.dirname(target).replace(HOME, "~", 1)
    if os.path.isdir(target):
        try:
            n = len([x for x in os.listdir(target) if not x.startswith(".")])
        except OSError:
            n = 0
        rows = [["Kind", "Project folder" if is_project(target) else "Folder"], ["Items", str(n)],
                ["Modified", when(recent(target))], ["Where", where]]
        out = {"kind": "dir", "rows": rows}
        if os.path.isdir(os.path.join(target, ".git")):
            br = git(target, "branch", "--show-current")
            last = git(target, "log", "-1", "--format=%s\x1f%cr")
            if br: rows.insert(1, ["Branch", br])
            if last and "\x1f" in last:
                msg, ago = last.split("\x1f", 1)
                out["about"] = msg
                rows.insert(2, ["Last commit", ago])
            dirty = git(target, "status", "--porcelain")
            rows.insert(2, ["Changes", f"{len(dirty.splitlines())} uncommitted" if dirty else "clean"])
        return out
    mime = mimetypes.guess_type(target)[0] or ""
    if not mime:
        try:
            mime = subprocess.run(["file", "-b", "--mime-type", target], capture_output=True, text=True, timeout=2).stdout.strip()
        except Exception:
            mime = ""
    rows = [["Kind", mime or "File"], ["Size", human(st.st_size)], ["Modified", when(st.st_mtime)], ["Where", where]]
    out = {"kind": "image" if mime.startswith("image/") else "file", "rows": rows, "path": target}
    textish = mime.startswith("text/") or mime in ("application/json", "application/xml", "application/javascript",
                                                    "application/x-shellscript", "application/toml", "application/x-yaml")
    if not textish and not mime and st.st_size < 2_000_000:
        textish = True
    if textish and st.st_size < 4_000_000:
        try:
            with open(target, "rb") as fh:
                head = fh.read(4096)
            if b"\0" not in head:
                lines = head.decode("utf-8", "replace").splitlines()[:24]
                out["text"] = "\n".join(l[:160] for l in lines)
        except OSError:
            pass
    return out


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "projects"
    arg = " ".join(sys.argv[2:])
    print(json.dumps(projects() if cmd == "projects" else files(arg) if cmd == "files"
                     else info(arg) if cmd == "info" else repos()))
