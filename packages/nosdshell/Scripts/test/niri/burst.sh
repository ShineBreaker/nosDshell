#!/usr/bin/env bash
# Capture N consecutive frames into OUTDIR as <prefix>-NNN.png.
#
# Usage:  Scripts/test/niri/burst.sh <outdir> <prefix> [count]
#
# Each frame goes through the same new-file detection as shot.sh, so a burst
# that outlives one wall-clock second cannot overwrite itself. niri's
# screenshot round-trip is ~100-150 ms, i.e. ~7 fps effective rate — frame
# spacing is bounded by the compositor, not by a sleep.
set -uo pipefail
. "$(dirname "$0")/env.sh"

OUT="${1:?usage: burst.sh <outdir> <prefix> [count]}"
PREFIX="${2:?usage: burst.sh <outdir> <prefix> [count]}"
COUNT="${3:-10}"
SRC="$ISO/shots/incoming"
mkdir -p "$OUT" "$SRC"
[ -n "$(niri_socket)" ] || { echo "FAIL no niri socket" >&2; exit 1; }

ok=0
for i in $(seq 1 "$COUNT"); do
  target="$OUT/$PREFIX-$(printf '%03d' "$i").png"
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
    mv -f "$got" "$target" && ok=$((ok+1))
  else
    echo "frame $i: no new file" >&2
    break
  fi
done
echo "$ok/$COUNT frames -> $OUT" >&2
