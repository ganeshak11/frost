#!/usr/bin/env python3
"""Build the Frost themes for the terminal and its tools from palette/frost.toml
into build/terminal/ (install.sh puts them in place).

    kitty, Konsole/Yakuake, Zellij, Neovim + Vim, bat, fzf, LS_COLORS, lsd, eza,
    lazygit, lazydocker, k9s, btop, bottom, yazi, ranger, nnn, fastfetch, glow,
    less, cava, cmus, newsboat, git, and an optional terminal wallpaper.

Everything is dark only. Backgrounds are left transparent wherever the app
allows it, so the terminal's glass shows through.
"""
import json, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "palette"))
from frost_palette import P, ANSI, RAW, rgb, mix, xterm256  # noqa: E402

OUT = REPO / "build" / "terminal"
HEAD = "generated from palette/frost.toml by extras/terminal/build_terminal.py; edit the palette, not this file"


def write(rel, text):
    f = OUT / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)


def tc(hex_, bg=False):
    """24-bit SGR fragment: 38;2;r;g;b (or 48;... for a background)."""
    return ("48" if bg else "38") + ";2;%d;%d;%d" % rgb(hex_)


# ── kitty ────────────────────────────────────────────────────────────────────
def kitty():
    names = "\n".join(f"color{i:<2}  {c}" for i, c in enumerate(ANSI))
    write("kitty/frost-obsidian.conf", f"""# Frost / Obsidian Glass for kitty ({HEAD}).
# Included at the end of kitty.conf, so it overrides the colours there.
# Remove the `include frost-obsidian.conf` line to go back.

# glass: translucent black with KWin blur behind it
background            {P.obsidian}
background_opacity    {P.opacity}
background_blur       {P.blur}
foreground            {P.text}

cursor                {P.red}
cursor_text_color     {P.obsidian}
selection_foreground  {P.bright}
selection_background  {P.deep}
url_color             {P.link}
url_style             curly

# tabs: red pill for the active tab
tab_bar_style         fade
tab_bar_background    {P.obsidian}
active_tab_foreground   {P.bright}
active_tab_background   {P.red}
active_tab_font_style   bold
inactive_tab_foreground {P.muted}
inactive_tab_background {P.surface}
tab_title_template    " {{index}}: {{title}} "

active_border_color   {P.red}
inactive_border_color {P.line}

# palette tuned to the red accent
{names}

# type: JetBrains Mono, with the Nerd Font kept for icons (Private Use Area)
font_family           JetBrains Mono
bold_font             JetBrains Mono ExtraBold
symbol_map            U+E000-U+F8FF,U+F0000-U+FFFFD CaskaydiaCove Nerd Font
""")
    write("kitty/frost-image.conf", f"""# Frost terminal wallpaper for kitty ({HEAD}).
# Installed only with `extras/terminal/install.sh --image`.
background_image         ~/.local/share/frost/terminal-bg.png
background_image_layout  cscaled
background_tint          0.85
""")


# ── Konsole / Yakuake ────────────────────────────────────────────────────────
def konsole():
    def entry(name, c):
        r, g, b = rgb(c)
        return f"[{name}]\nColor={r},{g},{b}\n"
    out = [f"# Frost for Konsole and Yakuake ({HEAD})\n"]
    out.append(entry("Background", P.obsidian) + "\n" + entry("BackgroundFaint", P.obsidian) + "\n" + entry("BackgroundIntense", P.surface) + "\n")
    for i in range(8):
        out.append(entry(f"Color{i}", ANSI[i]) + "\n")
        out.append(entry(f"Color{i}Faint", mix(ANSI[i], P.obsidian, 0.4)) + "\n")
        out.append(entry(f"Color{i}Intense", ANSI[i + 8]) + "\n")
    out.append(entry("Foreground", P.text) + "\n" + entry("ForegroundFaint", P.muted) + "\n" + entry("ForegroundIntense", P.bright) + "\n")
    # Solid obsidian: on this Plasma/Kvantum setup Konsole's own translucency
    # blends with white instead of the desktop (kitty's glass is unaffected).
    out.append(f"""[General]
Anchor=0.5,0.5
Blur=false
ColorRandomization=false
Description=Frost
FillStyle=Crop
Opacity=1
Wallpaper=
WallpaperFlipType=NoFlip
WallpaperOpacity=1
""")
    write("konsole/Frost.colorscheme", "".join(out))


# ── Zellij ───────────────────────────────────────────────────────────────────
def zellij():
    def c(hex_): return "%d %d %d" % rgb(hex_)
    em = (P.red, P.info, P.ok, P.warn)
    on_red = (P.obsidian, P.bright, P.obsidian, P.bright)

    def comp(name, base, bg, emph=em):   # zellij wants one property per line
        lines = [f"base {c(base)}", f"background {c(bg)}"] + [f"emphasis_{i} {c(e)}" for i, e in enumerate(emph)]
        return f"        {name} {{\n" + "".join(f"            {x}\n" for x in lines) + "        }\n"
    body = (comp("text_unselected", P.text, P.obsidian)
            + comp("text_selected", P.bright, P.raised)
            + comp("ribbon_selected", P.bright, P.red, on_red)
            + comp("ribbon_unselected", P.muted, P.surface)
            + comp("table_title", P.red, P.obsidian)
            + comp("table_cell_selected", P.bright, P.raised)
            + comp("table_cell_unselected", P.text, P.obsidian)
            + comp("list_selected", P.bright, P.raised)
            + comp("list_unselected", P.text, P.obsidian)
            + comp("frame_selected", P.red, P.obsidian)
            + comp("frame_unselected", P.line, P.obsidian)
            + comp("frame_highlight", P.warn, P.obsidian)
            + comp("exit_code_success", P.ok, P.obsidian)
            + comp("exit_code_error", P.red, P.obsidian))
    players = [P.red, P.info, P.ok, P.warn, ANSI[5], ANSI[6], P.soft, P.property, P.type, P.string]
    body += "        multiplayer_user_colors {\n" + "".join(f"            player_{i + 1} {c(p)}\n" for i, p in enumerate(players)) + "        }\n"
    write("zellij/frost.kdl", f"// Frost for Zellij ({HEAD})\nthemes {{\n    frost {{\n{body}    }}\n}}\n")


