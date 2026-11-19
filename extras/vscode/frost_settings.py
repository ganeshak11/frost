#!/usr/bin/env python3
"""Switch one editor's settings.json (VS Code / Cursor / Antigravity) to Frost Dark.

    frost_settings.py <settings.json> apply     use Frost Dark; colour overrides that
                                                were set for every theme are kept but
                                                moved under the previous theme's name, so
                                                they come back when you switch to it
    frost_settings.py <settings.json> revert    go back to the previous theme

The file is JSON with comments, so it's edited as text: comments and layout stay.
The previous theme is remembered in ~/.local/share/glass-theme/.
"""
import json, re, sys
from pathlib import Path

THEME = "Frost Dark"
KEYS = ("workbench.colorTheme", "workbench.preferredDarkColorTheme")   # the second wins when the
                                                                        # editor follows the system dark mode
SCOPED = ("workbench.colorCustomizations", "editor.tokenColorCustomizations")


def skip(s, i):
    """Index of the end of the string / comment starting at i, or i if none starts there."""
    if s[i] == '"':
        i += 1
        while s[i] != '"':
            i += 2 if s[i] == "\\" else 1
        return i + 1
    if s.startswith("//", i):
        return s.find("\n", i) if "\n" in s[i:] else len(s)
    if s.startswith("/*", i):
        return s.index("*/", i) + 2
    return i


def match(s, i):
    """s[i] is '{': index just past its matching '}'."""
    depth = 0
    while i < len(s):
        j = skip(s, i)
        if j != i:
            i = j; continue
        if s[i] == "{": depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0: return i + 1
        i += 1
    raise ValueError("unbalanced braces")


def first_token(s, i):
    """First character after i that isn't space or a comment."""
    while i < len(s):
        if s[i].isspace(): i += 1; continue
        j = skip(s, i) if s.startswith(("//", "/*"), i) else i
        if j != i: i = j; continue
        return i
    return i


def find(s, key):
    return re.search(r'"' + re.escape(key) + r'"\s*:\s*"([^"]*)"', s)


def put(s, key, value):
    """Set a top-level string setting, adding it if missing."""
    m = find(s, key)
    if m:
        return s[:m.start(1)] + value + s[m.end(1):]
    b = s.index("{") + 1
    rest = s[first_token(s, b):]
    return s[:b] + f'\n    "{key}": "{value}"' + ("," if not rest.startswith("}") else "") + s[b:]


def main():
    path, mode = Path(sys.argv[1]), sys.argv[2]
    state = Path.home() / ".local/share/glass-theme" / ("editor-theme-" + re.sub(r"\W+", "_", str(path)) + ".json")
    s = path.read_text() if path.exists() else "{\n}\n"
    if mode == "revert":
        old = json.loads(state.read_text()) if state.exists() else {}
        for key in KEYS:
            if old.get(key): s = put(s, key, old[key])
            elif key in old:   # it wasn't set before: take the line out again
                s = re.sub(r'\n[ \t]*"' + re.escape(key) + r'"\s*:\s*"[^"]*",?', "", s, count=1)
        path.write_text(s); print(f"{path}: back to {old.get(KEYS[0]) or 'previous theme'}")
        return
    m = find(s, KEYS[0])
    prev = m.group(1) if m else ""
    if prev == THEME:
        print(f"{path}: already Frost Dark"); return
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(json.dumps({k: (find(s, k).group(1) if find(s, k) else "") for k in KEYS}))
    # keep the old all-themes overrides, but only for the old theme
    for key in SCOPED:
        k = re.search(r'"' + re.escape(key) + r'"\s*:\s*\{', s)
        if not k or not prev: continue
        start = k.end() - 1
        end = match(s, start)
        t = first_token(s, start + 1)
        if s[t] == "}" or s.startswith('"[', t): continue        # empty, or already per-theme
        s = s[:start] + '{\n        "[' + prev + ']": ' + s[start:end] + "\n    }" + s[end:]
    for key in KEYS:
        s = put(s, key, THEME)
    path.write_text(s)
    print(f"{path}: Frost Dark (was {prev or 'default'})")


if __name__ == "__main__":
    main()
