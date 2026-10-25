#!/bin/bash
# Saves your CricketData.org key on the TV for the cricket scores (header line and Cricket row). The key is read without being shown,
# kept in cricket_key.txt next to this script (only you can read it), and never built into the app.
#   ./set-tmdb-key.sh            ask for the key
#   ./set-tmdb-key.sh --remove   delete the key (and the row) from the TV
# Optional last argument: the TV's address (default: TALKIES_TV or the .tv file, see tv-address.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$(dirname "$0")/tv-address.sh"
DEV="$(tv_default)"; REMOVE=0
for a in "$@"; do [ "$a" = "--remove" ] && REMOVE=1 || DEV="$a"; done
need_tv
F=/sdcard/Android/data/com.techpp.glass/files
adb connect "$DEV" >/dev/null 2>&1 || true

if [ "$REMOVE" = 1 ]; then
  adb -s "$DEV" shell -n rm -rf "$F/cricket_key.txt" "$F/cricket"
  rm -f "$HERE/cricket_key.txt"
  echo "Key removed. The scores disappear the next time you press Home."
else
  read -rsp "Paste your CricketData.org API key, then press Return: " KEY; echo
  KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
  [ -n "$KEY" ] || { echo "No key entered."; exit 1; }
  ( umask 077; printf '%s' "$KEY" > "$HERE/cricket_key.txt" )
  adb -s "$DEV" shell -n mkdir -p "$F"
  adb -s "$DEV" push "$HERE/cricket_key.txt" "$F/cricket_key.txt" >/dev/null
  echo "Key saved on the TV. Press Home on the remote; the first scores take a few seconds."
fi
# No force-stop: Talkies rereads the key on its next refresh, and force-stopping it would switch off its
# accessibility service (Android treats that as a crash), which keeps the Home button on Talkies.
adb -s "$DEV" shell -n input keyevent KEYCODE_HOME