# ── Neovim + Vim ─────────────────────────────────────────────────────────────
def vim():
    N = "NONE"
    S = P  # short
    g = {
        "Normal": (S.text, N), "NormalNC": (S.text, N), "NormalFloat": (S.text, S.raised),
        "FloatBorder": (S.line, S.raised), "FloatTitle": (S.red, S.raised, "bold"),
        "ColorColumn": (None, S.surface), "Cursor": (S.obsidian, S.red), "lCursor": (S.obsidian, S.red),
        "CursorLine": (None, S.surface), "CursorColumn": (None, S.surface),
        "CursorLineNr": (S.text, None, "bold"), "LineNr": (S.dim, None),
        "SignColumn": (None, N), "FoldColumn": (S.faint, N), "Folded": (S.muted, S.surface, "italic"),
        "VertSplit": (S.line, N), "WinSeparator": (S.line, N),
        "StatusLine": (S.text, S.raised), "StatusLineNC": (S.faint, S.surface),
        "TabLine": (S.muted, S.surface), "TabLineFill": (None, N), "TabLineSel": (S.bright, S.red, "bold"),
        "WinBar": (S.text, N, "bold"), "WinBarNC": (S.faint, N),
        "Visual": (None, S.deep), "VisualNOS": (None, S.deep),
        "Search": (S.bright, S.deep), "IncSearch": (S.bright, S.red, "bold"), "CurSearch": (S.bright, S.red, "bold"),
        "Substitute": (S.bright, S.red), "MatchParen": (S.red, None, "bold,underline"),
        "Pmenu": (S.text, S.raised), "PmenuSel": (S.bright, S.deep, "bold"), "PmenuSbar": (None, S.surface),
        "PmenuThumb": (None, S.line), "PmenuKind": (S.muted, S.raised), "PmenuExtra": (S.faint, S.raised),
        "PmenuMatch": (S.red, S.raised, "bold"), "PmenuMatchSel": (S.bright, S.deep, "bold"),
        "WildMenu": (S.bright, S.deep), "QuickFixLine": (None, S.wash),
        "NonText": (S.dim, None), "EndOfBuffer": (S.obsidian, None), "Whitespace": (S.line, None),
        "SpecialKey": (S.dim, None), "Conceal": (S.faint, None),
        "Directory": (S.red, None, "bold"), "Title": (S.heading, None, "bold"),
        "ErrorMsg": (S.error, None, "bold"), "WarningMsg": (S.warn, None), "MoreMsg": (S.ok, None),
        "ModeMsg": (S.text, None, "bold"), "Question": (S.info, None),
        "SpellBad": (None, None, "undercurl", S.error), "SpellCap": (None, None, "undercurl", S.warn),
        "SpellRare": (None, None, "undercurl", S.info), "SpellLocal": (None, None, "undercurl", S.muted),
        "Comment": (S.comment, None, "italic"),
        "Constant": (S.constant,), "String": (S.string,), "Character": (S.string,),
        "Number": (S.number,), "Boolean": (S.number,), "Float": (S.number,),
        "Identifier": (S.text,), "Function": (S.function,),
        "Statement": (S.keyword,), "Conditional": (S.keyword,), "Repeat": (S.keyword,), "Label": (S.keyword,),
        "Operator": (S.operator,), "Keyword": (S.keyword,), "Exception": (S.keyword,),
        "PreProc": (S.keyword,), "Include": (S.keyword,), "Define": (S.keyword,), "Macro": (S.constant,), "PreCondit": (S.keyword,),
        "Type": (S.type,), "StorageClass": (S.keyword,), "Structure": (S.type,), "Typedef": (S.type,),
        "Special": (S.escape,), "SpecialChar": (S.escape,), "Tag": (S.keyword,), "Delimiter": (S.operator,),
        "SpecialComment": (S.muted, None, "italic"), "Debug": (S.warn,),
        "Underlined": (S.url, None, "underline"), "Error": (S.error, None, "bold"), "Todo": (S.obsidian, S.warn, "bold"),
        "DiffAdd": (None, mix(S.obsidian, S.added, 0.18)), "DiffChange": (None, mix(S.obsidian, S.changed, 0.12)),
        "DiffDelete": (mix(S.obsidian, S.deleted, 0.6), mix(S.obsidian, S.deleted, 0.14)),
        "DiffText": (None, mix(S.obsidian, S.changed, 0.3)),
        "diffAdded": (S.added,), "diffRemoved": (S.deleted,), "diffChanged": (S.changed,),
        "diffFile": (S.text, None, "bold"), "diffLine": (S.red,),
        "htmlH1": (S.heading, None, "bold"), "markdownH1": (S.heading, None, "bold"), "markdownCode": (S.string,),
        "TelescopeNormal": (S.text, N), "TelescopeBorder": (S.line, N), "TelescopeTitle": (S.red, None, "bold"),
        "TelescopePromptPrefix": (S.red,), "TelescopeSelection": (S.bright, S.wash, "bold"),
        "TelescopeSelectionCaret": (S.red, S.wash), "TelescopeMatching": (S.red, None, "bold"),
        "TelescopeMultiSelection": (S.warn,),
    }
    nv = {  # Neovim only: diagnostics, tree-sitter, LSP, git signs
        "Added": (S.added,), "Changed": (S.changed,), "Removed": (S.deleted,),
        "DiagnosticError": (S.error,), "DiagnosticWarn": (S.warn,), "DiagnosticInfo": (S.info,),
        "DiagnosticHint": (S.muted,), "DiagnosticOk": (S.ok,),
        "DiagnosticUnderlineError": (None, None, "undercurl", S.error), "DiagnosticUnderlineWarn": (None, None, "undercurl", S.warn),
        "DiagnosticUnderlineInfo": (None, None, "undercurl", S.info), "DiagnosticUnderlineHint": (None, None, "undercurl", S.muted),
        "LspReferenceText": (None, S.raised), "LspReferenceRead": (None, S.raised), "LspReferenceWrite": (None, S.raised),
        "LspInlayHint": (S.faint, None, "italic"),
        "@variable": (S.text,), "@variable.builtin": (S.keyword, None, "italic"), "@variable.parameter": (S.parameter, None, "italic"),
        "@variable.member": (S.property,), "@property": (S.property,), "@field": (S.property,),
        "@constant": (S.constant,), "@constant.builtin": (S.constant,), "@module": (S.type,),
        "@function": (S.function,), "@function.builtin": (S.function,), "@function.call": (S.function,),
        "@function.method": (S.function,), "@function.method.call": (S.function,), "@constructor": (S.type,),
        "@type": (S.type,), "@type.builtin": (S.type,), "@attribute": (S.escape,),
        "@keyword": (S.keyword,), "@keyword.return": (S.keyword,), "@keyword.function": (S.keyword,),
        "@string": (S.string,), "@string.escape": (S.escape,), "@string.regexp": (S.escape,),
        "@number": (S.number,), "@boolean": (S.number,), "@comment": (S.comment, None, "italic"),
        "@punctuation": (S.operator,), "@punctuation.bracket": (S.operator,), "@punctuation.delimiter": (S.operator,),
        "@operator": (S.operator,), "@tag": (S.keyword,), "@tag.attribute": (S.type, None, "italic"),
        "@tag.delimiter": (S.operator,),
        "@markup.heading": (S.heading, None, "bold"), "@markup.strong": (S.text, None, "bold"),
        "@markup.italic": (S.text, None, "italic"), "@markup.raw": (S.string,), "@markup.link": (S.url,),
        "@markup.link.url": (S.url, None, "underline"), "@markup.list": (S.red,),
        "@lsp.type.parameter": (S.parameter, None, "italic"), "@lsp.type.property": (S.property,),
        "@lsp.type.namespace": (S.type,), "@lsp.type.enumMember": (S.constant,),
        "GitSignsAdd": (S.added,), "GitSignsChange": (S.changed,), "GitSignsDelete": (S.deleted,),
        "LazyNormal": (S.text, S.raised), "LazyButtonActive": (S.bright, S.red, "bold"), "LazyH1": (S.bright, S.red, "bold"),
    }

    def hi(name, spec):
        fg, bg, style, sp = (list(spec) + [None, None, None])[:4]
        parts = [f"hi {name}"]
        if fg: parts.append(f"guifg={fg}" + ("" if fg == N else f" ctermfg={xterm256(fg)}"))
        if bg: parts.append(f"guibg={bg}" + (" ctermbg=NONE" if bg == N else f" ctermbg={xterm256(bg)}"))
        parts.append(f"gui={style or 'NONE'} cterm={(style or 'NONE').replace('undercurl', 'underline')}")
        if sp: parts.append(f"guisp={sp}")
        return " ".join(parts)

    term = "\n".join(f"  let g:terminal_color_{i} = '{c}'" for i, c in enumerate(ANSI))
    text = f"""" Frost for Neovim and Vim ({HEAD}).
" Dark only. The background is left transparent so the terminal's glass shows.
hi clear
if exists('syntax_on') | syntax reset | endif
set background=dark
let g:colors_name = 'frost'

{chr(10).join(hi(k, v) for k, v in g.items())}

if has('nvim')
{chr(10).join('  ' + hi(k, v) for k, v in nv.items())}
{term}
endif
"""
    write("vim/frost.vim", text)
    write("vim/vimrc", f"""" Frost: Vim settings ({HEAD}).
" Created by extras/terminal/install.sh because you had no ~/.vimrc; it keeps
" Vim's usual defaults and adds the Frost colours. Revert deletes it again.
source $VIMRUNTIME/defaults.vim
if has('termguicolors') | set termguicolors | endif
silent! colorscheme frost
""")


