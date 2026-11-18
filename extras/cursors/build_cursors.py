#!/usr/bin/env python3
"""Frost cursor theme generator.

Draws every cursor as SVG (near-black body, crisp white outline, soft shadow,
red accents for badges and the busy spinner), then writes:
  build/Frost-cursors/cursors_scalable/<name>/   SVG cursors (Plasma 6 / KWin, sharp at any size)
  build/Frost-cursors/cursors/<name>             classic Xcursor files (X11 / XWayland apps)
plus every alias name Breeze uses, so apps asking for old X11 names still get
a Frost cursor. Anything not drawn here falls back to Breeze (Inherits).

Canvas: 32x32 units for nominal size 24 (same convention as Breeze).
Needs: rsvg-convert, python3-pil, python3-numpy.
"""
import io, json, math, os, shutil, struct, subprocess
from pathlib import Path
from PIL import Image
import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / "build" / "Frost-cursors"
BREEZE = Path("/usr/share/icons/breeze_cursors/cursors_scalable")
NOMINAL = 24
XSIZES = [24, 30, 36, 48, 60, 72]          # Xcursor nominal sizes written
BODY = "#0e0e12"
LINE = "#ffffff"
RED = "#F21D43"

# ------------------------------------------------------------------ helpers
def svg(inner):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'
            + inner + "</svg>\n")

def outlined(shapes, w=2.6):
    """Shadow, white outline and dark body from one set of shape elements.
    The outline is the shapes stroked wide underneath, so unions of several
    shapes get one clean outline."""
    s = shapes
    return (f'<g transform="translate(0.6,1.1)" fill="#000" fill-opacity="0.28" stroke="#000" '
            f'stroke-opacity="0.28" stroke-width="{w + 1.2}" stroke-linejoin="round">{s}</g>'
            f'<g fill="{LINE}" stroke="{LINE}" stroke-width="{w}" stroke-linejoin="round">{s}</g>'
            f'<g fill="{BODY}">{s}</g>')

def rot(shapes, deg):
    return f'<g transform="rotate({deg} 16 16)">{shapes}</g>'

def badge(inner, cx=23, cy=23, r=6.2, color=RED):
    return (f'<circle cx="{cx}" cy="{cy + 0.8}" r="{r + 1.4}" fill="#000" fill-opacity="0.25"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r + 1.2}" fill="{LINE}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>' + inner)

ARROW = '<path d="M4 3 L4 23.2 L9.1 18.4 L12.6 26.3 L15.7 24.9 L12.3 17.3 L18.9 17.3 Z"/>'
SMALL_ARROW = '<path d="M3 2.5 L3 19 L7.2 15.1 L10.1 21.6 L12.6 20.5 L9.8 14.2 L15.2 14.2 Z"/>'

def arrow_with(badge_svg):
    return outlined(SMALL_ARROW) + badge_svg

def plus(cx, cy, s=3.6, t=1.5, color="#fff"):
    return (f'<rect x="{cx - s}" y="{cy - t / 2}" width="{2 * s}" height="{t}" rx="{t / 2}" fill="{color}"/>'
            f'<rect x="{cx - t / 2}" y="{cy - s}" width="{t}" height="{2 * s}" rx="{t / 2}" fill="{color}"/>')

def spinner(cx, cy, r, phase, track=True, width=2.6):
    """A red arc (90-degree head with a fading tail) rotated by `phase` (0..1)."""
    out = ""
    if track:
        out += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="{width}"/>'
    a0 = phase * 2 * math.pi - math.pi / 2
    steps = 6
    for i in range(steps):   # tail segments, fading
        s = a0 - (i + 1) * 0.42
        e = a0 - i * 0.42
        x1, y1 = cx + r * math.cos(s), cy + r * math.sin(s)
        x2, y2 = cx + r * math.cos(e), cy + r * math.sin(e)
        op = 1 - i / steps
        out += (f'<path d="M{x1:.2f} {y1:.2f} A{r} {r} 0 0 1 {x2:.2f} {y2:.2f}" fill="none" '
                f'stroke="{RED}" stroke-opacity="{op:.2f}" stroke-width="{width}" stroke-linecap="round"/>')
    return out

