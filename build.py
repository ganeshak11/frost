#!/usr/bin/env python3
"""Frost: a light, glass-style theme for KDE Plasma 6.

Generates every theme file into ./build. Nothing here touches your system;
install.sh copies the build into ~/.local/share and ~/.config.
"""
import json, re, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "build"
VERSION = "1.0"

# ---------------------------------------------------------------- palettes
PAL = {
    "Dark": dict(
        window=(30, 31, 36), view=(37, 38, 44), alt=(43, 44, 51), button=(55, 56, 64),
        header=(30, 31, 36), tooltip=(40, 41, 48), comp=(22, 23, 27),
        text=(236, 236, 241), dim=(150, 152, 162), accent=(242, 29, 67),
        link=(90, 160, 255), visited=(176, 128, 230),
        neg=(255, 92, 92), neu=(255, 176, 46), pos=(52, 199, 89),
        icons="Papirus-Dark", kv="KvMojave",
    ),
    "Light": dict(
        window=(236, 236, 241), view=(255, 255, 255), alt=(245, 245, 248), button=(255, 255, 255),
        header=(230, 230, 236), tooltip=(250, 250, 252), comp=(30, 31, 36),
        text=(29, 29, 31), dim=(112, 112, 122), accent=(10, 112, 240),
        link=(10, 102, 220), visited=(130, 70, 200),
        neg=(220, 50, 50), neu=(210, 130, 0), pos=(30, 150, 60),
        icons="Papirus-Light", kv="KvMojaveLight",
    ),
}

c = lambda t: ",".join(map(str, t))
hx = lambda t, a=None: "#%02x%02x%02x" % t + ("" if a is None else "%02x" % a)


def mix(a, b, f):
    return tuple(round(x + (y - x) * f) for x, y in zip(a, b))


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


# ---------------------------------------------------------- colour schemes
def color_scheme(name, p):
    white = (255, 255, 255)
    def block(bg, alt, fg=None, dim=None):
        fg = fg or p["text"]; dim = dim or p["dim"]
        return (f"BackgroundAlternate={c(alt)}\nBackgroundNormal={c(bg)}\n"
                f"DecorationFocus={c(p['accent'])}\nDecorationHover={c(p['accent'])}\n"
                f"ForegroundActive={c(p['accent'])}\nForegroundInactive={c(dim)}\n"
                f"ForegroundLink={c(p['link'])}\nForegroundNegative={c(p['neg'])}\n"
                f"ForegroundNeutral={c(p['neu'])}\nForegroundNormal={c(fg)}\n"
                f"ForegroundPositive={c(p['pos'])}\nForegroundVisited={c(p['visited'])}\n")
    comp_fg = (236, 236, 241)
    sel = p["accent"]
    return f"""[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=false
Color=112,111,110
ColorAmount=0
ColorEffect=0
ContrastAmount=0
ContrastEffect=0
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
{block(p['button'], mix(p['button'], sel, .25))}
[Colors:Complementary]
{block(p['comp'], mix(p['comp'], sel, .25), comp_fg, (150, 152, 162))}
[Colors:Header]
{block(p['header'], p['window'])}
[Colors:Header][Inactive]
{block(p['window'], p['header'])}
[Colors:Selection]
{block(sel, mix(sel, p['window'], .4), white, mix(white, sel, .3))}
[Colors:Tooltip]
{block(p['tooltip'], p['window'])}
[Colors:View]
{block(p['view'], p['alt'])}
[Colors:Window]
{block(p['window'], p['alt'])}
[General]
ColorScheme=Frost{name}
Name=Frost {name}
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={c(p['window'])}
activeBlend={c(p['text'])}
activeForeground={c(p['text'])}
inactiveBackground={c(p['window'])}
inactiveBlend={c(p['dim'])}
inactiveForeground={c(p['dim'])}
"""


# ------------------------------------------------- Plasma desktop theme (glass)
STYLE = """<defs><style id="current-color-scheme" type="text/css">
.ColorScheme-Background{color:#1e1f24;}
.ColorScheme-Text{color:#ececf1;}
</style></defs>"""