# ── bat (also the colours of `man` through MANPAGER) ─────────────────────────
def bat():
    def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;")

    def d(pairs):
        return "<dict>" + "".join(f"<key>{k}</key><string>{esc(v)}</string>" for k, v in pairs.items()) + "</dict>"
    S = P
    rules = [
        ("Comment", "comment, punctuation.definition.comment", S.comment, "italic"),
        ("Keyword", "keyword, storage, storage.type, keyword.control, keyword.operator.new", S.keyword, ""),
        ("Operator", "keyword.operator, punctuation", S.operator, ""),
        ("String", "string, string.template, punctuation.definition.string", S.string, ""),
        ("Escape", "constant.character.escape, string.regexp", S.escape, ""),
        ("Number", "constant.numeric, constant.language.boolean", S.number, ""),
        ("Constant", "constant, constant.language, variable.other.constant, support.constant", S.constant, ""),
        ("Function", "entity.name.function, support.function, meta.function-call, variable.function", S.function, ""),
        ("Type", "entity.name.type, entity.name.class, support.type, support.class, entity.other.inherited-class, storage.type.primitive, entity.name.namespace", S.type, ""),
        ("Variable", "variable, variable.other.readwrite", S.text, ""),
        ("Parameter", "variable.parameter", S.parameter, "italic"),
        ("Property", "variable.other.property, support.variable.property, meta.object-literal.key, entity.name.tag.yaml, support.type.property-name", S.property, ""),
        ("Self", "variable.language.this, variable.language.self, variable.language.super", S.keyword, "italic"),
        ("Tag", "entity.name.tag", S.keyword, ""),
        ("Attribute", "entity.other.attribute-name", S.type, "italic"),
        ("Decorator", "entity.name.decorator, meta.decorator", S.escape, ""),
        ("Heading", "markup.heading, entity.name.section", S.heading, "bold"),
        ("Bold", "markup.bold", S.text, "bold"), ("Italic", "markup.italic", S.text, "italic"),
        ("Raw", "markup.raw, markup.inline.raw, markup.fenced_code", S.string, ""),
        ("Link", "markup.underline.link", S.url, "underline"),
        ("Inserted", "markup.inserted", S.added, ""), ("Deleted", "markup.deleted", S.deleted, ""),
        ("Changed", "markup.changed", S.changed, ""), ("Diff header", "meta.diff.header, meta.diff.range", S.red, "bold"),
        ("Invalid", "invalid", S.error, "underline"),
    ]
    items = [d({"background": S.obsidian, "foreground": S.text, "caret": S.red, "lineHighlight": S.surface,
                "selection": S.deep, "gutter": S.obsidian, "gutterForeground": S.dim, "invisibles": S.line,
                "findHighlight": S.red, "findHighlightForeground": S.bright})]
    items[0] = "<dict><key>settings</key>" + items[0] + "</dict>"
    for name, scope, fg, style in rules:
        items.append(f"<dict><key>name</key><string>{name}</string><key>scope</key><string>{scope}</string>"
                     f"<key>settings</key>{d({'foreground': fg, **({'fontStyle': style} if style else {})})}</dict>")
    write("bat/Frost.tmTheme", f"""<?xml version="1.0" encoding="UTF-8"?>
<!-- Frost for bat ({HEAD}) -->
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>name</key><string>Frost</string>
<key>settings</key><array>
{chr(10).join(items)}
</array>
<key>uuid</key><string>6f1d7e2a-f21d-4343-8f0b-0b0e0b0e0b0e</string>
</dict></plist>
""")


