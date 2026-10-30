#!/usr/bin/env bash
# Capture the motion of shell surfaces as filmstrips, curves and metrics.
#
# Usage: Scripts/test/motion.sh <out-name> [--slow N] [--settings F.json] [--scenes a,b]
#
# Runs verify.sh's motion-* scenes with every duration stretched N times
# (default 10: general.animationSpeed = 1/N), so back-to-back grim captures
# (~40-80 ms each under software rendering) sample a 200 ms animation 25+
# times. Each scene writes, per burst, under $NOSD_VERIFY_DIR/shots/<out-name>/:
#   <scene>-<phase>/filmstrip.png  10 frames from trigger to settle, labelled
#                                  with real-speed milliseconds
#   <scene>-<phase>/curve.png      pixel progress and changed-area size
#   <scene>-<phase>/metrics.json   settle_ms, t50_ms, bbox_overshoot, monotonic
# and motion-summary.txt with one line per burst. Times are converted back
# to real speed, so settle_ms is directly comparable with the Style.motion*
# tokens; capture latency makes it read up to ~one frame interval late.
#
# Default scenes: motion-popup motion-cc motion-launcher motion-osd
# motion-bubble motion-toast motion-press motion-switch.
# NOSD_MOTION_KEEP=1 keeps the raw frames.
#
# Before/after comparison: run once on the base commit (git worktree) and
# once on the change, then put the filmstrips side by side:
#   Scripts/test/motion-compare.sh <before-dir> <after-dir> <out.png>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_NAME=""; SLOW=10; USER_SETTINGS=""; SCENES="motion-popup,motion-cc,motion-launcher,motion-osd,motion-bubble,motion-toast,motion-press,motion-switch"
while [ $# -gt 0 ]; do
  case "$1" in
    --slow) SLOW="$2"; shift 2 ;;
    --settings) USER_SETTINGS="$(readlink -f "$2")"; shift 2 ;;
    --scenes) SCENES="$2"; shift 2 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) [ -z "$OUT_NAME" ] && OUT_NAME="$1" || { echo "unknown arg: $1" >&2; exit 2; }; shift ;;
  esac
done
[ -n "$OUT_NAME" ] || { echo "usage: motion.sh <out-name> [--slow N] [--settings F.json] [--scenes a,b]" >&2; exit 2; }
[[ "$SLOW" =~ ^[0-9]+$ ]] && [ "$SLOW" -ge 1 ] && [ "$SLOW" -le 20 ] || { echo "--slow must be an integer 1..20 (animationSpeed floor is 0.05)" >&2; exit 2; }

WORK="${NOSD_VERIFY_DIR:-/tmp/nosd-verify}"
mkdir -p "$WORK"
SEED="$WORK/motion-seed-$OUT_NAME.json"
# The OSD auto-hide and the notification timeout are plain delays, not
# animations, so they are not stretched; lengthen them so the stretched enter
# settles before the exit starts. The parked test windows would sit inside
# the capture regions, so they stay off unless asked for.
python3 - "$SEED" "$SLOW" "$USER_SETTINGS" <<'PYEOF'
import json, sys
out, slow, user = sys.argv[1], int(sys.argv[2]), sys.argv[3]
def merge(a, b):
    for k, v in b.items():
        a[k] = merge(a.get(k, {}), v) if isinstance(v, dict) and isinstance(a.get(k), dict) else v
    return a
seed = {"general": {"animationSpeed": round(1.0 / slow, 4)}, "osd": {"autoHideMs": 8000},
        "notifications": {"normalUrgencyDuration": 60}}
if user:
    seed = merge(seed, json.load(open(user)))
json.dump(seed, open(out, "w"))
PYEOF

NOSD_SPAWN_WINDOWS="${NOSD_SPAWN_WINDOWS:-0}" NOSD_MOTION_SLOW="$SLOW" "$SCRIPT_DIR/verify.sh" "$OUT_NAME" --settings "$SEED" --scenes "$SCENES"
STATUS=$?
SUMMARY="$WORK/shots/$OUT_NAME/motion-summary.txt"
: > "$SUMMARY"
for m in "$WORK/shots/$OUT_NAME"/*/metrics.json; do
  [ -f "$m" ] || continue
  printf '%-24s %s\n' "$(basename "$(dirname "$m")")" "$(tr -d '\n ' < "$m")" >> "$SUMMARY"
done
echo "================ motion summary ($SUMMARY) ================"
cat "$SUMMARY"
exit "$STATUS"