def frame_svg(r, opacity, edge, margin, w=10):
    """9-slice rounded frame that follows the colour scheme, plus blur masks.

    r: corner radius, opacity: fill alpha, edge: alpha of the 1px light rim,
    margin: content margin hint.
    """
    S = 2 * r + w
    out = []
    bb = lambda x, y, ww, hh: f'<rect x="{x}" y="{y}" width="{ww}" height="{hh}" fill="#000" fill-opacity="0.002"/>'
    fill = f'class="ColorScheme-Background" fill="currentColor" fill-opacity="{opacity}"'
    rim = f'class="ColorScheme-Text" fill="currentColor" fill-opacity="{edge}"'
    a = r - 1
    corners = {
        "topleft": (0, 0, f"M0,{r} A{r},{r} 0 0 1 {r},0 L{r},{r} Z",
                    f"M0,{r} A{r},{r} 0 0 1 {r},0 V1 A{a},{a} 0 0 0 1,{r} Z"),
        "topright": (r + w, 0, f"M{r+w},0 A{r},{r} 0 0 1 {S},{r} L{r+w},{r} Z",
                     f"M{r+w},0 A{r},{r} 0 0 1 {S},{r} H{S-1} A{a},{a} 0 0 0 {r+w},1 Z"),
        "bottomleft": (0, r + w, f"M0,{r+w} L{r},{r+w} L{r},{S} A{r},{r} 0 0 1 0,{r+w} Z",
                       f"M{r},{S} A{r},{r} 0 0 1 0,{r+w} H1 A{a},{a} 0 0 0 {r},{S-1} Z"),
        "bottomright": (r + w, r + w, f"M{r+w},{r+w} L{S},{r+w} A{r},{r} 0 0 1 {r+w},{S} Z",
                        f"M{S},{r+w} A{r},{r} 0 0 1 {r+w},{S} V{S-1} A{a},{a} 0 0 0 {S-1},{r+w} Z"),
    }
    edges = {
        "top": (r, 0, w, r, f"M{r},0 H{r+w} V1 H{r} Z"),
        "bottom": (r, r + w, w, r, f"M{r},{S-1} H{r+w} V{S} H{r} Z"),
        "left": (0, r, r, w, f"M0,{r} H1 V{r+w} H0 Z"),
        "right": (r + w, r, r, w, f"M{S-1},{r} H{S} V{r+w} H{S-1} Z"),
    }
    for pre, solid in (("", False), ("mask-", True)):
        f = 'fill="#000"' if solid else fill
        for n, (x, y, d, rd) in corners.items():
            out.append(f'<g id="{pre}{n}"><path d="{d}" {f}/>' + ("" if solid else f'<path d="{rd}" {rim}/>') + "</g>")
        for n, (x, y, ww, hh, rd) in edges.items():
            out.append(f'<g id="{pre}{n}"><rect x="{x}" y="{y}" width="{ww}" height="{hh}" {f}/>' + ("" if solid else f'<path d="{rd}" {rim}/>') + "</g>")
        out.append(f'<rect id="{pre}center" x="{r}" y="{r}" width="{w}" height="{w}" {f}/>')
    for side, (x, y, ww, hh) in {"top": (S + 4, 0, 1, margin), "bottom": (S + 6, 0, 1, margin),
                                 "left": (S + 8, 0, margin, 1), "right": (S + 8, 4, margin, 1)}.items():
        out.append(f'<rect id="hint-{side}-margin" x="{x}" y="{y}" width="{ww}" height="{hh}" fill="none"/>')
    out.append(f'<rect id="hint-stretch-borders" x="{S+2}" y="0" width="1" height="1" fill="none"/>')
    # our own (empty) shadow, otherwise Plasma borrows Breeze's shadow tiles,
    # which show up as dark squares at the corners of desktop widgets
    for n in ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"):
        out.append(f'<rect id="shadow-{n}" x="{S+20}" y="0" width="{r}" height="{r}" fill="#000" fill-opacity="0.002"/>')
    W = S + 8 + margin
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{S}" viewBox="0 0 {W} {S}">'
            + STYLE + "".join(out) + "</svg>\n")


