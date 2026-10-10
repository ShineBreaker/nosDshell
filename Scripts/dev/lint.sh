#!/usr/bin/env bash
# Lint nosDshell QML files with qmllint, resolving qs.* and Quickshell.*
# imports via a generated mirror tree (never written into the repo).
#
# Usage:
#   Scripts/dev/lint.sh                 # all repo .qml files
#   Scripts/dev/lint.sh --changed       # files changed vs HEAD + untracked
#   Scripts/dev/lint.sh file.qml ...    # explicit files
#
# Mirror tree: $NOSD_VERIFY_DIR/qmlimp/qs/... with a generated `qmldir` per
# dir (qmllint requires qmldir to resolve directory imports; Quickshell
# itself doesn't need it). Quickshell.* qmltypes come from the guix
# quickshell package; noctalia-qs is accepted as a fallback for comparison.
#
# Prints only Error:/Critical:/Fatal: diagnostics; full output for failing
# files goes to $NOSD_VERIFY_DIR/logs/lint-errors.log. Exits non-zero if any
# file produces an error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK="${NOSD_VERIFY_DIR:-/tmp/nosd-verify}"
MIRROR="$WORK/qmlimp"
mkdir -p "$WORK/logs"

QMLLINT="${QMLLINT:-$HOME/.guix-home/profile/bin/qmllint}"
[ -x "$QMLLINT" ] || QMLLINT=$(command -v qmllint) || { echo "qmllint not found" >&2; exit 2; }
QTQML="${QTQML:-$HOME/.guix-home/profile/lib/qt6/qml}"
[ -d "$QTQML" ] || QTQML=/usr/lib/qt6/qml   # distro layout fallback (CI containers)
[ -d "$QTQML" ] || QTQML=""

# upstream quickshell qml dir; noctalia-qs kept as fallback for comparison.
# QSQML env override wins (CI passes the distro package's lib/qt6/qml);
# otherwise ask guix only when it exists.
QSQML="${QSQML:-}"
if [ -z "$QSQML" ] && command -v guix >/dev/null; then
  for pkg in quickshell noctalia-qs; do
    d=$(guix build "$pkg" 2>/dev/null | tail -1)/lib/qt6/qml
    [ -d "$d" ] && { QSQML="$d"; break; }
  done
fi
echo "qmllint=$QMLLINT  qsqml=${QSQML:-none}"

# --- build mirror tree ---------------------------------------------------
rm -rf "$MIRROR"; mkdir -p "$MIRROR/qs"
cd "$REPO"
find . \( -name "*.qml" -o -name "*.js" -o -name "*.mjs" \) -not -path "./references/*" | while read -r f; do
  rel="${f#./}"; d=$(dirname "$rel")
  mkdir -p "$MIRROR/qs/$d"
  ln -sf "$REPO/$rel" "$MIRROR/qs/$d/$(basename "$f")"
done
find "$MIRROR/qs" -type d | while read -r d; do
  mapfile -t qmls < <(find "$d" -maxdepth 1 -name "*.qml" -printf "%f\n" | sort)
  [ ${#qmls[@]} -eq 0 ] && continue
  rel="${d#$MIRROR/qs}"; rel="${rel#/}"
  mod="qs"; [ -n "$rel" ] && mod="qs.${rel//\//.}"
  {
    echo "module $mod"
    for f in "${qmls[@]}"; do
      t="${f%.qml}"
      if head -3 "$d/$f" | grep -q "^pragma Singleton"; then
        echo "singleton $t 1.0 $f"
      else
        echo "$t 1.0 $f"
      fi
    done
  } > "$d/qmldir"
done
echo "mirror: $(find "$MIRROR/qs" -name qmldir | wc -l) qmldir files in $MIRROR/qs"

# --- file selection ------------------------------------------------------
if [ "${1:-}" = "--changed" ]; then
  mapfile -t FILES < <(cd "$REPO" && { git diff --name-only HEAD -- '*.qml'; git ls-files -o --exclude-standard -- '*.qml'; } | sort -u | grep -v '^references/' | sed "s|^|$REPO/|")
elif [ $# -gt 0 ]; then
  mapfile -t FILES < <(printf "%s\n" "$@" | while read -r f; do
    case "$f" in /*) echo "$f" ;; *) echo "$REPO/$f" ;; esac
  done | grep -v "/references/")
else
  mapfile -t FILES < <(find "$REPO" -name "*.qml" -not -path "$REPO/references/*" | sort)
fi
[ ${#FILES[@]} -eq 0 ] && { echo "no files to lint"; exit 0; }

# --- lint ----------------------------------------------------------------
TOTAL=0; ERRFILES=0; ERRN=0
ERRLOG="$WORK/logs/lint-errors.log"; : > "$ERRLOG"
for f in "${FILES[@]}"; do
  out=$("$QMLLINT" ${QSQML:+-I "$QSQML"} ${QTQML:+-I "$QTQML"} -I "$MIRROR" "$f" 2>&1)
  errs=$(grep -cE "^(Error|Critical|Fatal):" <<<"$out" || true)
  if [ "$errs" -gt 0 ]; then
    echo "== ${f#$REPO/} ($errs)"
    grep -E "^(Error|Critical|Fatal):" <<<"$out" | head -10
    { echo "== $f"; echo "$out"; echo; } >> "$ERRLOG"
    ERRFILES=$((ERRFILES+1)); ERRN=$((ERRN+errs))
  fi
  TOTAL=$((TOTAL+1))
done
echo "---- linted $TOTAL files | files with errors: $ERRFILES | error lines: $ERRN"
echo "full output: $ERRLOG"
[ "$ERRFILES" -gt 0 ] && exit 1
exit 0
