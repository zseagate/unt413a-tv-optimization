#!/usr/bin/env bash
# Undo the changes made by this project.
# usage: bash scripts/rollback.sh [BOX_IP]
set -uo pipefail
IP=${1:-192.168.1.50}
ADB=${ADB:-adb}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ORIG="$HERE/originals"

"$ADB" connect "$IP:5555" >/dev/null 2>&1 || true

PKGS="tv.icntv.vendor tv.cmcc.vendor com.amt.networkService com.cmcc.mid.softdetector
com.um.checkdatasize com.um.networkstatus com.dangbei.tvlauncher
com.android.dreams.basic com.android.dreams.phototable com.android.wallpaper.livepicker
com.android.wallpapercropper com.android.wallpaperbackup"

echo "1) re-enable the 12 preinstalled packages ..."
for p in $PKGS; do
  "$ADB" shell pm enable --user 0 "$p" >/dev/null 2>&1 && echo "  $p"
done

echo "2) reset background app-ops for third-party apps ..."
for p in $("$ADB" shell pm list packages -3 | sed 's/package://' | tr -d '\r'); do
  "$ADB" shell cmd appops set "$p" RUN_IN_BACKGROUND default >/dev/null 2>&1 || true
  "$ADB" shell cmd appops set "$p" RUN_ANY_IN_BACKGROUND default >/dev/null 2>&1 || true
done

echo "3) restore original system scripts ..."
if [ -f "$ORIG/startthirdservice.sh" ]; then
  "$ADB" shell 'mount -o remount,rw /system'
  "$ADB" push "$ORIG/SMI_RAC_TDAT16M30S.sh" /system/etc/SMI_RAC_TDAT16M30S.sh
  "$ADB" push "$ORIG/startthirdservice.sh"  /system/bin/startthirdservice.sh
  "$ADB" push "$ORIG/startstbagent.sh"      /system/bin/startstbagent.sh
  "$ADB" shell 'chmod 755 /system/etc/SMI_RAC_TDAT16M30S.sh /system/bin/startthirdservice.sh /system/bin/startstbagent.sh; sync; mount -o remount,ro /system'
else
  echo "  originals/ not found, skipped (restore them from your own backup)"
fi

echo "4) remove firewall rules for 6800/7777 ..."
"$ADB" shell 'for i in eth0 wlan0; do for p in 6800 7777; do while iptables -D INPUT -i $i -p tcp --dport $p -j DROP 2>/dev/null; do :; done; done; done' || true

echo "5) switch Home back to the stock launcher (if present) ..."
"$ADB" shell 'pm enable --user 0 com.dangbei.tvlauncher 2>/dev/null; cmd package set-home-activity --user 0 com.dangbei.tvlauncher/.activity.SplashActivity 2>/dev/null' || true

echo "6) optional: uninstall the CleanYourTV launcher ..."
read -r -p "uninstall com.gathin.tvhome? [y/N] " ans
case "$ans" in
  y|Y) "$ADB" shell pm uninstall com.gathin.tvhome ;;
  *) echo "  kept" ;;
esac

echo "rollback done. Reboot the box."
