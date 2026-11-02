#!/usr/bin/env bash
# Back up the files this project replaces, before changing anything.
# usage: bash scripts/backup-originals.sh [BOX_IP]
set -euo pipefail
IP=${1:-192.168.1.50}
ADB=${ADB:-adb}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/originals"

mkdir -p "$OUT"
"$ADB" connect "$IP:5555" >/dev/null 2>&1 || true

echo "pulling system scripts ..."
"$ADB" pull /system/etc/SMI_RAC_TDAT16M30S.sh "$OUT/SMI_RAC_TDAT16M30S.sh"
"$ADB" pull /system/bin/startthirdservice.sh     "$OUT/startthirdservice.sh"
"$ADB" pull /system/bin/startstbagent.sh         "$OUT/startstbagent.sh"

echo "saving package lists ..."
"$ADB" shell pm list packages     > "$OUT/packages.txt"
"$ADB" shell pm list packages -s  > "$OUT/packages-system.txt"
"$ADB" shell pm list packages -3  > "$OUT/packages-third.txt"
"$ADB" shell pm list packages -d  > "$OUT/packages-disabled.txt"
"$ADB" shell getprop              > "$OUT/getprop.txt"
"$ADB" shell settings list global  > "$OUT/settings-global.txt" 2>/dev/null || true
"$ADB" shell settings list secure  > "$OUT/settings-secure.txt" 2>/dev/null || true

echo "saved to $OUT"
