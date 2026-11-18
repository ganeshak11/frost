# Frost

A light, glassmorphic look for KDE Plasma 6 (Wayland), plus **Obsidian Glass**:
a set of native Plasma desktop widgets, a Mac-style dock and a Dynamic Island.

## What's here

| Path | What it does |
|---|---|
| `build.py` | Generates the theme: Frost Dark/Light colour schemes (red accent `#F21D43`), the glass Plasma theme (including the dock's glass bar, drawn by the bottom panel), Kvantum app styles, window decorations and global themes, into `build/` |
| `install.sh [dark\|light]` | Builds and applies the theme for your user (fonts, effects, panels). Backs up your previous look the first time |
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

## Dock and Dynamic Island

- **Dock** (bottom, hides until you push the pointer to the bottom edge): one glass bar with your apps (`org.frost.dock`) and the clipboard. There is no system tray or app menu: use KRunner (Alt+Space) to launch other apps, Quick Controls for Wi-Fi / Bluetooth / volume. Running dots (red = active app), gentle magnification, a small bounce while an app starts, a pulsing ring when one wants attention. Click to open / focus, click the active app to minimise, middle-click for a new window, right-click for New Window / Keep in Dock / Minimise / Maximise / Close, press and hold then drag to reorder. Icon size and magnification are in the widget's config (`iconSize`, `magnification`).
- **Dynamic Island** (`org.frost.island`, top centre; windows go under it): a black pill that shows what's live and morphs with a spring:
  - idle: the time, a green bolt while charging, an orange dot while an app uses the microphone, a red dot for unread notifications
  - music (any MPRIS player): artwork and live beat bars; a file transfer: progress ring and percentage; the Focus timer: ring and countdown. With two at once the second sits in a small bubble beside the pill
  - banners: notifications (click to open, hover to keep), transfer done / failed, charger in / out, low battery, Bluetooth device connected / disconnected, Do Not Disturb on / off
  - click the pill (or press **Meta+Alt+I**) to expand it: full player, big focus timer, transfer with Pause / Cancel, or the overview with date, battery, devices and your notification history (click one to open it, × to dismiss, Clear all). It closes when the pointer leaves it.
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
