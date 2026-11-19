#!/usr/bin/env python3
"""Developer sources for Frost Spotlight. Prints JSON.
  dev.py projects        folders in ~/dev (and one level below) that look like projects, newest first
  dev.py files QUERY     file / folder names in your home matching QUERY (plocate's daily index)
  dev.py repos           your GitHub repositories (gh CLI)
"""
import json, os, subprocess, sys

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


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "projects"
    print(json.dumps(projects() if cmd == "projects" else files(" ".join(sys.argv[2:])) if cmd == "files" else repos()))
