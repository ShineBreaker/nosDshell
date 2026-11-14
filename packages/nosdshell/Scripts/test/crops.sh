#!/usr/bin/env bash
# Batch crop a verify.sh screenshot directory for pixel-level comparison.
#
# Usage:
#   Scripts/test/crops.sh <shots-dir> [--position bottom|top|left|right]
#
# Reads $SHOTS_DIR/*.png, writes enlarged crops into <shots-dir>/crops/:
#   <name>-dock.png        full dock strip (1x, whole docked edge)
#   <name>-dock-l/c/r.png  the same strip split left/center/right, 2x
#   <name>-cc.png          right-hand column of control-center*/settings*/cc-*
#                          shots (520 px wide, 1x)
#   osd-*.png              centered overlay: 500x400 above the bottom edge, 1x
#   notification*.png      top-right floating layer: 560x260, 1x
#   toast.png              top-center strip: 700x200, 1x
#
# Geometry matches the 1920x1080 headless sway output used by verify.sh.
# Requires imagemagick only (magick preferred, convert as fallback).
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: crops.sh <shots-dir> [--position POS]" >&2; exit 2; }
SHOTS_DIR="$1"; shift
POSITION="${DOCK_POSITION:-bottom}"
while [ $# -gt 0 ]; do
  case "$1" in
    --position) POSITION="$2"; shift 2 ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -d "$SHOTS_DIR" ] || { echo "not a directory: $SHOTS_DIR" >&2; exit 2; }
SHOTS_DIR=$(readlink -f "$SHOTS_DIR")

if command -v magick >/dev/null 2>&1; then IM="magick"
elif command -v convert >/dev/null 2>&1; then IM="convert"
else echo "imagemagick not found (need magick or convert)" >&2; exit 1; fi
echo "using $IM"

CROPS="$SHOTS_DIR/crops"
mkdir -p "$CROPS"

# dock strip geometry: 1920x1080 canvas, 100 px thick (fashion = iconSize*1.5,
# Commons/Style.qml:467; efficient taskbars are thinner, 100 px has headroom)
# imagemagick geometry is WxH+X+Y. "X,Y WxH" (PIL syntax) makes convert emit
# the uncropped image silently — always write size first.
STRIP_H=100; STRIP_W=1920; SCREEN_H=1080
case "$POSITION" in
  top)    STRIP="${STRIP_W}x${STRIP_H}+0+0" ;;
  bottom) STRIP="${STRIP_W}x${STRIP_H}+0+$((SCREEN_H - STRIP_H))" ;;
  left)   STRIP="${STRIP_H}x1080+0+0" ;;
  right)  STRIP="${STRIP_H}x1080+$((1920 - STRIP_H))+0" ;;
  *) echo "bad --position: $POSITION (bottom|top|left|right)" >&2; exit 2 ;;
esac
# thirds run along the docked edge: x-offsets for top/bottom, y for left/right
if [ "$POSITION" = "left" ] || [ "$POSITION" = "right" ]; then
  THIRD_W=$((SCREEN_H / 3)); THIRD_SIZE="${STRIP_H}x${THIRD_W}"; AXIS="y"
else
  THIRD_W=$((STRIP_W / 3)); THIRD_SIZE="${THIRD_W}x${STRIP_H}"; AXIS="x"
fi
echo "dock position: $POSITION strip=$STRIP thirds=$THIRD_SIZE"

W=1920; H=1080
CC_RECT="520x${H}+$((W - 520))+0"                # right column of panels
OSD_RECT="500x400+$(((W - 500) / 2))+$((H - 400))" # centered, above bottom
NOTIFY_RECT="560x260+$((W - 560))+0"             # top-right
TOAST_RECT="700x200+$(((W - 700) / 2))+0"        # top-center

n=0
for PNG in "$SHOTS_DIR"/*.png; do
  [ -f "$PNG" ] || continue
  NAME=$(basename "$PNG" .png)
  STEM="$CROPS/$NAME"
  # *-strip.png is already a docked-edge crop (verify.sh taskbar scene); running
  # the strip cut on it yields a 1x1 ghost and a convert warning.
  case "$NAME" in
    *-strip) continue ;;
  esac
  # thirds need the full canvas; a short/odd source is skipped, not mangled.
  # convert is the one binary this script guarantees (guix imagemagick has no
  # separate identify on PATH); pull geometry through convert's info: output.
  if [ "$POSITION" = "left" ] || [ "$POSITION" = "right" ]; then
    MIN_W=$STRIP_H; MIN_H=1080
  else
    MIN_W=1920; MIN_H=$STRIP_H
  fi
  DIMS=$("$IM" "$PNG" -format "%w %h" info: 2>/dev/null | head -1)
  SW=${DIMS%% *}; SH=${DIMS##* }
  [ "${SW:-0}" -ge "$MIN_W" ] && [ "${SH:-0}" -ge "$MIN_H" ] \
    || { echo "skip $NAME: ${SW:-?}x${SH:-?} smaller than ${MIN_W}x${MIN_H}"; continue; }

  # 1) dock strip + left/center/right thirds at 2x — every shot, so the
  #    running/active dock items are checkable regardless of scene.
  "$IM" "$PNG" -crop "$STRIP" +repage "$STEM-dock.png"
  I=0
  for OFF in 0 "$THIRD_W" "$((THIRD_W * 2))"; do
    if [ "$AXIS" = "y" ]; then GEO="${THIRD_SIZE}+0+${OFF}"; else GEO="${THIRD_SIZE}+${OFF}+0"; fi
    case $I in
      0) "$IM" "$STEM-dock.png" -crop "$GEO" +repage -filter point -resize 200% "$STEM-dock-l.png" ;;
      1) "$IM" "$STEM-dock.png" -crop "$GEO" +repage -filter point -resize 200% "$STEM-dock-c.png" ;;
      2) "$IM" "$STEM-dock.png" -crop "$GEO" +repage -filter point -resize 200% "$STEM-dock-r.png" ;;
    esac
    I=$((I + 1))
  done

  # 2) right-hand column of panel shots (1x)
  case "$NAME" in
    control-center*|settings*|cc-*)
      "$IM" "$PNG" -crop "$CC_RECT" +repage "$STEM-cc.png" ;;
  esac

  # 3) floating overlays (1x, exact rects from the brief)
  case "$NAME" in
    osd-*)         "$IM" "$PNG" -crop "$OSD_RECT" +repage "$STEM-overlay.png" ;;
    notification*) "$IM" "$PNG" -crop "$NOTIFY_RECT" +repage "$STEM-overlay.png" ;;
    toast)         "$IM" "$PNG" -crop "$TOAST_RECT" +repage "$STEM-overlay.png" ;;
  esac
  n=$((n + 1))
done

echo "cropped $n shots -> $CROPS ($(find "$CROPS" -name '*.png' | wc -l) files)"