# ── LS_COLORS (ls, lsd, eza, fd, tree ... all read it) ───────────────────────
def dircolors():
    S = P
    groups = {
        S.warn: "tar tgz gz xz zst bz2 7z zip rar deb rpm iso appimage AppImage jar whl",
        ANSI[5]: "png jpg jpeg gif svg webp bmp ico tif tiff heic avif xcf kra",
        ANSI[13]: "mp3 flac ogg opus wav m4a mp4 mkv webm mov avi",
        S.property: "json jsonc toml yaml yml ini conf cfg kdl xml env",
        S.text: "md txt pdf doc docx odt rst",
        S.dim: "bak tmp swp log part crdownload old orig lock",
    }
    lines = [f"# Frost LS_COLORS ({HEAD})", "TERM *", "COLORTERM ?*", "RESET 0",
             f"DIR 01;{tc(S.red)}", f"LINK {tc(ANSI[6])}", "MULTIHARDLINK 00",
             f"FIFO {tc(S.warn)}", f"SOCK {tc(ANSI[5])}", f"DOOR {tc(ANSI[5])}",
             f"BLK 01;{tc(S.warn)}", f"CHR 01;{tc(S.warn)}",
             f"ORPHAN {tc(S.error)};09", f"MISSING {tc(S.error)};09",
             f"SETUID {tc(S.bright)};{tc(S.deep, True)}", f"SETGID {tc(S.bright)};{tc(S.deep, True)}",
             "CAPABILITY 00",
             f"STICKY_OTHER_WRITABLE 01;{tc(S.red)};{tc(S.wash, True)}",
             f"OTHER_WRITABLE 01;{tc(S.red)};{tc(S.wash, True)}",
             f"STICKY 01;{tc(S.red)};{tc(S.wash, True)}",
             f"EXEC 01;{tc(S.ok)}"]
    for col, exts in groups.items():
        lines += [f"*.{e} {tc(col)}" for e in exts.split()]
    lines.append(f"*~ {tc(S.dim)}")
    write("shell/dircolors", "\n".join(lines) + "\n")


# ── the shell file: fzf, bat, man/less, nnn ──────────────────────────────────
def shell():
    S = P
    fzf = (f"fg:{S.text},bg:-1,hl:{S.red},fg+:{S.bright},bg+:{S.wash},hl+:{S.soft},gutter:-1,"
           f"info:{S.muted},prompt:{S.red},pointer:{S.red},marker:{S.ok},spinner:{S.red},header:{S.muted},"
           f"border:{S.line},label:{S.muted},query:{S.text},separator:{S.line},scrollbar:{S.line},"
           f"preview-border:{S.line},preview-bg:-1")
    e = lambda *parts: "$'\\e[" + ";".join(parts) + "m'"   # noqa: E731
    # nnn: block, char, dir, exec, regular, hardlink, symlink, details, orphan, fifo, socket, unknown
    nnn = "".join("%02x" % n for n in (3, 3, 1, 2, 0, 6, 6, xterm256(S.muted), 9, 3, 5, 0))
    write("shell/terminal.sh", f"""# Frost colours for the terminal tools ({HEAD}).
# Sourced at the end of ~/.bashrc and ~/.zshrc by extras/terminal/install.sh
# (the line marked "frost-terminal"); revert removes that line.

# ls / lsd / eza / fd: file colours
if command -v dircolors >/dev/null 2>&1 && [ -r ~/.config/frost/dircolors ]; then
    eval "$(dircolors -b ~/.config/frost/dircolors)"
fi

# fzf: your options stay, the Frost colours go last so they win
export FZF_DEFAULT_OPTS="${{FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }}--color={fzf}"

# bat (batcat on Debian/Ubuntu; /usr/sbin/bat there is Bacula, so check it is the real one)
if command -v batcat >/dev/null 2>&1; then _frost_bat=batcat
elif command -v bat >/dev/null 2>&1 && bat --version 2>/dev/null | grep -q '^bat '; then _frost_bat=bat
else _frost_bat=; fi
if [ -n "$_frost_bat" ]; then
    export BAT_THEME=Frost
    # aliases that pin another theme are redefined with Frost
    alias cat >/dev/null 2>&1 && alias cat="$_frost_bat --paging=never --theme=Frost"
    alias bat >/dev/null 2>&1 && alias bat="$_frost_bat --theme=Frost"
    case "$MANPAGER" in *bat*) export MANPAGER="sh -c 'col -bx | $_frost_bat -l man -p --theme=Frost'" ;; esac
fi
unset _frost_bat

# less (and man when it isn't going through bat)
export LESS_TERMCAP_mb={e('01', tc(S.red))}
export LESS_TERMCAP_md={e('01', tc(S.red))}
export LESS_TERMCAP_me=$'\\e[0m'
export LESS_TERMCAP_so={e('01', tc(S.bright), tc(S.deep, True))}
export LESS_TERMCAP_se=$'\\e[0m'
export LESS_TERMCAP_us={e('04', tc(S.property))}
export LESS_TERMCAP_ue=$'\\e[0m'

# nnn
export NNN_FCOLORS='{nnn}'
export NNN_COLORS='1111'
""")


