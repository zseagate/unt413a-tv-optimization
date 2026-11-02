#!/usr/bin/env bash
# Apply the replacement system scripts.
# Run scripts/backup-originals.sh first.
# usage: bash scripts/apply-system.sh [BOX_IP]
set -euo pipefail
IP=${1:-192.168.1.50}
ADB=${ADB:-adb}
HERE="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$HERE/originals/startthirdservice.sh" ] || {
  echo "originals/ not found; run scripts/backup-originals.sh first." >&2
  exit 1
}

"$ADB" connect "$IP:5555" >/dev/null 2>&1 || true

echo "remount /system rw ..."
"$ADB" shell 'mount -o remount,rw /system'

"$ADB" push "$HERE/system/SMI_RAC_TDAT16M30S.sh" /system/etc/SMI_RAC_TDAT16M30S.sh
"$ADB" push "$HERE/system/startthirdservice.sh"  /system/bin/startthirdservice.sh
"$ADB" push "$HERE/system/startstbagent.sh"      /system/bin/startstbagent.sh

"$ADB" shell 'chmod 755 /system/etc/SMI_RAC_TDAT16M30S.sh /system/bin/startthirdservice.sh /system/bin/startstbagent.sh; sync; mount -o remount,ro /system'

echo "done. Reboot the box to apply the boot hook."
