#!/usr/bin/env python3
"""Put the Frost terminal themes (build/terminal/) in place, or take them out.

    apply.py install [--image]     only for the apps that are installed
    apply.py revert

Three kinds of change, each undone its own way:
  * files Frost owns (theme files): copied in; a file that was already there is
    backed up first and restored on revert, otherwise revert deletes it
  * one marked line added to a config you edit yourself (~/.bashrc, init.lua,
    config.kdl ...): revert removes just that line and its marker
  * one setting changed in a config (btop's color_theme, Konsole's profile,
    k9s's skin ...): the old value is kept and put back on revert, unless you
    changed that setting again since

Everything is recorded in ~/.local/share/glass-theme/terminal/manifest.json.
"""
import hashlib, json, os, re, shutil, subprocess, sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
B = REPO / "build" / "terminal"
HOME = Path.home()
CFG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = HOME / ".local/share/glass-theme/terminal"
MANIFEST = STATE / "manifest.json"
MARK = "frost-terminal"
MISSING = "__frost_missing__"

m = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
for _k in ("owned", "lines", "keys", "dirs", "created"):
    m.setdefault(_k, {} if _k != "dirs" else [])
done, skipped = [], []


def save():
    STATE.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(m, indent=2))


def mkdirs(d):
    """mkdir -p that remembers which folders it made, so revert can remove them."""
    d = Path(d)
    new = []
    while not d.exists():
        new.append(str(d))
        d = d.parent
    for x in reversed(new):
        Path(x).mkdir()
        if x not in m["dirs"]:
            m["dirs"].append(x)


def have(*cmds):
    return any(shutil.which(c) for c in cmds)


# ── the three kinds of change ────────────────────────────────────────────────
def own(src, dst):
    """Copy a Frost file in, backing up whatever was there before (once)."""
    dst = Path(dst)
    key = str(dst)
    if key not in m["owned"]:
        backup = None
        if dst.exists() and dst.read_bytes() != Path(src).read_bytes():
            backup = STATE / "backup" / dst.relative_to(HOME)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, backup)
            backup = str(backup)
        m["owned"][key] = backup
    mkdirs(dst.parent)
    shutil.copyfile(src, dst)


def own_text(text, dst):
    tmp = STATE / "tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    f = tmp / Path(dst).name
    f.write_text(text)
    own(f, dst)


def add_line(file, line, comment="#"):
    """Append `line` (with a marker comment above it) unless it is already there."""
    file = Path(file)
    text = file.read_text() if file.exists() else ""
    marker = f"{comment} {MARK}"
    if marker in text:
        return
    if text and not text.endswith("\n"):
        text += "\n"
    if not file.exists():
        m["created"][str(file)] = True     # revert deletes it again once it's empty
    mkdirs(file.parent)
    file.write_text(text + f"{marker}\n{line}\n")
    m["lines"][str(file)] = comment


def set_line(file, pattern, new):
    """Replace the first line matching `pattern` with `new` (or append it)."""
    file = Path(file)
    lines = file.read_text().splitlines()
    rx = re.compile(pattern)
    idx = next((i for i, ln in enumerate(lines) if rx.match(ln)), None)
    old = lines[idx] if idx is not None else MISSING
    key = f"line:{file}:{pattern}"
    if key not in m["keys"]:
        m["keys"][key] = {"kind": "line", "file": str(file), "pattern": pattern, "old": old, "new": new}
    if idx is None:
        lines.append(new)
    else:
        lines[idx] = new
    file.write_text("\n".join(lines) + "\n")


def _dig(d, path):
    for k in path[:-1]:
        d = d.setdefault(k, {}) if isinstance(d, dict) else {}
    return d


def set_yaml(file, path, value):
    file = Path(file)
    orig = file.read_text() if file.exists() else None
    data = (yaml.safe_load(orig) if orig else None) or {}
    parent = _dig(data, path)
    key = f"yaml:{file}:{'.'.join(path)}"
    if key not in m["keys"]:
        m["keys"][key] = {"kind": "yaml", "file": str(file), "path": path,
                          "old": parent.get(path[-1], MISSING), "new": value, "orig": orig}
    parent[path[-1]] = value
    mkdirs(file.parent)
    file.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))


def set_ini(file, group, keyname, value):
    file = str(file)
    old = subprocess.run(["kreadconfig6", "--file", file, "--group", group, "--key", keyname, "--default", MISSING],
                         capture_output=True, text=True).stdout.strip()
    key = f"ini:{file}:{group}:{keyname}"
    if key not in m["keys"]:
        m["keys"][key] = {"kind": "ini", "file": file, "group": group, "key": keyname, "old": old, "new": value}
    subprocess.run(["kwriteconfig6", "--file", file, "--group", group, "--key", keyname, value], check=True)