def panel_svg():
    """Panel background for the Frost bars.

    - default / top panels: fully transparent, no margins, no blur mask. The
      Dynamic Island draws its own pill.
    - bottom panels (south-*): a clear band, then the dock's glass bar, with a
      matching blur mask (mask-south-*) so only the bar is blurred.
    - thick-* hints: the gap between the bar's edge and the icons in it.
      The dock's 24 px top band keeps its icons in the bar; the magnified ones
      grow up into the band. Small panels (the island's) cap these paddings.
    """
    out = []
    t = 'fill="#000" fill-opacity="0"'

    def nine(pre, ox, r, w, fill, rim=None, band=0):
        """9-slice rounded frame at x offset ox; `band` px of clear space above it
        (part of the top row's elements, so the frame itself starts lower)."""
        S, a = 2 * r + w, r - 1
        X = lambda v: v + ox
        Y = lambda v: v + band
        corners = {   # name: (box, fill path, rim path)
            "topleft": ((0, 0, r, r + band),
                        f"M{X(0)},{Y(r)} A{r},{r} 0 0 1 {X(r)},{Y(0)} L{X(r)},{Y(r)} Z",
                        f"M{X(0)},{Y(r)} A{r},{r} 0 0 1 {X(r)},{Y(0)} V{Y(1)} A{a},{a} 0 0 0 {X(1)},{Y(r)} Z"),
            "topright": ((r + w, 0, r, r + band),
                         f"M{X(r+w)},{Y(0)} A{r},{r} 0 0 1 {X(S)},{Y(r)} L{X(r+w)},{Y(r)} Z",
                         f"M{X(r+w)},{Y(0)} A{r},{r} 0 0 1 {X(S)},{Y(r)} H{X(S-1)} A{a},{a} 0 0 0 {X(r+w)},{Y(1)} Z"),
            "bottomleft": ((0, Y(r + w), r, r),
                           f"M{X(0)},{Y(r+w)} L{X(r)},{Y(r+w)} L{X(r)},{Y(S)} A{r},{r} 0 0 1 {X(0)},{Y(r+w)} Z",
                           f"M{X(r)},{Y(S)} A{r},{r} 0 0 1 {X(0)},{Y(r+w)} H{X(1)} A{a},{a} 0 0 0 {X(r)},{Y(S-1)} Z"),
            "bottomright": ((r + w, Y(r + w), r, r),
                            f"M{X(r+w)},{Y(r+w)} L{X(S)},{Y(r+w)} A{r},{r} 0 0 1 {X(r+w)},{Y(S)} Z",
                            f"M{X(S)},{Y(r+w)} A{r},{r} 0 0 1 {X(r+w)},{Y(S)} V{Y(S-1)} A{a},{a} 0 0 0 {X(S-1)},{Y(r+w)} Z"),
        }
        edges = {     # name: (box, fill rect, rim path)
            "top": ((r, 0, w, r + band), (r, Y(0), w, r), f"M{X(r)},{Y(0)} H{X(r+w)} V{Y(1)} H{X(r)} Z"),
            "bottom": ((r, Y(r + w), w, r), (r, Y(r + w), w, r), f"M{X(r)},{Y(S-1)} H{X(r+w)} V{Y(S)} H{X(r)} Z"),
            "left": ((0, Y(r), r, w), (0, Y(r), r, w), f"M{X(0)},{Y(r)} H{X(1)} V{Y(r+w)} H{X(0)} Z"),
            "right": ((r + w, Y(r), r, w), (r + w, Y(r), r, w), f"M{X(S-1)},{Y(r)} H{X(S)} V{Y(r+w)} H{X(S-1)} Z"),
        }
        box = lambda x, y, ww, hh: f'<rect x="{X(x)}" y="{y}" width="{ww}" height="{hh}" {t}/>'
        rimp = lambda d: f'<path d="{d}" {rim}/>' if rim else ""
        for n, (bx, d, rd) in corners.items():
            out.append(f'<g id="{pre}{n}">{box(*bx)}' + (f'<path d="{d}" {fill}/>' if fill else "") + rimp(rd) + "</g>")
        for n, (bx, (x, y, ww, hh), rd) in edges.items():
            out.append(f'<g id="{pre}{n}">{box(*bx)}' + (f'<rect x="{X(x)}" y="{y}" width="{ww}" height="{hh}" {fill}/>' if fill else "") + rimp(rd) + "</g>")
        out.append(f'<g id="{pre}center">{box(r, Y(r), w, w)}' + (f'<rect x="{X(r)}" y="{Y(r)}" width="{w}" height="{w}" {fill}/>' if fill else "") + "</g>")
        return S

    def hints(pre, ox, top, bottom, left, right):
        for i, (side, m) in enumerate((("top", top), ("bottom", bottom), ("left", left), ("right", right))):
            ww, hh = (0.01, m) if side in ("top", "bottom") else (m, 0.01)
            out.append(f'<rect id="{pre}hint-{side}-margin" x="{ox + i * 2}" y="60" width="{ww or 0.01}" height="{hh or 0.01}" fill="none"/>')

    # the dock's glass follows the colour scheme: dark glass under Frost Dark, light under Frost Light
    glass = 'class="ColorScheme-Background" fill="currentColor" fill-opacity="0.55"'
    rim = 'class="ColorScheme-Text" fill="currentColor" opacity="0.13"'      # element opacity: stays faint when opaque
    nine("", 0, 4, 2, None)                                   # transparent
    hints("", 0, 0, 0, 0, 0)
    # Its blur mask is a single pixel per corner: with no mask at all Plasma
    # blurs the whole panel, which shows as a grey box around the island.
    # (a pixel in every corner piece: a panel at a screen edge doesn't draw the
    # pieces along that edge)
    nine("mask-", 230, 4, 2, None)
    for i, (px, py) in enumerate(((230, 0), (239, 0), (230, 9), (239, 9))):   # topleft, topright, bottomleft, bottomright
        out[-9 + i] = out[-9 + i].replace("</g>", f'<rect x="{px}" y="{py}" width="1" height="1" fill="#000"/></g>')
    # the dock: a 24 px clear band on top (room for the magnified icons), then the glass bar
    nine("south-", 20, 20, 10, glass, rim, band=24)
    nine("mask-south-", 80, 20, 10, 'fill="#000"', band=24)
    nine("thick-", 140, 4, 2, None)
    hints("thick-", 140, 30, 6, 8, 8)                         # icons 10 px inside the bar, below the band
    for pre in ("", "south-"):
        out.append(f'<rect id="{pre}hint-stretch-borders" x="200" y="60" width="1" height="1" fill="none"/>')
    for n in ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"):
        out.append(f'<rect id="shadow-{n}" x="210" y="0" width="4" height="4" {t}/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="250" height="100" viewBox="0 0 250 100">'
            + STYLE + "".join(out) + "</svg>\n")


