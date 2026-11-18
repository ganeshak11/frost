#!/usr/bin/env python3
"""Frost icon themes: Papirus with folders in the Frost red.

Papirus draws its default (blue) folders with two blues and a dark navy glyph.
For every folder-like icon (folders, special folders, user home, the folder
mimetype) that resolves to a blue Papirus file, this writes a recoloured copy;
everything else is inherited unchanged from Papirus-Dark.

Output: build/Frost (inherits Papirus-Dark).
"""
import configparser, os, re, shutil
from pathlib import Path

HOME_ICONS = Path.home() / ".local/share/icons"
OUT = Path(__file__).resolve().parent / "build"
PALETTE = {                      # Papirus blue -> Frost red
    "#5294e2": "#f21d43",        # folder body
    "#4877b1": "#b8132f",        # folder back / shade
    "#1d344f": "#5c0a19",        # glyph on special folders
}
BLUE = re.compile(r"^(folder|user)-blue")
CONTEXTS = ("places", "mimetypes")
# Only icons that are named as folders. Generic names like "network" or "desktop"
# must stay Papirus: Plasma falls back to them for e.g. "network-wireless".
FOLDER_NAMES = re.compile(r"^(folder|user-|inode-directory|gtk-directory|stock_folder|stock_open|insync-folder|gnome-home)")
THEMES = {"Frost": ("Papirus-Dark", "breeze-dark")}


def recolour(text):
    for a, b in PALETTE.items():
        text = re.sub(a, b, text, flags=re.I)
    return text


def build(name, base, fallback):
    src = HOME_ICONS / base
    dst = OUT / name
    if dst.exists():
        shutil.rmtree(dst)
    dirs = []
    count = 0
    for size in sorted(os.listdir(src)):
        sdir = src / size
        if not sdir.is_dir():
            continue
        for ctx in CONTEXTS:
            cdir = sdir / ctx
            if not cdir.is_dir():
                continue
            made = {}                                   # real target -> written file name
            for entry in sorted(os.listdir(cdir)):
                path = cdir / entry
                real = Path(os.path.realpath(path))
                if not entry.endswith(".svg") or not BLUE.match(real.name) or not FOLDER_NAMES.match(entry):
                    continue
                if BLUE.match(entry) or re.match(r"^(folder|user)-(red|green|yellow|orange|violet|grey|black|brown|cyan|"
                                                  r"magenta|pink|teal|white|indigo|nordic|deeporange|bluegrey|paleorange|"
                                                  r"palebrown|carmine|darkcyan|yaru|adwaita|breeze)", entry):
                    continue                                # leave colour-named variants alone
                out_dir = dst / size / ctx
                out_dir.mkdir(parents=True, exist_ok=True)
                if real in made:
                    os.symlink(made[real], out_dir / entry)
                else:
                    (out_dir / entry).write_text(recolour(real.read_text()))
                    made[real] = entry
                count += 1
            if made:
                dirs.append(f"{size}/{ctx}")

    # index.theme: our directories, with their definitions copied from the base theme
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    cp.read(src / "index.theme")
    lines = ["[Icon Theme]", f"Name={name}",
             f"Comment=Papirus with folders in the Frost red (#F21D43)",
             f"Inherits={base},{fallback},hicolor",
             "Directories=" + ",".join(dirs), ""]
    for d in dirs:
        lines.append(f"[{d}]")
        if cp.has_section(d):
            lines += [f"{k}={v}" for k, v in cp.items(d)]
        lines.append("")
    (dst / "index.theme").write_text("\n".join(lines))
    print(f"{name}: {count} folder icons in {len(dirs)} directories, inherits {base}")


if __name__ == "__main__":
    for n, (b, f) in THEMES.items():
        build(n, b, f)
