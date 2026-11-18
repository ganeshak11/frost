#!/usr/bin/env bash
# Build and install the Frost desktop widgets (Plasma 6 plasmoids).
# Each widget gets its own copy of the shared Obsidian glass style.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/.build"; rm -rf "$OUT"; mkdir -p "$OUT"
for w in "$HERE"/org.frost.*; do
  id=$(basename "$w")
  cp -r "$w" "$OUT/$id"
  cp "$HERE"/shared/*.qml "$OUT/$id/contents/ui/"
  # every widget gets a General/hidden flag, used by the layout profiles
  python3 - "$OUT/$id/contents/config/main.xml" <<'PY'
import os, sys
p = sys.argv[1]
entry = '    <entry name="hidden" type="Bool"><default>false</default></entry>\n'
if not os.path.exists(p):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0">\n'
                       '  <kcfgfile name=""/>\n  <group name="General">\n' + entry + '  </group>\n</kcfg>\n')
else:
    s = open(p).read()
    if 'name="hidden"' not in s:
        s = s.replace('<group name="General">\n', '<group name="General">\n' + entry, 1)
        open(p, "w").write(s)
PY
  kpackagetool6 -t Plasma/Applet -u "$OUT/$id" >/dev/null 2>&1 \
    || kpackagetool6 -t Plasma/Applet -i "$OUT/$id" >/dev/null 2>&1
  echo "installed $id"
done
