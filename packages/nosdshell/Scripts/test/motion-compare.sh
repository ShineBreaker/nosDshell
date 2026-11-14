#!/usr/bin/env bash
# Stack the filmstrips and curves of two motion.sh runs, burst by burst.
#
# Usage: Scripts/test/motion-compare.sh <before-shots-dir> <after-shots-dir> <out-dir>
#
# For every burst present in both runs writes <out-dir>/<burst>.png: the
# before filmstrip over the after filmstrip, each curve beside its strip,
# and a header line with both metrics.json. Needs ImageMagick (`convert`),
# which the verify environment provides.
set -euo pipefail
BEFORE="$1"; AFTER="$2"; DEST="$3"
mkdir -p "$DEST"
for b in "$BEFORE"/*/filmstrip.png; do
  name=$(basename "$(dirname "$b")")
  a="$AFTER/$name/filmstrip.png"
  [ -f "$a" ] || continue
  mb=$(tr -d '\n ' < "$BEFORE/$name/metrics.json")
  ma=$(tr -d '\n ' < "$AFTER/$name/metrics.json")
  convert \
    \( "$b" "$BEFORE/$name/curve.png" -resize x240 +append -background '#ddd' -gravity west -splice 0x22 -annotate +6+4 "before  $mb" \) \
    \( "$a" "$AFTER/$name/curve.png" -resize x240 +append -background '#ddd' -gravity west -splice 0x22 -annotate +6+4 "after   $ma" \) \
    -append "$DEST/$name.png"
  echo "wrote $DEST/$name.png"
done