def patch_file(file, transform):
    """Whole-file edit for configs with many colour settings (fastfetch): back
    up the original; revert restores it only if the file is still as we left it."""
    file = Path(file)
    original = file.read_text()
    new = transform(original)
    key = f"file:{file}"
    if key not in m["keys"]:
        backup = STATE / "backup" / file.relative_to(HOME)
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_text(original)
        m["keys"][key] = {"kind": "file", "file": str(file), "backup": str(backup)}
    file.write_text(new)
    m["keys"][key]["hash"] = hashlib.sha256(new.encode()).hexdigest()


# ── the apps ─────────────────────────────────────────────────────────────────
def kitty(image):
    d = CFG / "kitty"
    if not have("kitty") or not d.exists():
        return skipped.append("kitty")
    own(B / "kitty/frost-obsidian.conf", d / "frost-obsidian.conf")
    conf = d / "kitty.conf"
    if "include frost-obsidian.conf" not in conf.read_text():
        add_line(conf, "include frost-obsidian.conf")
    if image:
        own(B / "wallpaper/terminal-bg.png", HOME / ".local/share/frost/terminal-bg.png")
        own(B / "kitty/frost-image.conf", d / "frost-image.conf")
        if "include frost-image.conf" not in conf.read_text():
            add_line(conf, "include frost-image.conf")
    done.append("kitty" + (" (+ wallpaper)" if image else ""))


def konsole(image):
    if not have("konsole", "yakuake"):
        return skipped.append("Konsole")
    scheme = (B / "konsole/Frost.colorscheme").read_text()
    if image:
        own(B / "wallpaper/terminal-bg.png", HOME / ".local/share/frost/terminal-bg.png")
        scheme = scheme.replace("Wallpaper=\n", f"Wallpaper={HOME}/.local/share/frost/terminal-bg.png\n")
    own_text(scheme, HOME / ".local/share/konsole/Frost.colorscheme")
    rc = CFG / "konsolerc"
    prof = subprocess.run(["kreadconfig6", "--file", str(rc), "--group", "Desktop Entry", "--key", "DefaultProfile"],
                          capture_output=True, text=True).stdout.strip()
    if prof:
        set_ini(HOME / ".local/share/konsole" / prof, "Appearance", "ColorScheme", "Frost")
    else:
        own_text("[Appearance]\nColorScheme=Frost\nFont=JetBrains Mono,10,-1,5,400,0,0,0,0,0\n\n"
                 "[General]\nName=Frost\nParent=FALLBACK/\n", HOME / ".local/share/konsole/Frost.profile")
        set_ini(rc, "Desktop Entry", "DefaultProfile", "Frost.profile")
    done.append("Konsole / Yakuake")


def zellij():
    d = CFG / "zellij"
    if not have("zellij"):
        return skipped.append("Zellij")
    own(B / "zellij/frost.kdl", d / "themes/frost.kdl")
    conf = d / "config.kdl"
    if conf.exists() and re.search(r'^\s*theme\s+"', conf.read_text(), re.M) and f"// {MARK}" not in conf.read_text():
        print('  Zellij: config.kdl already picks a theme; change it to  theme "frost"  to use Frost')
    else:
        add_line(conf, 'theme "frost"', "//")
    done.append("Zellij")


def editors():
    if have("nvim"):
        d = CFG / "nvim"
        own(B / "vim/frost.vim", d / "colors/frost.vim")
        if (d / "init.lua").exists():
            add_line(d / "init.lua", 'pcall(vim.cmd.colorscheme, "frost")', "--")
        elif (d / "init.vim").exists():
            add_line(d / "init.vim", "silent! colorscheme frost", '"')
        else:
            own_text('pcall(vim.cmd.colorscheme, "frost")\n', d / "init.lua")
        done.append("Neovim")
    if have("vim"):
        own(B / "vim/frost.vim", HOME / ".vim/colors/frost.vim")
        rc = HOME / ".vimrc" if (HOME / ".vimrc").exists() or not (HOME / ".vim/vimrc").exists() else HOME / ".vim/vimrc"
        if rc.exists():
            add_line(rc, "silent! colorscheme frost", '"')
        else:
            own(B / "vim/vimrc", rc)
        done.append("Vim")


def bat():
    exe = "batcat" if have("batcat") else None
    if not exe:
        return skipped.append("bat")
    d = Path(subprocess.run([exe, "--config-dir"], capture_output=True, text=True).stdout.strip())
    own(B / "bat/Frost.tmTheme", d / "themes/Frost.tmTheme")
    subprocess.run([exe, "cache", "--build"], capture_output=True)
    if (d / "config").exists():
        set_line(d / "config", r'^\s*--theme[= ]', '--theme="Frost"')
    done.append("bat (+ man pages)")