# ── lsd ──────────────────────────────────────────────────────────────────────
def lsd():
    x = xterm256
    S = P
    write("lsd/colors.yaml", f"""# Frost for lsd ({HEAD}). File names take LS_COLORS.
user: {x(S.text)}
group: {x(S.muted)}
permission:
  read: {x(S.ok)}
  write: {x(S.warn)}
  exec: 1
  exec-sticky: 5
  no-access: {x(S.dim)}
  octal: {x(S.muted)}
  acl: 6
  context: 6
date:
  hour-old: {x(S.bright)}
  day-old: {x(S.text)}
  older: {x(S.muted)}
size:
  none: {x(S.dim)}
  small: {x(S.muted)}
  medium: {x(S.text)}
  large: 1
inode:
  valid: {x(S.muted)}
  invalid: {x(S.dim)}
links:
  valid: 6
  invalid: {x(S.error)}
tree-edge: {x(S.line)}
git-status:
  default: {x(S.muted)}
  unmodified: {x(S.muted)}
  ignored: {x(S.dim)}
  new-in-index: 2
  new-in-workdir: 2
  typechange: 3
  deleted: 1
  renamed: 6
  modified: 3
  conflicted: 9
""")


# ── eza ──────────────────────────────────────────────────────────────────────
def eza():
    S = P

    def f(c, bold=False): return "{foreground: \"%s\"%s}" % (c, ", is_bold: true" if bold else "")
    write("eza/theme.yml", f"""# Frost for eza ({HEAD})
colourful: true
filekinds:
  normal: {f(S.text)}
  directory: {f(S.red, True)}
  symlink: {f(ANSI[6])}
  pipe: {f(S.warn)}
  block_device: {f(S.warn, True)}
  char_device: {f(S.warn, True)}
  socket: {f(ANSI[5])}
  special: {f(ANSI[5])}
  executable: {f(S.ok, True)}
  mount_point: {f(S.red, True)}
perms:
  user_read: {f(S.ok)}
  user_write: {f(S.warn)}
  user_execute_file: {f(S.red, True)}
  user_execute_other: {f(S.red)}
  group_read: {f(S.ok)}
  group_write: {f(S.warn)}
  group_execute: {f(S.red)}
  other_read: {f(S.ok)}
  other_write: {f(S.warn)}
  other_execute: {f(S.red)}
  special_user_file: {f(ANSI[5])}
  special_other: {f(ANSI[5])}
  attribute: {f(S.muted)}
size:
  major: {f(S.muted)}
  minor: {f(S.muted)}
  number_byte: {f(S.muted)}
  number_kilo: {f(S.text)}
  number_mega: {f(S.text, True)}
  number_giga: {f(S.red)}
  number_huge: {f(S.red, True)}
  unit_byte: {f(S.dim)}
  unit_kilo: {f(S.dim)}
  unit_mega: {f(S.dim)}
  unit_giga: {f(S.dim)}
  unit_huge: {f(S.dim)}
users:
  user_you: {f(S.text)}
  user_root: {f(S.red)}
  user_other: {f(S.muted)}
  group_yours: {f(S.muted)}
  group_other: {f(S.dim)}
  group_root: {f(S.red)}
links:
  normal: {f(ANSI[6])}
  multi_link_file: {f(ANSI[6], True)}
git:
  new: {f(S.ok)}
  modified: {f(S.warn)}
  deleted: {f(S.red)}
  renamed: {f(ANSI[6])}
  typechange: {f(ANSI[5])}
  ignored: {f(S.dim)}
  conflicted: {f(S.error, True)}
git_repo:
  branch_main: {f(S.text)}
  branch_other: {f(S.red)}
  git_clean: {f(S.ok)}
  git_dirty: {f(S.warn)}
date: {f(S.muted)}
inode: {f(S.dim)}
blocks: {f(S.dim)}
header: {f(S.muted, True)}
octal: {f(S.muted)}
flags: {f(S.muted)}
punctuation: {f(S.dim)}
control_char: {f(S.error)}
broken_symlink: {f(S.error)}
broken_path_overlay: {f(S.error)}
""")


