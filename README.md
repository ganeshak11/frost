# Frost

A dark-only, glassmorphic look for KDE Plasma 6 (Wayland), plus **Obsidian Glass**:
a set of native Plasma desktop widgets, a Mac-style dock and a Dynamic Island.

## What's here

| Path | What it does |
|---|---|
| `build.py` | Generates the theme: the Frost Dark colour scheme (red accent `#F21D43`), the glass Plasma theme (including the dock's glass bar, drawn by the bottom panel), Kvantum app styles, window decorations and global themes, into `build/` |
| `install.sh` | Builds and applies the theme for your user (fonts, effects, panels). Backs up your previous look the first time |
| `revert.sh` | Restores the look you had before Frost |
| `system-install.sh` | **sudo.** Installs Rufscript / Inter / JetBrains Mono and the Frost login screen (SDDM). `--undo` removes the login theme |
| `sddm/frost/` | The login screen theme |
| `widgets/` | The Obsidian Glass widgets (QML plasmoids) and `install-widgets.sh` |
| `widgets/shared/` | Shared design tokens (`Style.qml`) and the glass card, copied into every widget at install |
| `desktop.sh` | Sets up the whole desktop: the island at the top, the dock at the bottom (removes other panels on the main screen, with their tray and app menu) and the cards in a bento layout around the portrait. Backs up the panel config first, restarts plasmashell once |
| `splash/` | Login splash (day, date, red progress line), packaged into the global themes |
| `extras/kitty/` | Kitty colours, glass and tabs; included from `~/.config/kitty/kitty.conf` |
| `extras/firefox/` | `userChrome.css` / `userContent.css` + `user.js` for the Firefox profile |
| `extras/system-boot.sh` | **sudo.** Plymouth boot splash and GRUB menu theme (`plymouth/`, `grub/`). `--undo` restores the previous ones |
| `extras/cursors/` | Frost cursor theme: `build_cursors.py` draws 23 cursors (dark body, white outline, red badges, animated red spinner) as Plasma SVG cursors + Xcursor files with 81 alias names, inheriting Breeze for the rest. `install.sh` installs to `~/.icons/Frost-cursors` and applies it; `--revert` goes back |
| `extras/icons/` | Frost icon theme: `build_icons.py` makes Frost from Papirus-Dark with ~1,400 folder icons recoloured to the Frost red; everything else is inherited from Papirus. `install.sh` installs it (also run by the main `install.sh`) |
| `extras/gtk/` | Frost for GTK 3 / GTK 4 apps: `build_gtk.py` recolours Breeze-Dark with the Frost palette and adds glass (translucent windows, header bars, sidebars, menus; rounded). `install.sh` puts it in `~/.themes/Frost`, selects it, adds the colours for libadwaita apps to `~/.config/gtk-4.0/gtk.css` and points Flatpak apps at it; `--revert` goes back |
| `extras/vscode/` | **Frost Dark** editor theme for VS Code, Cursor and Antigravity (`build_theme.py` makes a `.vsix`). `install.sh` installs it in each editor and selects it; colour overrides you had for every theme are kept, under your previous theme's name. `--revert` switches back |
| `extras/chromium/` | Frost Dark browser theme for Brave / Chrome. `install.sh` copies it to `~/.local/share/frost/chromium-theme` and prints the three clicks to load it (Chromium only takes local themes through its own page) |
| `extras/notes/` | **Frost Notes**: a global scratchpad on **Meta+Alt+N** (same key or Esc hides it). A small background process keeps the window ready, so it appears instantly, centred, on Frost glass. Search, many notes, autosave 0.4 s after you stop typing; each note is a plain `.md` in `~/.local/share/frost-notes/` (deleted ones go to its `trash/`). `install.sh` sets up the command, shortcut, autostart and KWin rule; `--remove` undoes it |
| `extras/kwin/` | `install.sh`: the Frost Alt+Tab window switcher. `better-blur.sh`: **sudo.** Builds and switches on [Better Blur DX](https://github.com/xarblu/kwin-effects-better-blur-dx), so GTK apps and their menus get real frosted glass; `--rebuild` after a Plasma update, `--off` for KWin's own blur |
| `previews/` | Screenshots used as the Global Theme previews in System Settings |

## Dock and Dynamic Island

- **Dock** (bottom, hides until you push the pointer to the bottom edge): one glass bar with your apps (`org.frost.dock`) and the clipboard. There is no system tray or app menu: use KRunner (Alt+Space) to launch other apps, Quick Controls for Wi-Fi / Bluetooth / volume. Running dots (red = active app), gentle magnification, a small bounce while an app starts, a pulsing ring when one wants attention. Click to open / focus, click the active app to minimise, middle-click for a new window, right-click for New Window / Keep in Dock / Minimise / Maximise / Close, press and hold then drag to reorder. Icon size and magnification are in the widget's config (`iconSize`, `magnification`).
- **Dynamic Island** (`org.frost.island`, top centre; windows go under it): a black pill that shows what's live and morphs with a spring:
  - idle: the time, a green bolt while charging, a green dot while an app uses the camera, an orange dot while one uses the microphone, a red dot for unread notifications
  - live activities, most important first: screen recording or sharing (pulsing red dot + elapsed time), music (any MPRIS player: artwork and live beat bars), your island timer (yellow ring + countdown) or stopwatch, a file transfer (Dolphin / KIO: ring and percentage), a browser download (Firefox `.part` / Brave and Chrome `.crdownload` files in ~/Downloads: name and size), the Focus timer. With two at once the second sits in a small bubble beside the pill; camera / mic dots stay visible in the corner
  - banners: notifications (click to open, hover to keep), transfer done / failed, download finished (click to open the file) or stopped, timer done (with a sound, even in Do Not Disturb), rain expected within the hour at the Weather widget's place (Open-Meteo, at most every 2 hours), charger in / out, low battery, Bluetooth device connected / disconnected, Do Not Disturb on / off
  - click the pill (or press **Meta+Alt+I**) to expand it: full player, big focus timer, transfer with Pause / Cancel, timer with Pause / +1 min / Cancel, stopwatch with Pause / Reset, recording time, download with speed, or the overview with date, battery, devices, timer chips (1 / 5 / 10 / 25 min, a custom one you set by scrolling, Stopwatch) and your notification history (click one to open it, × to dismiss, Clear all). It closes when the pointer leaves it.
- **Spotlight** (`org.frost.spotlight`): the **Meta** key on its own opens a centred black search bar using Plasma's own search runners: apps, open windows, System Settings pages, calculator (`= 1250 * 1.18`), unit and currency conversion (`10 km in miles`), recent files and places, web shortcuts (`gg:` Google, `dd:` DuckDuckGo, `yt:` YouTube). Results are grouped; Up / Down to move, Enter to open, Shift+Enter for an extra action, Tab to jump to the next group, Esc to close. It's a 1 px widget beside the island in the top bar, registered as the app launcher (that's how Meta reaches it). KRunner keeps Alt+Space, Alt+F2 and Meta+Space.
- **Do Not Disturb**: **Meta+Shift+D** toggles it from anywhere (`extras/shell/frost-dnd`; `extras/shell/install-shortcuts.sh` sets up the key). The island shows On / Off.
- **Clipboard**: the dock's clipboard icon runs Klipper, so copied text outlives the app it came from. **Meta+V** shows the history at the pointer.
- The island is the notification centre: with no system tray there's no Plasma bell and no popups of its own. If you add a tray back, untick its Notifications item (or you'll see every notification twice).

## Widgets

- **Chronos**: day, date, time with seconds, greeting, 24-hour timeline, layout profile chips (Default / Focus / Monitoring / Minimal). Click the time for 12/24-hour.
- **System Observatory**: CPU, RAM, GPU, disk and a 60-second network graph (from KDE's ksystemstats).
- **Weather Intelligence**: Open-Meteo, no account. City in the widget settings.
- **Device Ecosystem**: laptop network, KDE Connect phone (battery, ring, send file), Tailscale peers.
- **Focus**: Pomodoro with your own projects (click the project name to add, pick or remove), daily stats, optional Do Not Disturb.
- **Calendar & Agenda**: Monday-first month grid with a coloured dot per kind of event, and what's coming up. Click a day, press **+** and type `09:30 Gym`, `Gym`, or `05/03/2004 Mom's bday` (another date, e.g. a birth date, so ages are counted). Pick Once / Weekly / Monthly / Yearly and a colour (birthday pink, anniversary purple, important red); "bday" / "anniversary" pick yearly and the colour for you. Right-click one of your events to delete it. Feeds in the widget settings, one per line: `link #colour Name +Word`: Indian holidays, Real Madrid fixtures (gold) and F1 races, qualifying and sprints (orange) by default; add your Google Calendar's secret iCal address. Reminders appear in the Dynamic Island 10 minutes before and at the start of timed events, at 9:00 for all-day ones (switch off in the settings).
- **Quick Controls**: volume / mic / brightness sliders and pills for Wi-Fi, Bluetooth, Tailscale, DND, Night Light, Power.
- **Music**: artwork (thumbnail only for videos), live beat bars from `cava` (`code/beats.py`, local only, stops when idle), progress and controls. Appears only while something plays, hides 30 s after pausing.

## Change and reinstall

```bash
widgets/install-widgets.sh   # after editing a widget (plasmashell loads it on its next start)
./desktop.sh                 # re-apply bars and layout (restarts plasmashell once)
./install.sh dark            # after editing build.py
```