def shell():
    own(B / "shell/terminal.sh", CFG / "frost/terminal.sh")
    own(B / "shell/dircolors", CFG / "frost/dircolors")
    line = "[ -r ~/.config/frost/terminal.sh ] && . ~/.config/frost/terminal.sh"
    for rc in (HOME / ".bashrc", HOME / ".zshrc"):
        if rc.exists():
            add_line(rc, line)
    done.append("shell: LS_COLORS, fzf, less, nnn")


def lsd_eza():
    if have("lsd"):
        own(B / "lsd/colors.yaml", CFG / "lsd/colors.yaml")
        set_yaml(CFG / "lsd/config.yaml", ["color", "theme"], "custom")
        done.append("lsd")
    if have("eza"):
        own(B / "eza/theme.yml", CFG / "eza/theme.yml")
        done.append("eza")


def tuis():
    for app in ("lazygit", "lazydocker"):
        if have(app):
            set_yaml(CFG / app / "config.yml", ["gui", "theme"], json.loads((B / app / "theme.json").read_text()))
            done.append(app)
    if have("k9s"):
        own(B / "k9s/frost.yaml", CFG / "k9s/skins/frost.yaml")
        set_yaml(CFG / "k9s/config.yaml", ["k9s", "ui", "skin"], "frost")
        done.append("k9s")


def monitors():
    if have("btop"):
        theme = CFG / "btop/themes/frost.theme"
        own(B / "btop/frost.theme", theme)
        conf = CFG / "btop/btop.conf"
        if conf.exists():
            set_line(conf, r"^color_theme\s*=", f'color_theme = "{theme}"')
            set_line(conf, r"^truecolor\s*=", "truecolor = true")
        else:
            own_text(f'color_theme = "{theme}"\ntruecolor = true\n', conf)
        done.append("btop")
    if have("bottom", "btm"):
        snap = HOME / "snap/bottom/current"
        dst = (snap / ".config/bottom/bottom.toml") if snap.exists() else (CFG / "bottom/bottom.toml")
        own(B / "bottom/bottom.toml", dst)
        done.append("bottom")


def files():
    if have("yazi"):
        own(B / "yazi/theme.toml", CFG / "yazi/theme.toml")
        done.append("yazi")
    if have("ranger"):
        own(B / "ranger/frost.py", CFG / "ranger/colorschemes/frost.py")
        add_line(CFG / "ranger/rc.conf", "set colorscheme frost")
        done.append("ranger")
    if have("nnn"):
        done.append("nnn (through the shell file)")


def fastfetch():
    conf = CFG / "fastfetch/config.jsonc"
    if not have("fastfetch") or not conf.exists():
        return skipped.append("fastfetch")
    try:
        json.loads(conf.read_text())
    except ValueError:
        print("  fastfetch: config.jsonc has comments, which this script can't edit safely; skipped")
        return skipped.append("fastfetch")

    def recolour(text):
        data = json.loads(text)
        logo = data.setdefault("logo", {})
        logo["color"] = {"1": "red", "2": "white"}
        data.setdefault("display", {}).setdefault("color", {})["separator"] = "90"
        for mod in data.get("modules", []):
            if isinstance(mod, dict):
                if "keyColor" in mod:
                    mod["keyColor"] = "red"
                if mod.get("type") == "custom" and "outputColor" in mod:
                    mod["outputColor"] = "90"
        return json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    patch_file(conf, recolour)
    done.append("fastfetch")


def glow():
    if not have("glow"):
        return skipped.append("glow")
    own(B / "glow/frost.json", CFG / "glow/frost.json")
    conf = CFG / "glow/glow.yml"
    if conf.exists():
        set_line(conf, r"^style\s*:", f'style: "{CFG}/glow/frost.json"')
    else:
        own_text(f'style: "{CFG}/glow/frost.json"\n', conf)
    done.append("glow")


def music():
    if have("cava"):
        dst = CFG / "cava/config"
        if dst.exists() and str(dst) not in m["owned"]:
            print("  cava: you have your own ~/.config/cava/config; copy the [color] section from build/terminal/cava/config")
        else:
            own(B / "cava/config", dst)
            done.append("cava (the terminal one; the island's beat bars have their own)")
    if have("cmus"):
        own(B / "cmus/frost.theme", CFG / "cmus/frost.theme")
        add_line(CFG / "cmus/rc", "colorscheme frost")
        done.append("cmus")
    if have("newsboat"):
        own(B / "newsboat/frost", CFG / "frost/newsboat")
        conf = (HOME / ".newsboat/config") if (HOME / ".newsboat").is_dir() else (CFG / "newsboat/config")
        add_line(conf, f'include "{CFG}/frost/newsboat"')
        done.append("newsboat")