# ------------------------------------------------------------------ shapes
HAND_POINT = (
    '<rect x="10.4" y="2.6" width="4.4" height="14" rx="2.2"/>'          # index finger
    '<rect x="14.2" y="10.2" width="4" height="9" rx="2"/>'              # middle
    '<rect x="17.6" y="11.4" width="3.8" height="8.4" rx="1.9"/>'        # ring
    '<rect x="20.7" y="13" width="3.5" height="7.6" rx="1.75"/>'         # little
    '<path d="M10.4 14 L24.2 16 L24.2 22.5 Q24.2 28.5 18 28.5 L14.4 28.5 Q11.4 28.5 9.6 26 '
    'L5.6 20.6 Q4.6 19 6.1 18.1 Q7.4 17.4 8.6 18.6 L10.4 20.5 Z"/>'    # palm + thumb
)
HAND_OPEN = (
    '<rect x="8.6" y="5.2" width="3.6" height="13" rx="1.8"/>'
    '<rect x="12.2" y="3.2" width="3.8" height="14" rx="1.9"/>'
    '<rect x="16" y="4" width="3.7" height="13.5" rx="1.85"/>'
    '<rect x="19.6" y="6.4" width="3.4" height="12" rx="1.7"/>'
    '<path d="M8.6 14 L23 14 L23 22 Q23 28.6 17 28.6 L14 28.6 Q10.8 28.6 9 26 L4.6 19.6 '
    'Q3.6 17.9 5.2 17 Q6.6 16.3 7.8 17.6 L8.6 18.6 Z"/>'
)
HAND_CLOSED = (
    '<rect x="9" y="10" width="3.6" height="7" rx="1.8"/>'
    '<rect x="12.4" y="9" width="3.8" height="7.5" rx="1.9"/>'
    '<rect x="16" y="9.4" width="3.7" height="7.4" rx="1.85"/>'
    '<rect x="19.4" y="10.6" width="3.4" height="6.6" rx="1.7"/>'
    '<path d="M9 13.5 L22.8 13.5 L22.8 21.5 Q22.8 27.4 17 27.4 L14 27.4 Q10.6 27.4 9 24.6 '
    'L6.4 20 Q5.6 18.4 7.1 17.6 Q8.4 17 9 18 Z"/>'
)
IBEAM = ('<rect x="14.9" y="6" width="2.2" height="20" rx="1"/>'
         '<rect x="11" y="4" width="10" height="2.4" rx="1.2"/>'
         '<rect x="11" y="25.6" width="10" height="2.4" rx="1.2"/>')
DOUBLE_H = '<path d="M2.5 16 L9 9.6 L9 13.8 L23 13.8 L23 9.6 L29.5 16 L23 22.4 L23 18.2 L9 18.2 L9 22.4 Z"/>'
HEAD = '<path d="M16 2.4 L21.2 8.4 L10.8 8.4 Z"/>'          # one arrowhead, pointing up
MOVE = ('<rect x="14.5" y="7" width="3" height="18" rx="1.2"/><rect x="7" y="14.5" width="18" height="3" rx="1.2"/>'
        + HEAD + rot(HEAD, 90) + rot(HEAD, 180) + rot(HEAD, 270))
CROSS = ('<rect x="3" y="15" width="11" height="2" rx="1"/><rect x="18" y="15" width="11" height="2" rx="1"/>'
         '<rect x="15" y="3" width="2" height="11" rx="1"/><rect x="15" y="18" width="2" height="11" rx="1"/>')
CELL = ('<rect x="13.6" y="4" width="4.8" height="24" rx="1.4"/><rect x="4" y="13.6" width="24" height="4.8" rx="1.4"/>')
LENS = '<circle cx="13" cy="13" r="8.6"/><path d="M18.8 20.6 L21 18.4 L28.6 26 Q29.2 27.6 27.8 28.6 Q26.4 29.2 25.8 28.6 Z"/>'

def not_allowed(cx=16, cy=16, r=9.5, w=3.2):
    d = r / math.sqrt(2)
    ring = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{{c}}" stroke-width="{{w}}"/>'
    bar = f'<path d="M{cx - d:.2f} {cy + d:.2f} L{cx + d:.2f} {cy - d:.2f}" stroke="{{c}}" stroke-width="{{w}}" stroke-linecap="round"/>'
    both = ring + bar
    return (both.replace("{c}", "#000").replace("{w}", str(w + 2.4)).replace('stroke="#000"', 'stroke="#000" stroke-opacity="0.3"')
            + both.replace("{c}", LINE).replace("{w}", str(w + 2))
            + both.replace("{c}", RED).replace("{w}", str(w)))

