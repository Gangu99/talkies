#!/bin/bash
# Puts the TV back the way it was.
#   ./restore.sh                 the TV's own home screen back, Talkies removed
#   ./restore.sh --keep-talkies    the TV's own home screen back, Talkies left installed
#   ./restore.sh --all           also re-enable every debloated app, normal animations, Private DNS off
# Optional last argument: the TV's address (default: TALKIES_TV or the .tv file, see tv-address.sh).
set -uo pipefail
. "$(dirname "$0")/tv-address.sh"
ALL=0; KEEP=0; DEV="$(tv_default)"
for a in "$@"; do
  case "$a" in
    --all) ALL=1 ;;
    --keep-talkies|--keep-glass) KEEP=1 ;;
    *) DEV="$a" ;;
  esac
done
need_tv
adb connect "$DEV" >/dev/null 2>&1 || true
sh() { adb -s "$DEV" shell -n "$@"; }

echo "== Restoring the TV's own home screen"
for p in com.google.android.apps.tv.launcherx com.google.android.tungsten.setupwraith; do
  sh pm path "$p" >/dev/null 2>&1 || continue   # not a Google TV: nothing of Google's to put back
  sh pm enable "$p" >/dev/null 2>&1 || sh cmd package install-existing "$p"
done
if sh pm path com.google.android.apps.tv.launcherx >/dev/null 2>&1; then
  STOCK=com.google.android.apps.tv.launcherx/.home.HomeActivity
else
  # Other TVs: the first home screen that came with the TV (a system app), not Talkies or a fallback page.
  SYSTEM="$(sh pm list packages -s | tr -d '\r')"
  STOCK=""
  for a in $(sh cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tr -d '\r' | grep /); do
    case "$a" in com.techpp.glass/*|*FallbackHome*|*setupwraith*|*Settings*) continue ;; esac
    if printf '%s\n' "$SYSTEM" | grep -qx "package:${a%%/*}"; then STOCK="$a"; break; fi
  done
fi
[ -n "$STOCK" ] && sh cmd package set-home-activity --user 0 "$STOCK" || true
[ "$KEEP" = 1 ] || adb -s "$DEV" uninstall com.techpp.glass >/dev/null 2>&1 || true

if [ "$ALL" = 1 ]; then
  echo "== Re-enabling debloated apps"
  for p in net.oneplus.weather oneplus.smarthome com.oneplus.tv.userguide fusion.android.tv.demo \
           com.heytap.tv.msgboard com.heytap.tv.remotediagnosing com.heytap.mcs com.heytap.olink \
           com.heytap.tv.camera com.coloros.relax.tv com.google.android.play.games \
           com.google.android.feedback com.android.printspooler com.android.dreams.basic; do
    sh pm enable "$p" >/dev/null 2>&1 || sh cmd package install-existing "$p"
  done
  echo "== Normal animation speed, Private DNS off"
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    sh settings put global $k 1.0
  done
  sh settings put global private_dns_mode off
fi
sh input keyevent KEYCODE_HOME
echo "Default home now: $(sh cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)"