# ── lazygit / lazydocker / k9s ───────────────────────────────────────────────
def tuis():
    S = P
    write("lazygit/theme.json", json.dumps({
        "activeBorderColor": [S.red, "bold"], "inactiveBorderColor": [S.line],
        "searchingActiveBorderColor": [S.warn, "bold"], "optionsTextColor": [S.muted],
        "selectedLineBgColor": [S.wash], "inactiveViewSelectedLineBgColor": [S.surface],
        "cherryPickedCommitFgColor": [S.obsidian], "cherryPickedCommitBgColor": [ANSI[6]],
        "markedBaseCommitFgColor": [S.obsidian], "markedBaseCommitBgColor": [S.warn],
        "unstagedChangesColor": [S.red], "defaultFgColor": [S.text],
    }, indent=2))
    write("lazydocker/theme.json", json.dumps({
        "activeBorderColor": [S.red, "bold"], "inactiveBorderColor": [S.line],
        "selectedLineBgColor": [S.wash], "optionsTextColor": [S.muted],
    }, indent=2))
    write("k9s/frost.yaml", f"""# Frost skin for k9s ({HEAD})
k9s:
  body:
    fgColor: "{S.text}"
    bgColor: default
    logoColor: "{S.red}"
  prompt:
    fgColor: "{S.text}"
    bgColor: default
    suggestColor: "{S.muted}"
  info:
    fgColor: "{S.red}"
    sectionColor: "{S.text}"
  dialog:
    fgColor: "{S.text}"
    bgColor: default
    buttonFgColor: "{S.text}"
    buttonBgColor: "{S.raised}"
    buttonFocusFgColor: "{S.bright}"
    buttonFocusBgColor: "{S.red}"
    labelFgColor: "{S.red}"
    fieldFgColor: "{S.text}"
  frame:
    border:
      fgColor: "{S.line}"
      focusColor: "{S.red}"
    menu:
      fgColor: "{S.text}"
      keyColor: "{S.red}"
      numKeyColor: "{S.soft}"
    crumbs:
      fgColor: "{S.bright}"
      bgColor: "{S.raised}"
      activeColor: "{S.red}"
    status:
      newColor: "{S.info}"
      modifyColor: "{S.warn}"
      addColor: "{S.ok}"
      pendingColor: "{S.warn}"
      errorColor: "{S.error}"
      highlightColor: "{S.red}"
      killColor: "{S.muted}"
      completedColor: "{S.dim}"
    title:
      fgColor: "{S.text}"
      bgColor: default
      highlightColor: "{S.red}"
      counterColor: "{S.soft}"
      filterColor: "{S.warn}"
  views:
    charts:
      bgColor: default
      defaultDialColors: ["{S.red}", "{S.dim}"]
      defaultChartColors: ["{S.red}", "{S.soft}"]
    table:
      fgColor: "{S.text}"
      bgColor: default
      cursorFgColor: "{S.bright}"
      cursorBgColor: "{S.deep}"
      markColor: "{S.warn}"
      header:
        fgColor: "{S.muted}"
        bgColor: default
        sorterColor: "{S.red}"
    xray:
      fgColor: "{S.text}"
      bgColor: default
      cursorColor: "{S.deep}"
      cursorTextColor: "{S.bright}"
      graphicColor: "{S.red}"
    yaml:
      keyColor: "{S.property}"
      colonColor: "{S.muted}"
      valueColor: "{S.text}"
    logs:
      fgColor: "{S.text}"
      bgColor: default
      indicator:
        fgColor: "{S.text}"
        bgColor: "{S.raised}"
        toggleOnColor: "{S.red}"
        toggleOffColor: "{S.dim}"
""")


# ── btop / bottom ────────────────────────────────────────────────────────────
def monitors():
    S = P
    grad = (mix(S.red, S.obsidian, 0.45), S.red, "#ff8aa0")
    t = {
        "main_bg": "", "main_fg": S.text, "title": S.text, "hi_fg": S.red,
        "selected_bg": S.deep, "selected_fg": S.bright, "inactive_fg": S.dim, "graph_text": S.muted,
        "meter_bg": S.line, "proc_misc": S.soft, "cpu_box": S.line, "mem_box": S.line, "net_box": S.line,
        "proc_box": S.line, "div_line": S.line,
        "temp_start": S.muted, "temp_mid": S.warn, "temp_end": S.red,
        "cpu_start": grad[0], "cpu_mid": grad[1], "cpu_end": grad[2],
        "free_start": mix(S.ok, S.obsidian, 0.5), "free_mid": "", "free_end": S.ok,
        "cached_start": mix(S.info, S.obsidian, 0.5), "cached_mid": "", "cached_end": S.info,
        "available_start": mix(S.text, S.obsidian, 0.5), "available_mid": "", "available_end": S.text,
        "used_start": grad[0], "used_mid": grad[1], "used_end": grad[2],
        "download_start": mix(S.red, S.obsidian, 0.6), "download_mid": S.red, "download_end": "#ff8aa0",
        "upload_start": mix(S.text, S.obsidian, 0.6), "upload_mid": S.muted, "upload_end": S.text,
        "process_start": S.text, "process_mid": S.soft, "process_end": S.red,
    }
    write("btop/frost.theme", f"# Frost for btop ({HEAD})\n" + "".join(f'theme[{k}]="{v}"\n' for k, v in t.items()))
    cores = [S.red, S.soft, "#ff8aa0", S.constant, S.function, S.parameter, S.muted, S.text]
    write("bottom/bottom.toml", f"""# Frost for bottom ({HEAD})
[styles.cpu]
all_entry_color = "{S.red}"
avg_entry_color = "{S.soft}"
cpu_core_colors = [{", ".join(f'"{c}"' for c in cores)}]

[styles.memory]
ram_color = "{S.red}"
cache_color = "{S.info}"
swap_color = "{S.warn}"
arc_color = "{ANSI[6]}"
gpu_colors = ["{S.soft}", "{S.property}"]

[styles.network]
rx_color = "{S.red}"
tx_color = "{S.text}"
rx_total_color = "{S.soft}"
tx_total_color = "{S.muted}"

[styles.battery]
high_battery_color = "{S.ok}"
medium_battery_color = "{S.warn}"
low_battery_color = "{S.red}"

[styles.tables]
headers = {{ color = "{S.red}", bold = true }}

[styles.graphs]
graph_color = "{S.dim}"
legend_text = {{ color = "{S.muted}" }}

[styles.widgets]
border_color = "{S.line}"
selected_border_color = "{S.red}"
widget_title = {{ color = "{S.text}", bold = true }}
text = {{ color = "{S.text}" }}
selected_text = {{ color = "{S.bright}", bg_color = "{S.deep}" }}
disabled_text = {{ color = "{S.dim}" }}
""")


