# Sourced by the scripts here: which TV to talk to. Pass its address as the last argument, set TALKIES_TV, or save it
# once in a .tv file next to the scripts (git ignores it):  echo 192.168.1.20:5555 > .tv
tv_default() {
  if [ -n "${TALKIES_TV:-}" ]; then echo "$TALKIES_TV"
  elif [ -n "${GLASS_TV:-}" ]; then echo "$GLASS_TV"   # the old name still works
  elif [ -f "$(dirname "$0")/.tv" ]; then tr -d ' \r\n' < "$(dirname "$0")/.tv"
  fi
}
need_tv() {
  [ -n "${DEV:-}" ] && return 0
  echo "Which TV? Pass its address (e.g. ./$(basename "$0") 192.168.1.20:5555), set TALKIES_TV, or save it once:"
  echo "  echo 192.168.1.20:5555 > .tv"
  exit 1
}