# ------------------------------------------------------------------ cursors
# name: (frames as list of svg strings, hotspot (x, y) in canvas units, frame delay ms)
def single(s, hx, hy): return ([svg(s)], (hx, hy), 0)

CURSORS = {
    "default":      single(outlined(ARROW), 4, 3),
    "pointer":      single(outlined(HAND_POINT), 12.6, 3),
    "text":         single(outlined(IBEAM, 2.2), 16, 16),
    "vertical-text": single(rot(outlined(IBEAM, 2.2), 90), 16, 16),
    "crosshair":    single(outlined(CROSS, 2.2) + f'<circle cx="16" cy="16" r="1.7" fill="{RED}"/>', 16, 16),
    "cell":         single(outlined(CELL), 16, 16),
    "all-scroll":   single(outlined(MOVE), 16, 16),
    "openhand":     single(outlined(HAND_OPEN), 15, 15),
    "closedhand":   single(outlined(HAND_CLOSED), 15, 16),
    "size_hor":     single(outlined(DOUBLE_H), 16, 16),
    "size_ver":     single(rot(outlined(DOUBLE_H), 90), 16, 16),
    "size_fdiag":   single(rot(outlined(DOUBLE_H), 45), 16, 16),
    "size_bdiag":   single(rot(outlined(DOUBLE_H), -45), 16, 16),
    "not-allowed":  single(not_allowed(), 16, 16),
    "help":         single(arrow_with(badge('<text x="23" y="26.4" font-family="sans-serif" font-weight="bold" '
                                              'font-size="9.5" text-anchor="middle" fill="#fff">?</text>')), 3, 2.5),
    "copy":         single(arrow_with(badge(plus(23, 23))), 3, 2.5),
    "alias":        single(arrow_with(badge('<path d="M20.4 25.6 Q20.4 20.6 25 20.6 M22.8 18.6 L25.2 20.6 L22.8 22.8" '
                                              'fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>')), 3, 2.5),
    "no-drop":      single(outlined(SMALL_ARROW) + not_allowed(23, 23, 5.2, 2), 3, 2.5),
    "context-menu": single(outlined(SMALL_ARROW)
                           + '<rect x="16.6" y="16.6" width="12.6" height="11" rx="2.4" fill="#fff"/>'
                           + f'<rect x="17.6" y="17.6" width="10.6" height="9" rx="1.8" fill="{BODY}"/>'
                           + ''.join(f'<rect x="19.4" y="{19.6 + i * 2.4}" width="7" height="1.1" rx="0.55" fill="{RED if i == 0 else "#fff"}"/>' for i in range(3)), 3, 2.5),
    "zoom-in":      single(outlined(LENS) + plus(13, 13, 4, 1.8, RED), 13, 13),
    "zoom-out":     single(outlined(LENS) + f'<rect x="9" y="12.1" width="8" height="1.8" rx="0.9" fill="{RED}"/>', 13, 13),
    "wait":         ([svg(f'<circle cx="16.6" cy="17.1" r="11.6" fill="#000" fill-opacity="0.28"/>'
                          f'<circle cx="16" cy="16" r="11.6" fill="{LINE}"/><circle cx="16" cy="16" r="10.4" fill="{BODY}"/>'
                          + spinner(16, 16, 6.6, i / 24)) for i in range(24)], (16, 16), 35),
    "progress":     ([svg(outlined(SMALL_ARROW)
                          + f'<circle cx="23" cy="23" r="7.6" fill="{LINE}"/><circle cx="23" cy="23" r="6.6" fill="{BODY}"/>'
                          + spinner(23, 23, 4, i / 24, width=2)) for i in range(24)], (3, 2.5), 35),
}

