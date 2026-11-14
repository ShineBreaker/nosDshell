#!/usr/bin/env bash
# Take a single screenshot of the nested output and move it to DEST.
#
# Usage:  Scripts/test/niri/shot.sh <dest.png>
#
# niri's screenshot-path only resolves to one-second precision, so every shot
# lands in $ISO/shots/incoming with a same-second name — this script snapshots
# the dir contents first, then waits for a file that is NEW, and moves it out
# immediately. That is also what makes burst captures safe.
set -uo pipefail
. "$(dirname "$0")/env.sh"

DEST="${1:?usage: shot.sh <dest.png>}"
SRC="$ISO/shots/incoming"
mkdir -p "$SRC" "$(dirname "$DEST")"
[ -n "$(niri_socket)" ] || { echo "FAIL no niri socket" >&2; exit 1; }

declare -A before=()
for f in "$SRC"/*.png; do [ -f "$f" ] && before["$f"]=1; done

niri_msg action screenshot-screen >/dev/null 2>&1

got=""
for t in $(seq 1 40); do
  for f in "$SRC"/*.png; do
    [ -f "$f" ] || continue
    [ -n "${before[$f]:-}" ] && continue
    sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
    if [ "$sz" -gt 2048 ]; then got="$f"; break; fi
  done
  [ -n "$got" ] && break
  sleep 0.05
done

if [ -n "$got" ]; then
  mv -f "$got" "$DEST"
  echo "ok $DEST ($(stat -c%s "$DEST")B)"
else
  echo "FAIL nothing new in $SRC" >&2
  exit 1
fi
