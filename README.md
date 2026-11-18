# Frost

A light, glassmorphic look for KDE Plasma 6 (Wayland), plus **Obsidian Glass**:
a set of native Plasma desktop widgets.

## What's here

| Path | What it does |
|---|---|
| `build.py` | Generates the theme: Frost Dark/Light colour schemes (red accent `#F21D43`), the glass Plasma theme, Kvantum app styles, window decorations and global themes, into `build/` |
| `install.sh [dark\|light]` | Builds and applies the theme for your user (fonts, effects, panels). Backs up your previous look the first time |
| `revert.sh` | Restores the look you had before Frost |
| `system-install.sh` | **sudo.** Installs Rufscript / Inter / JetBrains Mono and the Frost login screen (SDDM). `--undo` removes the login theme |
| `sddm/frost/` | The login screen theme |
| `widgets/` | The Obsidian Glass widgets (QML plasmoids) and `install-widgets.sh` |
| `widgets/shared/` | Shared design tokens (`Style.qml`) and the glass card, copied into every widget at install |
| `desktop.sh` | Places the widgets on the desktop (two columns + a bottom-centre media pill) |

## Widgets

- **Chronos**: day, date, time with seconds, greeting, 24-hour timeline, layout profile chips (Default / Focus / Monitoring / Minimal). Click the time for 12/24-hour.
- **System Observatory**: CPU, RAM, GPU, disk and a 60-second network graph (from KDE's ksystemstats).
- **Weather Intelligence**: Open-Meteo, no account. City in the widget settings.
- **Device Ecosystem**: laptop network, KDE Connect phone (battery, ring, send file), Tailscale peers.
- **Focus**: Pomodoro with your own projects (click the project name to add, pick or remove), daily stats, optional Do Not Disturb.
- **Calendar & Agenda**: Monday-first, holidays, local events, iCal feeds (Google "secret address") in the widget settings.
- **Quick Controls**: volume / mic / brightness sliders and pills for Wi-Fi, Bluetooth, Tailscale, DND, Night Light, Power.
- **Media**: "now playing" pill for any MPRIS player; hidden when nothing plays.

## Change and reinstall

```bash
widgets/install-widgets.sh   # after editing a widget
./desktop.sh                 # re-apply the layout
./install.sh dark            # after editing build.py
```