# Breeze's real cursor names -> ours (the rest of Breeze's names are aliases of these)
MAP = {
    "default": "default", "pointer": "pointer", "text": "text", "vertical-text": "vertical-text",
    "crosshair": "crosshair", "cell": "cell", "all-scroll": "all-scroll", "fleur": "all-scroll",
    "dnd-move": "all-scroll", "openhand": "openhand", "closedhand": "closedhand",
    "size_hor": "size_hor", "col-resize": "size_hor", "left_side": "size_hor", "right_side": "size_hor",
    "size_ver": "size_ver", "row-resize": "size_ver", "top_side": "size_ver", "bottom_side": "size_ver",
    "size_fdiag": "size_fdiag", "top_left_corner": "size_fdiag", "bottom_right_corner": "size_fdiag",
    "size_bdiag": "size_bdiag", "top_right_corner": "size_bdiag", "bottom_left_corner": "size_bdiag",
    "not-allowed": "not-allowed", "circle": "not-allowed",
    "help": "help", "copy": "copy", "alias": "alias", "no-drop": "no-drop", "dnd-no-drop": "no-drop",
    "context-menu": "context-menu", "zoom-in": "zoom-in", "zoom-out": "zoom-out",
    "wait": "wait", "progress": "progress",
}
# a few common CSS / X11 names Breeze may not list
EXTRA = {"left_ptr": "default", "arrow": "default", "hand2": "pointer", "hand1": "pointer",
         "pointing_hand": "pointer", "xterm": "text", "ibeam": "text", "watch": "wait",
         "left_ptr_watch": "progress", "grab": "openhand", "grabbing": "closedhand",
         "move": "all-scroll", "ew-resize": "size_hor", "ns-resize": "size_ver",
         "nwse-resize": "size_fdiag", "nesw-resize": "size_bdiag", "e-resize": "size_hor",
         "w-resize": "size_hor", "n-resize": "size_ver", "s-resize": "size_ver",
         "nw-resize": "size_fdiag", "se-resize": "size_fdiag", "ne-resize": "size_bdiag",
         "sw-resize": "size_bdiag", "forbidden": "not-allowed", "question_arrow": "help",
         "dnd-copy": "copy", "dnd-link": "alias", "link": "alias", "cross": "crosshair",
         "tcross": "crosshair", "plus": "cell"}

# ------------------------------------------------------------------ writers
def render(svg_text, px):
    png = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px)], input=svg_text.encode(),
                         capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")

def xcursor(frames, hot, delay):
    chunks = []
    for nom in XSIZES:
        px = round(nom * 32 / NOMINAL)
        hx, hy = round(hot[0] * px / 32), round(hot[1] * px / 32)
        for f in frames:
            im = render(f, px)
            p = np.asarray(im, dtype=np.uint32)            # premultiplied ARGB, little endian
            a = p[..., 3]
            argb = (a << 24) | ((p[..., 0] * a // 255) << 16) | ((p[..., 1] * a // 255) << 8) | (p[..., 2] * a // 255)
            data = argb.astype("<u4").tobytes()
            hdr = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nom, 1, px, px, hx, hy, delay or 0)
            chunks.append((nom, hdr + bytes(data)))
    ntoc = len(chunks)
    out = bytearray(struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc))
    pos = 16 + ntoc * 12
    for nom, c in chunks:
        out += struct.pack("<III", 0xFFFD0002, nom, pos); pos += len(c)
    for _, c in chunks:
        out += c
    return bytes(out)

def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    sc, xc = OUT / "cursors_scalable", OUT / "cursors"
    sc.mkdir(parents=True); xc.mkdir()
    for name, (frames, hot, delay) in CURSORS.items():
        d = sc / name; d.mkdir()
        meta = []
        for i, f in enumerate(frames):
            fn = f"{name}.svg" if len(frames) == 1 else f"{name}-{i + 1:02d}.svg"
            (d / fn).write_text(f)
            m = {"filename": fn, "hotspot_x": hot[0], "hotspot_y": hot[1], "nominal_size": NOMINAL}
            if delay: m["delay"] = delay
            meta.append(m)
        (d / "metadata.json").write_text(json.dumps(meta, indent=2))
        (xc / name).write_bytes(xcursor(frames, hot, delay))

    # aliases: every Breeze name whose real cursor we draw, plus a few extras
    aliases = dict(EXTRA)
    if BREEZE.exists():
        for p in BREEZE.iterdir():
            real = os.path.basename(os.path.realpath(p))
            if real in MAP: aliases[p.name] = MAP[real]
    for k, v in MAP.items():
        aliases.setdefault(k, v)
    n = 0
    for alias, target in aliases.items():
        if alias in CURSORS or target not in CURSORS:
            continue
        for base in (sc, xc):
            link = base / alias
            if not link.exists():
                link.symlink_to(target); n += 1
    (OUT / "index.theme").write_text("[Icon Theme]\nName=Frost\nComment=Obsidian Glass cursors: dark, "
                                     "white outline, red accents\nInherits=breeze_cursors\n")
    (OUT / "cursor.theme").write_text("[Icon Theme]\nInherits=Frost-cursors\n")
    print(f"{len(CURSORS)} cursors, {n // 2} alias names -> {OUT}")

if __name__ == "__main__":
    main()
