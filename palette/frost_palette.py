"""Load palette/frost.toml for the Frost generators.

    import sys; sys.path.insert(0, "<repo>/palette")
    from frost_palette import P, ANSI, rgb, mix, xterm256

P is a flat namespace: P.red, P.text, P.obsidian, P.keyword ... (section names
dropped; [ansi] lives in ANSI as a list of 16 in terminal order). A name that
appears in two sections keeps the first one ([accent] red before [ansi] red).
"""
import tomllib
from pathlib import Path
from types import SimpleNamespace

FILE = Path(__file__).resolve().parent / "frost.toml"
RAW = tomllib.loads(FILE.read_text())

ANSI_ORDER = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
ANSI = [RAW["ansi"][n] for n in ANSI_ORDER] + [RAW["ansi"]["bright_" + n] for n in ANSI_ORDER]

_flat = {}
for section in ("base", "accent", "state", "glass", "syntax"):
    for k, v in RAW[section].items():
        _flat.setdefault(k, v)
P = SimpleNamespace(**_flat)


def rgb(hex_):
    """'#F21D43' -> (242, 29, 67)"""
    h = hex_.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(r, g, b):
    return "#%02x%02x%02x" % (round(r), round(g), round(b))


def mix(a, b, t):
    """Blend colour a towards b by t (0 = a, 1 = b)."""
    ra, rb = rgb(a), rgb(b)
    return hexc(*(x + (y - x) * t for x, y in zip(ra, rb)))


def _xterm_table():
    table = []
    base = [(0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
            (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]
    table += base
    steps = [0, 95, 135, 175, 215, 255]
    table += [(r, g, b) for r in steps for g in steps for b in steps]
    table += [(8 + 10 * i,) * 3 for i in range(24)]
    return table


_XT = _xterm_table()


def xterm256(hex_):
    """Nearest xterm-256 index (16..255 only: 0..15 are the Frost ANSI colours,
    which are better named directly)."""
    c = rgb(hex_)
    return min(range(16, 256), key=lambda i: sum((a - b) ** 2 for a, b in zip(c, _XT[i])))
