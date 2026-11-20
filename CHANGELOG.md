# Changelog

## Unreleased

- **Screen Time** card and its tracker (`extras/screentime`): time per app and per hour today, top
  apps and the last seven days. Window titles are never recorded.
- **Frost Link** (`extras/link`): this laptop and [Frost Mobile](https://github.com/ganeshak11/frost-mobile),
  the Frost launcher for Android, work as one machine over Tailscale. Only your own Tailscale devices
  are answered. It syncs Frost Notes both ways, screen time, calendars, and each device's battery and
  music.
- Screen Time shows the phone and the laptop together (phone in red, laptop in white).
- Device Ecosystem shows what the phone is playing and its screen time today, and its battery
  through Frost Link when KDE Connect isn't connected.
- Calendar & Agenda shows the phone's events, and its own events reach the phone.
- Frost Notes reloads a note changed on disk (by the sync), unless you are editing it.
- Desktop layout: the right side is one column (Observatory; Agenda beside Quick Controls; Screen
  Time), keeping the middle of the wallpaper clear. `desktop.sh` runs again (a quote in a comment
  had broken it) and finds the desktop even while Plasma reports it on screen -1.

## v1.0.0 (2026-11-19)

The first release of Frost: a dark-only, glassmorphic look for KDE Plasma 6 on Wayland, with the
Obsidian Glass widgets, a Mac-style dock and a Dynamic Island. See the [README](README.md) to install.

### Theme

- Frost Dark colour scheme (red accent `#F21D43`), glass Plasma theme, Kvantum app style, Aurorae
  window frames and a global theme with a login splash.
- Fonts: Rufscript for the interface, JetBrains Mono for code.
- Login screen (SDDM), lock screen, Alt+Tab window switcher, cursors, icons (Papirus-based, red
  folders), Plymouth boot splash and GRUB menu.
- Matching themes for GTK 3 / 4 and libadwaita apps, VS Code / Cursor / Antigravity, Brave / Chrome,
  Firefox and kitty, with optional Better Blur DX for frosted GTK windows.

### Desktop

- **Dynamic Island**: live activities (music with beat bars, recording, timer, stopwatch,
  transfers, downloads, Focus), notification banners and history, an animated charging pill,
  screenshot thumbnails you can drag into any app, and volume / brightness pop-ups.
- **Dock**: pinned and running apps with gentle magnification, running dots and reordering.
- **Spotlight** on Meta: apps, windows, settings, calculator and conversions, plus your `~/dev`
  projects, file search, `> command` and `gh:` GitHub search, with a preview pane.
- **Control Centre** on Meta+Alt+C and the **Shortcut Sheet** on Meta+/.

### Widgets

Chronos, Weather Intelligence, System Observatory, Device Ecosystem (drop files on your phone),
Focus (Pomodoro), Calendar & Agenda (local events, iCal feeds with repeating events, reminders),
Quick Controls (a phone-style control centre) and Music.

### Extras

- **Frost Notes** on Alt+Y: instant global notes with autosave and Markdown editing and preview.
- Do Not Disturb on Meta+Shift+D, a Frost bash prompt, and zram tuning for low-memory laptops.

### Fixed before release

A code audit fixed `install.sh` stopping at step 2, leaked background processes from the sound
helper, and 23 smaller logic bugs. See commit `be483e0` and
[docs/changes-2026-11-19.md](docs/changes-2026-11-19.md).