def plasma_theme(base: Path):
    files = {
        "widgets/panel-background.svg": panel_svg(),
        "dialogs/background.svg": frame_svg(14, 0.26, 0.20, 10),
        "widgets/background.svg": frame_svg(18, 0.48, 0.12, 12),
        "widgets/tooltip.svg": frame_svg(10, 0.45, 0.20, 8),
    }
    for variant in ("", "translucent/"):
        for rel, svg in files.items():
            write(base / variant / rel, svg)
    # "opaque" mode (a panel set to Opaque, or no compositing): same shapes, solid fill
    for folder in ("opaque", "solid"):
        for rel, svg in files.items():
            write(base / folder / rel, re.sub(r'fill-opacity="0\.\d+"', 'fill-opacity="1"', svg))
    write(base / "metadata.json", json.dumps({
        "KPlugin": {"Id": "Frost", "Name": "Frost", "Description": "Frosted glass panels and popups",
                    "Authors": [{"Name": "ganeshak11"}], "License": "GPL-2.0+", "Version": VERSION,
                    "Category": "Plasma Theme"},
        "X-Plasma-API-Minimum-Version": "6.0"}, indent=2))
    write(base / "plasmarc", "[ContrastEffect]\nenabled=true\ncontrast=0.9\nintensity=1.0\nsaturation=1.7\n\n"
                             "[AdaptiveTransparency]\nenabled=true\n")


# --------------------------------------------------- window decoration (Aurorae)
P, R, TH = 16, 10, 32   # shadow padding, corner radius, title bar height
SH = 0.30                # shadow strength at the window edge


