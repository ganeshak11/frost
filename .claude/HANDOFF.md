# Frost: handoff notes (where we stopped)

Project: `~/dev/Personal/frost`. KDE Plasma 6.6 (Wayland), Ubuntu 26.04, 1920x1080, 5.7 GB RAM.
See `README.md` for what each file does. Reinstall widgets with `widgets/install-widgets.sh`,
re-apply bars + desktop layout with `./desktop.sh` (restarts plasmashell once).

## Done and working
- Frost theme (glass Plasma theme, Frost Dark/Light colours, red accent #F21D43, Kvantum, Aurorae
  window frame with buttons on the right, edges stretched), `install.sh` / `revert.sh`.
- Fonts: Rufscript (UI), JetBrains Mono (code). SDDM login theme `sddm/frost` (installed via `system-install.sh`).
- Lock screen: not themeable in Plasma 6 (left stock, uses Rufscript).
- Desktop cards (bento layout, `desktop.sh`): chronos, weather, focus, devices, music, observatory,
  agenda, controls. Shrunk to fit between island and dock (weather/focus 240 h, devices 160, music 272,
  observatory 208, agenda 320, controls 368); screen y 56 .. 984.
- Matching pass: kitty, Firefox, login splash, Plymouth + GRUB, zram tuning (see README).
- **Old top bar and dock replaced** (user's request, 2026-11-18):
  - Top: panel 215 = only `org.frost.island`, centred, fit width, 40 px, windows go below it, opaque
    (no blur box). Global shortcut Meta+Alt+I opens/closes the island.
  - Bottom: panel 71 = org.frost.dock 216 | org.kde.plasma.clipboard 219; auto-hide (user's choice),
    floating, fit, 94 px (24 px clear band + 70 px glass bar drawn by the theme's `south-*` panel
    background), translucent. The user removed kickoff, the system tray and the trash from it at
    23:45 and chose to keep only a clipboard icon (Klipper) added back. No app launcher now.
  - Meta+V = Klipper's "Show Clipboard Items at Mouse Position" (kglobalshortcutsrc, set over
    D-Bus by desktop.sh); the clipboard icon has no shortcut (its popup can't show while the dock hides).
  - The island is the notification centre and JobViewServer (no tray, so no Plasma bell / popups);
    history lives in the island's expanded idle view.
- Verified on screen: banners (queue, sizes), idle overview with history + Clear all, unread dot,
  focus pill + expanded focus view, transfer live activity (fake job via JobViewServer) + Done banner,
  two activities at once (transfer pill + focus bubble), dock bar order and sizes, no grey boxes, cards.
- Commit: everything is still uncommitted (user asked to be asked first).

Backups of the panel config (appletsrc + plasmashellrc) in `~/.local/share/glass-theme/`:
`backup-panels-20261118-223443` (before this task), plus one per `desktop.sh` run.

- Calendar card (org.frost.agenda), 2026-11-19: repeating local events (weekly / monthly / yearly,
  `id` per event, ages / years for yearly ones), tags with colours (birthday #f472b6, anniversary
  #a78bfa, important #F21D43), a "dd/mm/yyyy" or "yyyy-mm-dd" prefix for another date, feed lines
  `link #colour Name +Word` (default feeds: Indian holidays, ics.fixtur.es Real Madrid, Better F1
  Calendar filtered to races / qualifying / sprints), reminders sent with notify-send (so the island
  shows them; sent ids kept in config `reminded`). Logic unit-tested with Node (extracting the JS
  functions from main.qml); the add-event chips and a live reminder were not clicked/seen yet.
  The user still has to add their own birthday and another person's (they'll do it in the card).

## Not verified yet (needs the user's hands or the right moment)
- Dock feel: magnification (1.3, computed from resting positions so it no longer wobbles), drag to
  reorder, right-click menu, the clipboard icon's popup. Meta+V by key press (the action was tested).
- `desktop.sh` after the apps + clipboard rewrite: config part dry-run and JS syntax-checked only.
- Island: clicking the pill (only the shortcut was tested), music view (nothing was playing),
  Pause / Cancel on a real transfer, charger / low battery / Bluetooth / DND banners.

## Possible follow-ups
- Calendar feeds with TZID times (Google calendars) are read as local time, and RRULE repeats in feeds
  are ignored (only the first date shows). The current feeds use UTC times, so they're right.
- Volume / brightness changes as island HUD banners (replacing Plasma's OSD).
- "toggle do not disturb" global shortcut belonged to the removed tray bell; it no longer works.
- `[Containments][8]` in appletsrc is an orphaned Plasma 5 systray containment (unused; harmless).

## Notes / gotchas learned
- Never name QML root properties `data`, `left`, `status`, `focus`, `expanded`, `screen` (clash with
  Item/PlasmoidItem). `expandedChanged` passes a parameter named `expanded`: use `(on) => {}`.
- In an `onXChanged` handler, other bindings that depend on X may not be re-evaluated yet: decide
  from X itself (this broke "transfer finished" detection).
- Inline-component ids: use lowercase (`st`), not `S`.
- Desktop applet sizes saved = preferred size rounded up to 16 px. Card coordinates are relative to
  Plasma's free area, which starts 8 px below the top panel: y = screen y - 48 with the island panel.
- `pkill -f` with a pattern also matches the calling shell; use `pgrep -x name`.
- A removed applet's global shortcut stays registered in kglobalaccel and blocks the key for a new
  one: free it with `qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister
  plasmashell "activate widget N"`. Shortcut keys are set with `setForeignShortcutKeys` (python3-dbus,
  keys as `(ai)` structs, e.g. Meta+V = 0x10000056).
- Without Klipper (the clipboard applet), Wayland copy/paste only works while the source app is open.
- Plasma panel popups inherit the panel opacity mode (opaque panel -> solid popups).
- Quitting plasmashell right after removing panels/applets via evaluateScript can segfault; KCrash
  restarts it at once and races any config edit (lost kickoff + tray once). `desktop.sh` waits 12 s,
  quits with `quit_shell` (retries until it stays down) and checks the config before editing it.
- plasmashell rewrites `AppletOrder` from its live order on exit: write the order while it's stopped.
- Scripting: `hiding` takes none | autohide | dodgewindows | windowsgobelow (the getter reports
  "none" for windowsgobelow; plasmashellrc panelVisibility=3 is right). A brand-new panel ignores
  some setters until its window exists: set them again later. `panel.opacity = ...` does nothing;
  `panelOpacity` in plasmashellrc is read at start (1 opaque, 2 translucent).
- Panel applet padding = theme `thick-hint-*-margin` + 4, capped at (thickness - 22) / 2.
  `floating-hint-*` margins are taken out of the thickness, not added to the window: don't use them.
- Panel blur follows the `mask-*` elements; with none, Plasma blurs the whole panel window (a grey
  box over a black wallpaper). A panel touching a screen edge doesn't draw that edge's border pieces,
  so the island panel's 1 px mask pixels sit in every corner piece.
- `status.py`: configparser strips the outer brackets of section names
  (`Containments][139][Applets][208`), so sub-groups are `sec + "][Configuration][General"`.
- Testing notification / job code standalone: run `plasmawindowed` inside `dbus-run-session` so the
  widget owns org.freedesktop.Notifications and JobViewServer there; plain plasmawindowed can't
  (plasmashell owns them). A fake job: JobViewServer.requestView + JobViewV2.setPercent/terminate,
  from a client that stays connected (python3-dbus); busctl/qdbus jobs end when the caller exits.