# ── yazi / ranger ────────────────────────────────────────────────────────────
def files():
    S = P

    def st(fg=None, bg=None, bold=False, reversed_=False):
        parts = []
        if fg: parts.append(f'fg = "{fg}"')
        if bg: parts.append(f'bg = "{bg}"')
        if bold: parts.append("bold = true")
        if reversed_: parts.append("reversed = true")
        return "{ " + ", ".join(parts) + " }"
    write("yazi/theme.toml", f"""# Frost for yazi ({HEAD})
[mgr]
cwd = {st(S.red, bold=True)}
find_keyword  = {st(S.warn, bold=True)}
find_position = {st(S.soft)}
marker_copied   = {st(S.ok, S.ok)}
marker_cut      = {st(S.red, S.red)}
marker_marked   = {st(ANSI[6], ANSI[6])}
marker_selected = {st(S.warn, S.warn)}
count_copied   = {st(S.obsidian, S.ok)}
count_cut      = {st(S.bright, S.red)}
count_selected = {st(S.obsidian, S.warn)}
border_symbol = "│"
border_style  = {st(S.line)}
# code previews in the same colours as bat (install.sh puts Frost.tmTheme there)
syntect_theme = "~/.config/bat/themes/Frost.tmTheme"

[indicator]
parent  = {st(S.bright, S.raised)}
current = {st(S.bright, S.wash, bold=True)}
preview = {st(S.bright, S.raised)}

[tabs]
active   = {st(S.bright, S.red, bold=True)}
inactive = {st(S.muted, S.surface)}

[mode]
normal_main = {st(S.bright, S.red, bold=True)}
normal_alt  = {st(S.red, S.raised)}
select_main = {st(S.obsidian, S.warn, bold=True)}
select_alt  = {st(S.warn, S.raised)}
unset_main  = {st(S.obsidian, ANSI[6], bold=True)}
unset_alt   = {st(ANSI[6], S.raised)}

[status]
perm_type  = {st(S.red)}
perm_read  = {st(S.ok)}
perm_write = {st(S.warn)}
perm_exec  = {st(S.red)}
perm_sep   = {st(S.dim)}
progress_label  = {st(S.bright, bold=True)}
progress_normal = {st(S.red, S.raised)}
progress_error  = {st(S.error, S.raised)}

[icon]
# folder icons in Frost red, like the folder names (yazi's default is blue)
prepend_conds = [
  {{ if = "dir", text = "\\uf07b", fg = "{S.red}" }},
]

[filetype]
rules = [
  {{ url = "*/", fg = "{S.red}", bold = true }},
  {{ mime = "image/*", fg = "{ANSI[5]}" }},
  {{ mime = "{{audio,video}}/*", fg = "{ANSI[13]}" }},
  {{ mime = "application/{{zip,gzip,x-tar,x-xz,x-7z-compressed,x-rar,zstd,x-bzip2}}", fg = "{S.warn}" }},
  {{ url = "*", is = "exec", fg = "{S.ok}" }},
  {{ url = "*", is = "link", fg = "{ANSI[6]}" }},
  {{ url = "*", is = "orphan", fg = "{S.error}" }},
]
""")
    write("ranger/frost.py", f'''# Frost colour scheme for ranger ({HEAD}).
# Uses the terminal's ANSI colours, which kitty and Konsole set to Frost
# (red is exactly the Frost red), so it stays in step with the palette.
from ranger.colorschemes.default import Default
from ranger.gui.color import bold, reverse, red, green, yellow, cyan, white, default_colors

BRIGHT_WHITE = 15
RAISED = {xterm256(S.raised)}


class Scheme(Default):
    progress_bar_color = red

    def use(self, context):
        if context.reset:
            return default_colors
        fg, bg, attr = Default.use(self, context)
        if context.in_browser:
            if context.selected:
                attr &= ~reverse
                attr |= bold
                fg, bg = BRIGHT_WHITE, (red if context.main_column else RAISED)
            elif context.directory:
                fg, attr = red, attr | bold
            elif context.link:
                fg = cyan
            elif context.executable:
                fg = green
        elif context.in_titlebar:
            if context.hostname:
                fg, attr = red, attr | bold
            elif context.directory:
                fg = white
            elif context.tab and context.good:
                fg, bg = BRIGHT_WHITE, red
        elif context.in_statusbar:
            if context.marked:
                fg = yellow
            if context.message and context.bad:
                fg = red
        return fg, bg, attr
''')


# ── glow ─────────────────────────────────────────────────────────────────────
def glow():
    S = P
    style = {
        "document": {"block_prefix": "\n", "block_suffix": "\n", "color": S.text, "margin": 2},
        "block_quote": {"indent": 1, "indent_token": "│ ", "color": S.muted, "italic": True},
        "paragraph": {}, "list": {"level_indent": 2},
        "heading": {"block_suffix": "\n", "color": S.heading, "bold": True},
        "h1": {"prefix": " ", "suffix": " ", "color": S.bright, "background_color": S.red, "bold": True},
        "h2": {"prefix": "## "}, "h3": {"prefix": "### "}, "h4": {"prefix": "#### "},
        "h5": {"prefix": "##### "}, "h6": {"prefix": "###### ", "color": S.muted, "bold": False},
        "text": {}, "strikethrough": {"crossed_out": True}, "emph": {"italic": True},
        "strong": {"bold": True, "color": S.bright}, "hr": {"color": S.line, "format": "\n────────\n"},
        "item": {"block_prefix": "• "}, "enumeration": {"block_prefix": ". "},
        "task": {"ticked": "[✓] ", "unticked": "[ ] "},
        "link": {"color": S.url, "underline": True}, "link_text": {"color": S.link, "bold": True},
        "image": {"color": ANSI[5], "underline": True}, "image_text": {"color": S.muted, "format": "Image: {{.text}} →"},
        "code": {"prefix": " ", "suffix": " ", "color": S.string, "background_color": S.raised},
        "code_block": {"color": S.text, "margin": 2, "chroma": {
            "text": {"color": S.text}, "error": {"color": S.error},
            "comment": {"color": S.comment, "italic": True}, "comment_preproc": {"color": S.keyword},
            "keyword": {"color": S.keyword}, "keyword_reserved": {"color": S.keyword},
            "keyword_namespace": {"color": S.keyword}, "keyword_type": {"color": S.type},
            "operator": {"color": S.operator}, "punctuation": {"color": S.operator},
            "name": {"color": S.text}, "name_builtin": {"color": S.function}, "name_tag": {"color": S.keyword},
            "name_attribute": {"color": S.type}, "name_class": {"color": S.type, "bold": True},
            "name_constant": {"color": S.constant}, "name_decorator": {"color": S.escape},
            "name_function": {"color": S.function}, "name_other": {"color": S.text},
            "literal_number": {"color": S.number}, "literal_string": {"color": S.string},
            "literal_string_escape": {"color": S.escape},
            "generic_deleted": {"color": S.deleted}, "generic_inserted": {"color": S.added},
            "generic_emph": {"italic": True}, "generic_strong": {"bold": True},
            "generic_subheading": {"color": S.muted}, "background": {"background_color": S.surface}}},
        "table": {}, "definition_list": {}, "definition_term": {},
        "definition_description": {"block_prefix": "\n🠶 "}, "html_block": {}, "html_span": {},
    }
    write("glow/frost.json", json.dumps(style, indent=2))