def git():
    if not have("git"):
        return
    own(B / "git/git.conf", CFG / "frost/git.conf")
    path = "~/.config/frost/git.conf"
    have_it = subprocess.run(["git", "config", "--global", "--get-all", "include.path"], capture_output=True, text=True).stdout.split()
    if path not in have_it:
        subprocess.run(["git", "config", "--global", "--add", "include.path", path], check=True)
    m["git"] = path
    done.append("git")


# ── install / revert ─────────────────────────────────────────────────────────
def install(image):
    if not B.exists():
        sys.exit("build/terminal/ is missing: run extras/terminal/build_terminal.py first")
    mkdirs(STATE)
    try:
        for step in (lambda: kitty(image), lambda: konsole(image), zellij, editors, bat, shell, lsd_eza, tuis,
                     monitors, files, fastfetch, glow, music, git):
            step()
    finally:
        save()
    print("Frost is on: " + ", ".join(done))
    if skipped:
        print("Not installed here, skipped: " + ", ".join(skipped))


def revert():
    if not MANIFEST.exists():
        sys.exit("Nothing to revert: the Frost terminal themes aren't installed.")
    notes = []
    for key, k in reversed(list(m["keys"].items())):
        f = Path(k["file"])
        if k["kind"] == "line" and f.exists():
            lines = f.read_text().splitlines()
            if k["new"] in lines:
                i = lines.index(k["new"])
                if k["old"] == MISSING:
                    del lines[i]
                else:
                    lines[i] = k["old"]
                f.write_text("\n".join(lines) + "\n")
            else:
                notes.append(f"{f}: changed since, left as it is")
        elif k["kind"] == "yaml" and f.exists():
            data = yaml.safe_load(f.read_text()) or {}
            parent = _dig(data, k["path"])
            if parent.get(k["path"][-1]) == k["new"]:
                if k["old"] == MISSING:
                    parent.pop(k["path"][-1], None)
                    for depth in range(len(k["path"]) - 1, 0, -1):   # drop parents left empty
                        up = _dig(data, k["path"][:depth])
                        if up.get(k["path"][depth - 1]) == {}:
                            up.pop(k["path"][depth - 1])
                else:
                    parent[k["path"][-1]] = k["old"]
                orig = k.get("orig")
                if orig is None and not data:
                    f.unlink()
                elif orig is not None and data == ((yaml.safe_load(orig) if orig else None) or {}):
                    f.write_text(orig)       # byte for byte what you had
                else:
                    f.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        elif k["kind"] == "ini":
            cur = subprocess.run(["kreadconfig6", "--file", k["file"], "--group", k["group"], "--key", k["key"]],
                                 capture_output=True, text=True).stdout.strip()
            if cur == k["new"]:
                args = ["--delete"] if k["old"] == MISSING else [k["old"]]
                subprocess.run(["kwriteconfig6", "--file", k["file"], "--group", k["group"], "--key", k["key"], *args])
        elif k["kind"] == "file" and f.exists():
            if hashlib.sha256(f.read_bytes()).hexdigest() == k["hash"]:
                shutil.copyfile(k["backup"], f)
            else:
                notes.append(f"{f}: changed since, left as it is (the original is in {k['backup']})")
    for file, comment in m["lines"].items():
        f = Path(file)
        if not f.exists():
            continue
        lines, out, skip = f.read_text().splitlines(), [], False
        for ln in lines:
            if skip:
                skip = False
                continue
            if ln.strip() == f"{comment} {MARK}":
                skip = True
                continue
            out.append(ln)
        if not out and m["created"].get(file):
            f.unlink()
        else:
            f.write_text("\n".join(out) + ("\n" if out else ""))
    for dst, backup in m["owned"].items():
        d = Path(dst)
        if backup:
            shutil.copy2(backup, d)
        elif d.exists():
            d.unlink()
    if m.get("git"):
        subprocess.run(["git", "config", "--global", "--fixed-value", "--unset-all", "include.path", m["git"]])
    if shutil.which("batcat"):
        subprocess.run(["batcat", "cache", "--build"], capture_output=True)
    shutil.rmtree(STATE)
    for d in sorted(m["dirs"], key=len, reverse=True):   # folders we made, if empty
        try:
            Path(d).rmdir()
        except OSError:
            pass
    for n in notes:
        print("  " + n)
    print("Frost terminal themes removed; your previous settings are back.")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["revert"]:
        revert()
    elif args[:1] == ["install"]:
        install("--image" in args)
    else:
        sys.exit(__doc__)
