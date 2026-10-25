#!/bin/bash
# Sets the country Talkies uses for picks, cricket and °C/°F, when the TV's own settings say otherwise.
# Normally it follows the TV's time zone (then its language setting), so most people never need this.
#   ./set-region.sh GB          a two-letter country code
#   ./set-region.sh --remove    back to the TV's own settings
# Optional last argument: the TV's address (default: TALKIES_TV or the .tv file, see tv-address.sh).
set -euo pipefail
. "$(dirname "$0")/tv-address.sh"
DEV="${2:-$(tv_default)}"; need_tv
F=/sdcard/Android/data/com.techpp.glass/files/region.txt
adb connect "$DEV" >/dev/null 2>&1 || true
if [ "${1:-}" = "--remove" ]; then
  adb -s "$DEV" shell -n rm -f "$F"
  echo "Talkies follows the TV's settings again."
elif [[ "${1:-}" =~ ^[A-Za-z]{2}$ ]]; then
  adb -s "$DEV" shell -n "echo $(echo "$1" | tr a-z A-Z) > $F"
  echo "Country set to $(echo "$1" | tr a-z A-Z). Picks refresh next time the home screen shows."
else
  echo "Usage: ./set-region.sh XX | --remove"; exit 1
fi