# ── cava / cmus / newsboat / git ─────────────────────────────────────────────
def misc():
    S = P
    write("cava/config", f"""; Frost for cava ({HEAD}).
; Only the colours: every other setting keeps cava's default.
[color]
background = default
foreground = '{S.red}'
gradient = 1
gradient_count = 3
gradient_color_1 = '{S.deep}'
gradient_color_2 = '{S.red}'
gradient_color_3 = '#ff8aa0'
""")
    raised, surface, deep = xterm256(S.raised), xterm256(S.surface), xterm256(S.deep)
    cm = {
        "color_cmdline_bg": "default", "color_cmdline_fg": "default", "color_error": 9, "color_info": 3,
        "color_separator": 8, "color_statusline_bg": raised, "color_statusline_fg": 7,
        "color_titleline_bg": 1, "color_titleline_fg": 15, "color_win_bg": "default", "color_win_cur": 1,
        "color_win_cur_sel_bg": 1, "color_win_cur_sel_fg": 15, "color_win_dir": 1, "color_win_fg": 7,
        "color_win_inactive_cur_sel_bg": raised, "color_win_inactive_cur_sel_fg": 1,
        "color_win_inactive_sel_bg": raised, "color_win_inactive_sel_fg": 7,
        "color_win_sel_bg": deep, "color_win_sel_fg": 15, "color_win_title_bg": surface, "color_win_title_fg": 1,
    }
    write("cmus/frost.theme", f"# Frost for cmus ({HEAD})\n" + "".join(f"set {k}={v}\n" for k, v in cm.items()))
    write("newsboat/frost", f"""# Frost for newsboat ({HEAD})
color background          default   default
color listnormal          color7    default
color listnormal_unread   color15   default   bold
color listfocus           color15   color1    bold
color listfocus_unread    color15   color1    bold
color info                color15   color{raised} bold
color article             color7    default
color hint-key            color1    default   bold
color hint-keys-delimiter color8    default
color hint-separator      color8    default
color hint-description    color7    default
highlight article "^(Feed|Title|Author|Link|Date):" color1 default bold
highlight article "https?://[^ ]+" color9 default underline
""")
    write("git/git.conf", f"""# Frost colours for git ({HEAD}).
# Pulled in by `include.path` in ~/.gitconfig; revert removes that include.
[color]
	ui = auto
[color "branch"]
	current = "{S.red}" bold
	local = "{S.text}"
	remote = "{S.muted}"
	upstream = "{S.soft}"
[color "diff"]
	meta = "{S.muted}" bold
	frag = "{S.red}"
	func = "{S.function}"
	old = "{S.deleted}"
	new = "{S.added}"
	commit = "{S.warn}"
	whitespace = "{S.red}" reverse
[color "status"]
	header = "{S.muted}"
	branch = "{S.red}" bold
	added = "{S.added}"
	changed = "{S.changed}"
	untracked = "{S.link}"
	unmerged = "{S.error}" bold
[color "decorate"]
	HEAD = "{S.red}" bold
	branch = "{S.text}" bold
	remoteBranch = "{S.muted}"
	tag = "{S.warn}"
	stash = "{S.property}"
[color "grep"]
	match = "{S.red}" bold
	filename = "{S.muted}"
	lineNumber = "{S.dim}"
""")


# ── terminal wallpaper (optional, --image) ───────────────────────────────────
def wallpaper():
    try:
        from PIL import Image, ImageFilter
    except ImportError:
        print("  (no PIL: skipping the terminal wallpaper)")
        return
    W, H = 1920, 1080
    base = Image.new("RGB", (W, H), rgb(P.obsidian))
    glow_ = Image.new("RGB", (W // 8, H // 8), rgb(P.obsidian))
    px = glow_.load()
    gw, gh = glow_.size
    red, ob = rgb(P.red), rgb(P.obsidian)
    for y in range(gh):
        for x in range(gw):
            # one soft red glow low on the right, a fainter one top left
            d1 = ((x - gw * 0.82) / (gw * 0.55)) ** 2 + ((y - gh * 0.95) / (gh * 0.7)) ** 2
            d2 = ((x - gw * 0.1) / (gw * 0.4)) ** 2 + ((y - gh * 0.05) / (gh * 0.5)) ** 2
            t = max(0.0, 1 - d1) ** 2 * 0.16 + max(0.0, 1 - d2) ** 2 * 0.05
            px[x, y] = tuple(round(o + (r - o) * t) for o, r in zip(ob, red))
    base = glow_.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(24))
    grain = Image.effect_noise((W, H), 10).convert("L")
    base = Image.blend(base, Image.merge("RGB", (grain, grain, grain)), 0.025)
    (OUT / "wallpaper").mkdir(parents=True, exist_ok=True)
    base.save(OUT / "wallpaper" / "terminal-bg.png", optimize=True)


def main():
    for step in (kitty, konsole, zellij, vim, bat, dircolors, shell, lsd, eza, tuis, monitors, files, glow, misc, wallpaper):
        step()
    print(f"Frost terminal themes built into {OUT.relative_to(REPO)}/")


if __name__ == "__main__":
    main()
