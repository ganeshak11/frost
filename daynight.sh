#!/usr/bin/env bash
# Frost day and night: Frost Light from sunrise, Frost Dark from sunset.
# Switches live (colours, app style, icons, window frames, GTK apps, login
# splash); the Obsidian Glass cards and the dock follow, the island stays black.
#   ./daynight.sh light | dark   switch now (stays until the next sunrise/sunset)
#   ./daynight.sh auto           match the sun at the weather widget's location
#   ./daynight.sh on | off       switch automatically (a systemd user timer that
#                                checks every 10 minutes) / stop doing that
#   ./daynight.sh status
# Apps that are already open keep their Kvantum style until they restart.
set -euo pipefail
CFG=~/.config
STATE=~/.local/state/frost; mkdir -p "$STATE"
kw() { kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }

# where the sun is: the Frost Weather widget's latitude / longitude (Mysuru by default)
location() {
  python3 - "$CFG/plasma-org.kde.plasma.desktop-appletsrc" <<'PY'
import configparser, sys
c = configparser.RawConfigParser(strict=False, interpolation=None); c.optionxform = str
lat, lon = 12.2958, 76.6394
try:
    c.read(sys.argv[1])
    for s in c.sections():
        if c.get(s, "plugin", fallback="") == "org.frost.weather":
            g = s + "][Configuration][General"
            lat = float(c.get(g, "latitude", fallback=lat)); lon = float(c.get(g, "longitude", fallback=lon)); break
except Exception: pass
print(lat, lon)
PY
}

# "light" between today's sunrise and sunset there, else "dark" (NOAA sunrise equation)
sun_mode() {
  python3 - $(location) <<'PY'
import datetime as dt, math, sys
lat, lon = map(float, sys.argv[1:3])
r, d = math.radians, math.degrees
def sun(day, rising):
    n = day.timetuple().tm_yday; lh = lon / 15
    t = n + ((6 if rising else 18) - lh) / 24
    m = 0.9856 * t - 3.289
    l = (m + 1.916 * math.sin(r(m)) + 0.020 * math.sin(r(2 * m)) + 282.634) % 360
    ra = d(math.atan(0.91764 * math.tan(r(l)))) % 360
    ra = (ra + (l // 90) * 90 - (ra // 90) * 90) / 15
    sd = 0.39782 * math.sin(r(l)); cd = math.cos(math.asin(sd))
    ch = (math.cos(r(90.833)) - sd * math.sin(r(lat))) / (cd * math.cos(r(lat)))
    if ch > 1: return None                        # sun never rises today
    if ch < -1: return "always"                   # never sets
    h = (360 - d(math.acos(ch)) if rising else d(math.acos(ch))) / 15
    ut = (h + ra - 0.06571 * t - 6.622 - lh) % 24
    return dt.datetime(day.year, day.month, day.day, tzinfo=dt.timezone.utc) + dt.timedelta(hours=ut)
now = dt.datetime.now(dt.timezone.utc)
day = now.astimezone().date()
rise, sett = sun(day, True), sun(day, False)
if rise == "always": print("light")
elif rise is None: print("dark")
else:
    if sett < rise: sett += dt.timedelta(days=1)  # far east/west of UTC
    print("light" if rise <= now < sett else "dark")
PY
}

current() { [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" = FrostLight ] && echo light || echo dark; }

apply() {
  local m=$1 V; [ "$m" = light ] && V=Light || V=Dark
  local ICONS=Frost; [ "$V" = Light ] && ICONS=Frost-Light
  plasma-apply-colorscheme "Frost$V" >/dev/null 2>&1 || true
  kw Kvantum/kvantum.kvconfig General theme "Frost$V"
  kw kdeglobals Icons Theme "$ICONS"
  /usr/lib/x86_64-linux-gnu/libexec/plasma-changeicons "$ICONS" >/dev/null 2>&1 || true
  kw kwinrc org.kde.kdecoration2 theme "__aurorae__svg__Frost$V"
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  kw ksplashrc KSplash Theme "org.frost.$m"
  kw kdeglobals KDE LookAndFeelPackage "org.frost.$m"     # shown as the active Global Theme
  command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface color-scheme "prefer-$m" || true
  echo "Frost $V"
}

case "${1:-status}" in
  light|dark) apply "$1" ;;
  auto)
    # act only when the sun's mode changes, so a manual switch lasts until the next sunrise / sunset
    want=$(sun_mode); last=$(cat "$STATE/daynight" 2>/dev/null || true)
    if [ "$want" != "$last" ]; then echo "$want" > "$STATE/daynight"; [ "$want" != "$(current)" ] && apply "$want"; fi ;;
  on)
    mkdir -p ~/.local/bin "$CFG/systemd/user"
    install -m 755 "$0" ~/.local/bin/frost-daynight
    cat > "$CFG/systemd/user/frost-daynight.service" <<'EOF'
[Unit]
Description=Frost day/night switch

[Service]
Type=oneshot
ExecStart=%h/.local/bin/frost-daynight auto
EOF
    cat > "$CFG/systemd/user/frost-daynight.timer" <<'EOF'
[Unit]
Description=Frost day/night switch, checked every 10 minutes

[Timer]
OnStartupSec=20s
OnCalendar=*:0/10

[Install]
WantedBy=timers.target
EOF
    rm -f "$STATE/daynight"
    systemctl --user daemon-reload
    systemctl --user enable --now frost-daynight.timer
    "$HOME/.local/bin/frost-daynight" auto
    echo "automatic day/night is on (now: $(current))" ;;
  off)
    systemctl --user disable --now frost-daynight.timer 2>/dev/null || true
    rm -f "$CFG/systemd/user/frost-daynight."{service,timer} ~/.local/bin/frost-daynight "$STATE/daynight"
    systemctl --user daemon-reload
    echo "automatic day/night is off (staying $(current))" ;;
  status)
    echo "now: $(current), by the sun: $(sun_mode) (at $(location | tr ' ' ','))"
    systemctl --user is-enabled frost-daynight.timer >/dev/null 2>&1 && echo "automatic: on" || echo "automatic: off" ;;
  *) echo "usage: $0 light|dark|auto|on|off|status"; exit 1 ;;
esac
