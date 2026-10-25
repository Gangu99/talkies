#!/bin/bash
# Switches the TV's home screen.
#   ./switch-home.sh glass        Talkies
#   ./switch-home.sh projectivy   Projectivy Launcher
# Optional second argument: the TV's address (default: TALKIES_TV or the .tv file, see tv-address.sh).
set -euo pipefail
. "$(dirname "$0")/tv-address.sh"
DEV="${2:-$(tv_default)}"; need_tv
case "${1:-}" in
  glass)      HOME_ACT=com.techpp.glass/.HomeActivity ;;
  projectivy) HOME_ACT=com.spocky.projengmenu/.ui.home.MainActivity ;;
  *) echo "Usage: $0 glass|projectivy [tv-ip:port]"; exit 1 ;;
esac
adb connect "$DEV" >/dev/null 2>&1 || true
adb -s "$DEV" shell -n cmd package set-home-activity --user 0 "$HOME_ACT"
adb -s "$DEV" shell -n input keyevent KEYCODE_HOME
echo "Home screen: $(adb -s "$DEV" shell -n cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)"
