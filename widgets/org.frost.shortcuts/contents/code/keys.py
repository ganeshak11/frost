#!/usr/bin/env python3
"""The shortcuts for the Frost cheat sheet, read live from KDE's own shortcut
config (~/.config/kglobalshortcutsrc), so the sheet always shows the keys that
really work. Prints JSON: [{"group": ..., "items": [{"label": ..., "keys": [...]}]}].
Shortcuts with no key are left out. Read-only."""
import configparser, json, os

cfg = configparser.RawConfigParser(strict=False, interpolation=None, delimiters=("=",))
cfg.optionxform = str
try:
    cfg.read(os.path.expanduser("~/.config/kglobalshortcutsrc"))
except Exception:
    pass


def keys(value):
    """'Meta+Shift+S\\tPrint,Meta+Shift+S,Take a screenshot' -> ['Meta+Shift+S', 'Print']"""
    active = value.split(",")[0]
    return [k for k in active.split("\\t") if k and k != "none"]


def get(section, key):
    try:
        return keys(cfg.get(section, key))
    except Exception:
        return []


def widget(name):
    """the key of a plasmashell widget, found by its name ('Activate Dynamic Island Widget')"""
    if cfg.has_section("plasmashell"):
        for k, v in cfg.items("plasmashell"):
            if k.startswith("activate widget") and v.endswith(f",Activate {name} Widget"):
                found = keys(v)
                if found:
                    return found
    return []


groups = [
    ("Frost", [
        ("Spotlight search", ["Meta"]),
        ("Dynamic Island", widget("Dynamic Island")),
        ("Control Centre", widget("Control Centre")),
        ("Shortcut sheet", widget("Shortcut Sheet")),
        ("Frost Notes", get("services][frost-notes.desktop", "_launch")),
        ("Do Not Disturb", get("services][frost-dnd.desktop", "_launch")),
        ("Clipboard at pointer", get("plasmashell", "show-on-mouse-pos")),
        ("KRunner", get("services][org.kde.krunner.desktop", "_launch") or ["Alt+Space"]),
    ]),
    ("Windows", [
        ("Switch windows", get("kwin", "Walk Through Windows")),
        ("Overview", get("kwin", "Overview")),
        ("Peek at desktop", get("kwin", "Show Desktop")),
        ("Maximize", get("kwin", "Window Maximize")),
        ("Minimize", get("kwin", "Window Minimize")),
        ("Tile left", get("kwin", "Window Quick Tile Left")),
        ("Tile right", get("kwin", "Window Quick Tile Right")),
        ("Close window", get("kwin", "Window Close")),
        ("Desktop 1 / 2", get("kwin", "Switch to Desktop 1")[:1] + get("kwin", "Switch to Desktop 2")[:1]),
    ]),
    ("Screenshots", [
        ("Whole screen", get("services][org.kde.spectacle.desktop", "FullScreenScreenShot")),
        ("Region", get("services][org.kde.spectacle.desktop", "RectangularRegionScreenShot")),
        ("Window under pointer", get("services][org.kde.spectacle.desktop", "WindowUnderCursorScreenShot")),
        ("Open Spectacle", get("services][org.kde.spectacle.desktop", "_launch")),
    ]),
    ("Apps", [
        ("VS Code", get("services][code_code.desktop", "_launch")),
        ("Brave", get("services][brave-browser.desktop", "new-window")),
        ("Brave private", get("services][brave-browser.desktop", "new-private-window")),
        ("Antigravity", get("services][antigravity.desktop", "_launch")),
        ("System Settings", get("services][systemsettings.desktop", "_launch")),
    ]),
    ("In Spotlight", [
        ("Open", ["Enter"]),
        ("Other action (Dolphin…)", ["Shift+Enter"]),
        ("Project in terminal", ["Ctrl+Enter"]),
        ("Next group", ["Tab"]),
        ("Run a command", [">"]),
        ("This sheet", ["?"]),
    ]),
]

out = []
for name, items in groups:
    rows = []
    for label, ks in items:
        ks = [k for k in ks if k not in ("Tools", "Launch Mail", "Calculator")]   # special keyboard keys
        if not ks: continue
        # a second key only while the row stays short enough to keep its label
        if len(ks) > 1 and len((ks[0] + "+" + ks[1]).split("+")) > 4: ks = ks[:1]
        rows.append({"label": label, "keys": ks[:2]})
    if rows:
        out.append({"group": name, "items": rows})
print(json.dumps(out))