def decoration_svg():
    """Each tile is drawn at its own origin and then moved with translate(),
    so gradients defined in tile-local coordinates line up exactly."""
    defs = [STYLE.replace("<defs>", "").replace("</defs>", "")]
    def lin(i, x1, y1, x2, y2):
        defs.append(f'<linearGradient id="{i}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
                    f'<stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="{SH}"/></linearGradient>')
    def rad(i, cx, cy, rr, inner):
        defs.append(f'<radialGradient id="{i}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{rr}" fx="{cx}" fy="{cy}">'
                    f'<stop offset="{inner:.3f}" stop-color="#000" stop-opacity="{SH}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>')
    W, TL = 10, P + R
    bg = 'class="ColorScheme-Background" fill="currentColor"'
    rim = 'class="ColorScheme-Text" stroke="currentColor" stroke-opacity="0.07" stroke-width="1" fill="none"'
    rad("gtl", TL, TL, TL, R / TL); rad("gtr", 0, TL, TL, R / TL)
    rad("gbl", P, 0, P, 0); rad("gbr", 0, 0, P, 0)
    lin("gt", 0, 0, 0, P); lin("gb", 0, P, 0, 0)
    lin("gl", 0, 0, P, 0); lin("gr", P, 0, 0, 0)
    tiles = {
        "topleft": (TL, P + TH,
                    f'<rect width="{TL}" height="{TL}" fill="url(#gtl)"/>'
                    f'<rect y="{TL}" width="{P}" height="{TH-R}" fill="url(#gl)"/>'
                    f'<path d="M{P},{P+TH} V{TL} A{R},{R} 0 0 1 {TL},{P} V{P+TH} Z" {bg}/>'
                    f'<path d="M{P+.5},{P+TH} V{TL} A{R-.5},{R-.5} 0 0 1 {TL},{P+.5}" {rim}/>'),
        "top": (W, P + TH,
                f'<rect width="{W}" height="{P}" fill="url(#gt)"/><rect y="{P}" width="{W}" height="{TH}" {bg}/>'
                f'<path d="M0,{P+.5} H{W}" {rim}/>'),
        "topright": (TL, P + TH,
                     f'<rect width="{TL}" height="{TL}" fill="url(#gtr)"/>'
                     f'<rect x="{R}" y="{TL}" width="{P}" height="{TH-R}" fill="url(#gr)"/>'
                     f'<path d="M0,{P} A{R},{R} 0 0 1 {R},{TL} V{P+TH} H0 Z" {bg}/>'
                     f'<path d="M0,{P+.5} A{R-.5},{R-.5} 0 0 1 {R-.5},{TL} V{P+TH}" {rim}/>'),
        "left": (P, W, f'<rect width="{P}" height="{W}" fill="url(#gl)"/>'),
        "right": (P, W, f'<rect width="{P}" height="{W}" fill="url(#gr)"/>'),
        "center": (W, W, f'<rect width="{W}" height="{W}" {bg}/>'),
        "bottomleft": (P, P, f'<rect width="{P}" height="{P}" fill="url(#gbl)"/>'),
        "bottom": (W, P, f'<rect width="{W}" height="{P}" fill="url(#gb)"/>'),
        "bottomright": (P, P, f'<rect width="{P}" height="{P}" fill="url(#gbr)"/>'),
    }
    # QtSvg resolves userSpaceOnUse gradients in the coordinate system of the
    # element that uses them, so translate() on the group keeps them aligned.
    body, x, y = [], 0, 0
    for st in ("", "inactive-"):
        x = 0
        for n, (tw, th, inner) in tiles.items():
            body.append(f'<g id="decoration-{st}{n}" transform="translate({x},{y})">{inner}</g>')
            x += tw + 10
        y += 80
    # stretch the edge tiles instead of repeating them (repeating leaves seams
    # that show up as faint stripes in the shadow)
    body.append('<rect id="hint-stretch-borders" x="0" y="0" width="1" height="1" fill="none"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="{y}">'
            f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>\n')


BTN = ("close", "minimize", "maximize", "restore")
BW, BH = 28, 22          # button size: a bare glyph, with a soft rounded square on hover
CLOSE_RED = (242, 29, 67)


def button_svg(kind, p):
    """Window buttons, style "Glyphs": thin icons in soft text colour; hovering
    shows a faint rounded square behind them, and close turns solid red."""
    cx, cy, k = BW / 2, BH / 2, 4
    glyph = {
        "close": f'<path d="M{cx-k+.5},{cy-k+.5} L{cx+k-.5},{cy+k-.5} M{cx+k-.5},{cy-k+.5} L{cx-k+.5},{cy+k-.5}" {{s}}/>',
        "minimize": f'<path d="M{cx-k},{cy} H{cx+k}" {{s}}/>',
        "maximize": f'<rect x="{cx-k+.5}" y="{cy-k+.5}" width="{2*k-1}" height="{2*k-1}" rx="2" {{s}}/>',
        "restore": (f'<path d="M{cx-k+2.5},{cy-k+.5} H{cx+k-1} A1.5,1.5 0 0 1 {cx+k-.5},{cy-k+2} V{cy+k-3}" {{s}}/>'
                    f'<rect x="{cx-k+.5}" y="{cy-k+2.5}" width="{2*k-3}" height="{2*k-3}" rx="1.5" {{s}}/>'),
    }[kind]
    text, dim, light = p["text"], p["dim"], p["window"][0] > 128
    soft = mix(text, p["window"], .22)                       # glyph at rest
    def state(fg, square=None, sq_op=0.0, op=1.0):
        sq = f'<rect x="0.5" y="0.5" width="{BW-1}" height="{BH-1}" rx="7" fill="{hx(square)}" fill-opacity="{sq_op}"/>' if square else ""
        stroke = f'stroke="{hx(fg)}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" fill="none"'
        return f'<g opacity="{op}">{sq}{glyph.replace("{s}", stroke)}</g>'
    close = kind == "close"
    hover = state((255, 255, 255), CLOSE_RED, 1) if close else state(text, text, .10 if light else .12)
    pressed = state((255, 255, 255), mix(CLOSE_RED, (0, 0, 0), .2), 1) if close else state(text, text, .18 if light else .22)
    states = {
        "active": state(soft), "hover": hover, "pressed": pressed, "deactivated": state(soft, op=.3),
        "inactive": state(dim, op=.8), "hover-inactive": hover, "pressed-inactive": pressed,
        "deactivated-inactive": state(dim, op=.25),
    }
    parts, x = [], 0
    for st, inner in states.items():
        parts.append(f'<g id="{st}-center" transform="translate({x},0)">'
                     f'<rect width="{BW}" height="{BH}" fill="#000" fill-opacity="0"/>{inner}</g>')
        x += BW + 4
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="{BH}">{"".join(parts)}</svg>\n'


def aurorae(name, p, base: Path):
    write(base / "decoration.svg", decoration_svg())
    for k in BTN:
        write(base / f"{k}.svg", button_svg(k, p))
    write(base / f"Frost{name}rc", f"""[General]
ActiveTextColor={c(p['text'])}
InactiveTextColor={c(p['dim'])}
Animation=120
TitleAlignment=Center
TitleVerticalAlignment=Center
UseTextShadow=false
Shadow=true
LeftButtons=
RightButtons=IAX

[Layout]
BorderLeft=0
BorderRight=0
BorderBottom=0
TitleEdgeTop=0
TitleEdgeBottom=0
TitleEdgeLeft=12
TitleEdgeRight=12
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=10
TitleEdgeRightMaximized=10
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TH}
ButtonWidth={BW}
ButtonHeight={BH}
ButtonSpacing=2
ButtonMarginTop={(TH-BH)//2}
ExplicitButtonSpacer=10
PaddingTop={P}
PaddingBottom={P}
PaddingLeft={P}
PaddingRight={P}
""")
    meta = {"KPlugin": {"Id": f"Frost{name}", "Name": f"Frost {name}", "Authors": [{"Name": "ganeshak11"}],
                        "License": "GPL-2.0+", "Version": VERSION, "EnabledByDefault": True, "Category": ""}}
    write(base / "metadata.json", json.dumps(meta, indent=2))
    write(base / "metadata.desktop", f"[Desktop Entry]\nName=Frost {name}\nX-KDE-PluginInfo-Name=Frost{name}\n"
          f"X-KDE-PluginInfo-Author=ganeshak11\nX-KDE-PluginInfo-License=GPL-2.0+\nX-KDE-PluginInfo-Version={VERSION}\n"
          "X-KDE-PluginInfo-EnabledByDefault=true\n")


# ------------------------------------------------------------------ Kvantum
def kvantum(name, p, base: Path):
    src = Path("/usr/share/Kvantum") / p["kv"]
    cfg = (src / f"{p['kv']}.kvconfig").read_text()
    sets = {
        "translucent_windows": "true", "blurring": "true", "popup_blurring": "true",
        "reduce_window_opacity": "30" if name == "Dark" else "25",
        "reduce_menu_opacity": "30", "menu_blur_radius": "6", "tooltip_blur_radius": "6",
        "menu_shadow_depth": "6", "tooltip_shadow_depth": "4", "animate_states": "false",
        "opaque": "kaffeine,kmplayer,subtitlecomposer,kdenlive,vlc,smplayer,smplayer2,avidemux,avidemux2_qt4,"
                  "avidemux3_qt4,avidemux3_qt5,kamoso,QtCreator,VirtualBox,VirtualBoxVM,trojita,dragon,digikam,lyx,"
                  "okular,gwenview,krita,obs,libreoffice,soffice.bin,android-studio,studio",
    }
    for k, v in sets.items():
        if re.search(rf"^{k}=", cfg, re.M):
            cfg = re.sub(rf"^{k}=.*$", f"{k}={v}", cfg, flags=re.M)
        else:
            cfg = cfg.replace("[%General]\n", f"[%General]\n{k}={v}\n", 1)
    colors = {
        "window.color": hx(p["window"]), "inactive.window.color": hx(p["window"]),
        "base.color": hx(p["view"], 0xdd), "inactive.base.color": hx(p["view"], 0xdd),
        "alt.base.color": hx(p["alt"]), "inactive.alt.base.color": hx(p["alt"]),
        "button.color": hx(p["button"]), "tooltip.base.color": hx(p["tooltip"]),
        "highlight.color": hx(p["accent"]), "inactive.highlight.color": hx(mix(p["accent"], p["window"], .35)),
        "highlight.text.color": "#ffffff", "inactive.highlight.text.color": "#ffffff",
        "text.color": hx(p["text"]), "window.text.color": hx(p["text"]), "button.text.color": hx(p["text"]),
        "tooltip.text.color": hx(p["text"]), "inactive.text.color": hx(mix(p["text"], p["window"], .15)),
        "inactive.window.text.color": hx(mix(p["text"], p["window"], .15)),
        "disabled.text.color": hx(p["dim"]), "link.color": hx(p["link"]), "link.visited.color": hx(p["visited"]),
    }
    for k, v in colors.items():
        cfg = re.sub(rf"^{re.escape(k)}=.*$", f"{k}={v}", cfg, flags=re.M)
    cfg = re.sub(r"^comment=.*$", f"comment=Frost {name}: translucent, blurred, based on {p['kv']} by Tsu Jan", cfg, flags=re.M)
    write(base / f"Frost{name}.kvconfig", cfg)
    shutil.copy(src / f"{p['kv']}.svg", base / f"Frost{name}.svg")


# ------------------------------------------------------- Global themes (LnF)
def lookandfeel(name, p, base: Path):
    shutil.copytree(ROOT / "splash", base / "contents/splash")   # login splash
    write(base / "metadata.json", json.dumps({
        "KPlugin": {"Id": f"org.frost.{name.lower()}", "Name": f"Frost {name}",
                    "Description": "Frosted glass with a top bar and dock", "Authors": [{"Name": "ganeshak11"}],
                    "License": "GPL-2.0+", "Version": VERSION, "Category": "Plasma Look And Feel"},
        "X-Plasma-APIVersion": "2", "KPackageStructure": "Plasma/LookAndFeel"}, indent=2))
    write(base / "contents/defaults", f"""[kdeglobals][KDE]
widgetStyle=kvantum

[kdeglobals][General]
ColorScheme=Frost{name}

[kdeglobals][Icons]
Theme={p['icons']}

[plasmarc][Theme]
name=Frost

[kwinrc][org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__Frost{name}
ButtonsOnLeft=
ButtonsOnRight=IAX
BorderSize=None
BorderSizeAuto=false
""")


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    plasma_theme(OUT / "plasma/desktoptheme/Frost")
    for name, p in PAL.items():
        write(OUT / f"color-schemes/Frost{name}.colors", color_scheme(name, p))
        kvantum(name, p, OUT / f"Kvantum/Frost{name}")
        aurorae(name, p, OUT / f"aurorae/themes/Frost{name}")
        lookandfeel(name, p, OUT / f"plasma/look-and-feel/org.frost.{name.lower()}")
    print("built into", OUT)


if __name__ == "__main__":
    main()
