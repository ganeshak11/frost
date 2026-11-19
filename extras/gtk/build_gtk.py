#!/usr/bin/env python3
"""Build the Frost GTK theme (GTK 3 and GTK 4) into extras/gtk/build/Frost.

Starts from Breeze-Dark's stylesheets (the breeze-gtk-theme package), swaps in
Frost's colours (frost-colors.css: what Plasma's GTK colour sync makes of the
FrostDark scheme, red accent #F21D43) and adds a glass layer: translucent
windows, header bars, sidebars and menus, rounded corners. KWin blurs what's
behind them when the Better Blur effect is on (extras/kwin/better-blur.sh).

Also writes libadwaita.css: the same look for libadwaita apps (Loupe, Zenity,
GNOME tools), which ignore GTK themes and only read ~/.config/gtk-4.0/gtk.css.
"""
import re, shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "build" / "Frost"
BREEZE = Path("/usr/share/themes/Breeze-Dark")

colors = dict(re.findall(r"@define-color\s+(\w+)\s+([^;]+);", (HERE / "frost-colors.css").read_text()))

# how see-through each layer is (1 = solid). Text stays fully opaque.
WIN, HEAD, VIEW, SIDE, MENU = 0.80, 0.62, 0.72, 0.40, 0.90

GLASS3 = f"""
/* ---------------------------------------------------------------- Frost glass */
window.background, window.background.csd, .background {{ background-color: alpha(@theme_bg_color_breeze, {WIN}); }}
headerbar, .titlebar, headerbar.titlebar, .titlebar:not(headerbar) {{
  background-color: alpha(@theme_titlebar_background_breeze, {HEAD}); background-image: none; box-shadow: none; }}
headerbar:backdrop, .titlebar:backdrop {{ background-color: alpha(@theme_titlebar_background_breeze, {HEAD}); }}
.view, iconview, textview text, treeview.view, list, row:not(:selected) {{ background-color: alpha(@theme_base_color_breeze, {VIEW}); }}
.sidebar, placessidebar, placessidebar list, stacksidebar, .navigation-sidebar {{ background-color: alpha(@theme_bg_color_breeze, {SIDE}); }}
menu, .menu, .context-menu, popover.background, popover.menu {{ background-color: alpha(@theme_bg_color_breeze, {MENU}); }}
tooltip.background {{ background-color: alpha(@tooltip_background_breeze, {MENU}); }}
decoration, window.csd, window.csd > .titlebar {{ border-radius: 12px 12px 0 0; }}
decoration {{ border-radius: 12px; }}
*:selected, row:selected, .view:selected {{ background-color: @theme_selected_bg_color_breeze; color: #ffffff; }}
"""

GLASS4 = f"""
/* ---------------------------------------------------------------- Frost glass */
window, window.background {{ background-color: alpha(@theme_bg_color_breeze, {WIN}); }}
window.csd, window.csd.background {{ border-radius: 12px; }}
headerbar, .titlebar {{ background-color: alpha(@theme_titlebar_background_breeze, {HEAD}); background-image: none; box-shadow: none; }}
.view, textview > text, gridview, listview, columnview, list {{ background-color: alpha(@theme_base_color_breeze, {VIEW}); }}
.sidebar, .navigation-sidebar, placessidebar {{ background-color: alpha(@theme_bg_color_breeze, {SIDE}); }}
popover > contents, popover.menu > contents, .menu {{ background-color: alpha(@theme_bg_color_breeze, {MENU}); }}
"""

# libadwaita: its own named colours (old @define-color names and the newer CSS variables)
c = colors
ADW_COLORS = {
    "accent_bg_color": "#f21d43", "accent_fg_color": "#ffffff", "accent_color": "#ff4d6d",
    "destructive_bg_color": c["error_color_breeze"], "destructive_color": c["error_color_breeze"],
    "success_color": c["success_color_breeze"], "warning_color": c["warning_color_breeze"], "error_color": c["error_color_breeze"],
    "window_bg_color": f"alpha({c['theme_bg_color_breeze']}, {WIN})", "window_fg_color": c["theme_fg_color_breeze"],
    "view_bg_color": f"alpha({c['theme_base_color_breeze']}, {VIEW})", "view_fg_color": c["theme_text_color_breeze"],
    "headerbar_bg_color": f"alpha({c['theme_titlebar_background_breeze']}, {HEAD})", "headerbar_fg_color": c["theme_fg_color_breeze"],
    "headerbar_backdrop_color": f"alpha({c['theme_titlebar_background_breeze']}, {HEAD})",
    "sidebar_bg_color": f"alpha({c['theme_bg_color_breeze']}, {SIDE})", "sidebar_fg_color": c["theme_fg_color_breeze"],
    "secondary_sidebar_bg_color": f"alpha({c['theme_bg_color_breeze']}, {SIDE})",
    "card_bg_color": "rgba(255, 255, 255, 0.05)", "card_fg_color": c["theme_fg_color_breeze"],
    "popover_bg_color": f"alpha({c['theme_bg_color_breeze']}, {MENU})", "popover_fg_color": c["theme_fg_color_breeze"],
    "dialog_bg_color": f"alpha({c['theme_bg_color_breeze']}, {MENU})", "dialog_fg_color": c["theme_fg_color_breeze"],
}


def recolour(css: str) -> str:
    return re.sub(r"(@define-color\s+(\w+)\s+)([^;]+);",
                  lambda m: f"{m.group(1)}{colors.get(m.group(2), m.group(3))};", css)


def main():
    if not BREEZE.is_dir():
        raise SystemExit("breeze-gtk-theme is not installed (needed as the base)")
    shutil.rmtree(OUT, ignore_errors=True)
    shutil.copytree(BREEZE / "assets", OUT / "assets")
    for ver, glass in (("gtk-3.0", GLASS3), ("gtk-4.0", GLASS4)):
        css = recolour((BREEZE / ver / "gtk.css").read_text())
        (OUT / ver).mkdir(parents=True)
        (OUT / ver / "gtk.css").write_text("/* Frost: Breeze-Dark recoloured, with glass. Built by extras/gtk/build_gtk.py */\n" + css + glass)
        (OUT / ver / "gtk-dark.css").write_text('@import url("gtk.css");\n')
    (OUT / "index.theme").write_text("[Desktop Entry]\nType=X-GNOME-Metatheme\nName=Frost\nComment=Frost dark glass, red accent\n"
                                     "Encoding=UTF-8\n\n[X-GNOME-Metatheme]\nGtkTheme=Frost\nIconTheme=Frost\nCursorTheme=Frost-cursors\n")
    adw = "/* Frost for libadwaita apps (between the FROST markers; written by extras/gtk/install.sh) */\n"
    adw += "".join(f"@define-color {k} {v};\n" for k, v in ADW_COLORS.items())
    adw += ":root {\n" + "".join(f"  --{k.replace('_', '-')}: {v};\n" for k, v in ADW_COLORS.items()) + "}\n"
    (HERE / "build" / "libadwaita.css").write_text(adw)
    print(f"built {OUT}")


if __name__ == "__main__":
    main()
