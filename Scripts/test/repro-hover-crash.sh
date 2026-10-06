#!/usr/bin/env bash
# Reproduce the hover-delivery SIGSEGV (QQuickItem::isVisible inside
# deliverHoverEventRecursive) in an isolated headless sway.
#
# Usage:  Scripts/test/repro-hover-crash.sh [seconds]
#
# Sweeps a virtual pointer (wlrctl, zwlr_virtual_pointer_v1) back and forth
# across the dock strip while a background loop opens/closes foot windows so
# the app-item Repeater model churns under the moving pointer. Exit 1 means
# qs crashed (bug reproduced); exit 0 means it survived the whole run.
#
# Same isolation guarantees as verify.sh: HOME and all XDG dirs live under
# NOSD_VERIFY_DIR, dbus-run-session gives a private bus, and the compositor
# env vars from the invoking session are scrubbed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK="${NOSD_VERIFY_DIR:-/tmp/nosd-repro-hover}"
DURATION="${1:-90}"

WORK_REAL=$(readlink -f "$WORK" 2>/dev/null || echo "$WORK")
case "$WORK_REAL" in
  /|"$HOME"|"$HOME"/*|/etc|/usr|/gnu|/run/user/*|"")
    echo "refusing to run: NOSD_VERIFY_DIR resolves to unsafe path '$WORK_REAL'" >&2; exit 2 ;;
esac

LOG="$WORK/logs/hover-crash.log"
rm -rf "$WORK"/{config,cache,state,data,home,runtime}
mkdir -p "$WORK"/{logs,home,config,cache,state,data,runtime,sway}
chmod 700 "$WORK/runtime"

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$WORK/config"
export XDG_CACHE_HOME="$WORK/cache"
export XDG_STATE_HOME="$WORK/state"
export XDG_DATA_HOME="$WORK/data"
export XDG_RUNTIME_DIR="$WORK/runtime"
export NOSD_CONFIG_DIR="$WORK/config/nosdshell/"
export NOSD_CACHE_DIR="$WORK/cache/nosdshell/"
mkdir -p "$NOSD_CONFIG_DIR" "$NOSD_CACHE_DIR"

# Same seed as verify.sh except displayMode — the reporter runs auto_hide
# (keep-hidden leaves a 2px sliver), which slides the dock in/out during the
# sweep and is part of the trigger space being tested.
python3 - <<'PYEOF'
import json, os
base = {"settingsVersion": 68,
        "dock": {"displayMode": "auto_hide", "onlySameOutput": False},
        "general": {"telemetryEnabled": False, "showChangelogOnStartup": False}}
cfg = os.environ["NOSD_CONFIG_DIR"].rstrip("/")
cch = os.environ["NOSD_CACHE_DIR"].rstrip("/")
open(cfg + "/settings.json", "w").write(json.dumps(base))
open(cch + "/shell-state.json", "w").write(json.dumps(
    {"changelogState": {"lastSeenVersion": "4.7.8"},
     "telemetry": {"instanceId": "repro"},
     "notificationsState": {"lastSeenTs": 0}}))
PYEOF

cat > "$WORK/sway/config" <<'EOF'
output * resolution 1920x1080 position 0 0
output * bg #1d2430 solid_color
EOF

PKGS="${QS_PKG:-quickshell} sway foot wlrctl grim niri gdb binutils pipewire wireplumber dbus
font-google-noto font-google-noto-sans-cjk papirus-icon-theme adwaita-icon-theme
qtwayland qtmultimedia qt5compat python coreutils findutils grep gawk procps"

export WORK REPO LOG DURATION
guix shell $PKGS -- bash <<'INNEREOF'
set -uo pipefail
cd "$WORK"

unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID
export XDG_CURRENT_DESKTOP=sway

SWAY_PID=""; QS_PID=""; NIRI_PID=""
cleanup() {
  [ -n "$QS_PID" ]   && { kill "$QS_PID" 2>/dev/null; }
  [ -n "$NIRI_PID" ] && kill "$NIRI_PID" 2>/dev/null
  [ -n "$SWAY_PID" ] && { swaymsg exit 2>/dev/null; kill "$SWAY_PID" 2>/dev/null; }
  pkill -f "foot" 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
sway -c "$WORK/sway/config" > "$WORK/logs/sway.log" 2>&1 &
SWAY_PID=$!
for i in $(seq 1 50); do
  S=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1); [ -n "$S" ] && break; sleep 0.2
done
export SWAYSOCK="$S"
for i in $(seq 1 50); do
  W=$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1)
  [ -n "$W" ] && export WAYLAND_DISPLAY=$(basename "$W") && break; sleep 0.2
done
echo "SWAYSOCK=$SWAYSOCK WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
swaymsg "output HEADLESS-1 resolution 1920x1080 position 0 0" 2>/dev/null || swaymsg create_output 2>/dev/null

pipewire > "$WORK/logs/pipewire.log" 2>&1 &
sleep 0.5

SWAY_WL="$WAYLAND_DISPLAY"
if [ "${REPRO_COMPOSITOR:-sway}" = "niri" ]; then
  # Nested niri (winit backend) inside headless sway — runs the real
  # compositor code path that produced the crash, without touching the
  # user's session. The nested window gets a full-output rect so pointer
  # coordinates pass through 1:1.
  cat > "$WORK/niri-config.kdl" <<'NIRICFG'
input { }
outputs {
  "winit" {
    mode "1920x1080"
  }
}
NIRICFG
  NIRI_CONFIG="$WORK/niri-config.kdl" niri > "$WORK/logs/niri.log" 2>&1 &
  NIRI_PID=$!
  for i in $(seq 1 60); do
    W=$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v '\.lock$' | grep -v "^$XDG_RUNTIME_DIR/$SWAY_WL$" | head -1)
    [ -n "$W" ] && break; sleep 0.25
  done
  export WAYLAND_DISPLAY=$(basename "$W")
  for i in $(seq 1 60); do
    N=$(ls "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null | head -1)
    [ -n "$N" ] && export NIRI_SOCKET="$N" && break; sleep 0.25
  done
  echo "niri nested: WAYLAND_DISPLAY=$WAYLAND_DISPLAY NIRI_SOCKET=$NIRI_SOCKET"
  # Put the niri window over the whole output so the dock strip maps 1:1.
  # Identify it by con_id from the tree — app_id/title vary across versions.
  sleep 1
  NIRI_CON=$(swaymsg -t get_tree | python3 -c "
import json, sys
def walk(n):
    if (n.get('app_id') or '') in ('winit', 'niri') or 'niri' in (n.get('name') or '').lower():
        if n.get('type') == 'con' and n.get('pid') == $NIRI_PID:
            print(n['id']); return True
    for c in n.get('nodes', []) + n.get('floating_nodes', []):
        if walk(c): return True
    return False
walk(json.load(sys.stdin))" 2>/dev/null | head -1)
  if [ -n "$NIRI_CON" ]; then
    swaymsg "[con_id=$NIRI_CON] fullscreen enable" 2>/dev/null
    echo "niri window con_id=$NIRI_CON -> fullscreen"
  else
    echo "WARN: could not find niri window in sway tree"
    swaymsg -t get_tree > "$WORK/logs/tree.json" 2>/dev/null
  fi
  sleep 1
  export XDG_CURRENT_DESKTOP=niri
fi

# The real-world crash fires during qs STARTUP (~2s in, services still
# loading, dock delegates incubating) while the pointer is already parked
# on the dock strip. So: park the virtual pointer on the strip FIRST, then
# start sweeping the moment qs launches — never wait for it to be ready.
wlrctl pointer move -5000 -5000   # clamp to (0,0) before any surface exists
wlrctl pointer move 200 1055      # onto where the dock strip will appear
swaymsg 'for_window [app_id=".*"] floating enable, resize set 360 170, move position 1400 60' 2>/dev/null
for i in 0 1 2; do foot --app-id="repro-$i" --title="win-$i" >/dev/null 2>&1 & sleep 0.4; done

if [ "${QS_GDB:-0}" = "1" ]; then
  # Start qs normally (wrapper supplies the QML env), then attach gdb and
  # wait for the SIGSEGV. `continue` blocks until the next stop, so the
  # post-mortem commands run at the crash frame.
  QT_LOGGING_RULES="${QS_LOG_RULES:-qt.quick.hover.trace=true}" qs -p "$REPO" > "$LOG" 2>&1 &
  QS_PID=$!
  sleep 3
  QSREAL=$(readlink -f "/proc/$QS_PID/exe")
  QSLIB=$(grep -o '/gnu/store/[^ ]*qtdeclarative[^ ]*libQt6Quick.so[^ ]*' "/proc/$QS_PID/maps" 2>/dev/null | head -1)
  DBG=$(find /gnu/store -path "*qtdeclarative-6.9.2-debug/lib/debug/gnu/store/*/lib/libQt6Quick.so.6.9.2.debug" 2>/dev/null | head -1)
  # add-symbol-file ignores the debuglink CRC, so a same-version debug file
  # from a differently-hashed build still works. .text runtime address =
  # first r-xp mapping start + .text vaddr offset within its LOAD segment.
  LIBBASE=$(awk -v lib="$QSLIB" '$6==lib && $2 ~ /r-xp/ {print $1; exit}' "/proc/$QS_PID/maps" | cut -d- -f1)
  TEXTVA=$(readelf -W -S "$QSLIB" 2>/dev/null | awk '$2==".text" {print $4; exit}')
  LOADVA=$(readelf -W -l "$QSLIB" 2>/dev/null | awk '/LOAD/ && / R E / {print $3; exit}')
  TEXTVA=${TEXTVA#0x}; LOADVA=${LOADVA#0x}
  TEXTADDR=$(printf '0x%x' $(( 0x$LIBBASE + 0x$TEXTVA - 0x$LOADVA )))
  echo "gdb: exe=$QSREAL lib=$QSLIB base=$LIBBASE text=$TEXTADDR dbg=$DBG"
  gdb -batch -p "$QS_PID" \
      -ex "set pagination off" \
      -ex "add-symbol-file $DBG $TEXTADDR" \
      -ex "continue" \
      -ex "bt 12" \
      -ex "frame 2" -ex "p ii" -ex "p children.size()" -ex "p child" -ex "p item" \
      -ex "x/6gx child" -ex "info symbol *(void**)child" \
      > "$WORK/logs/gdb.log" 2>&1 &
else
  # ulimit -c unlimited + cwd=$WORK so the SIGSEGV leaves `core` in $WORK.
  # QS_DISABLE_CRASH_HANDLER (>=0.3.0) keeps quickshell from eating the signal.
  # gdb attach perturbs the race away (ptrace stops every thread spawn), so
  # post-mortem is done from the core instead.
  start_qs() {
    (ulimit -c unlimited; cd "$WORK"; exec env QS_DISABLE_CRASH_HANDLER=1 QT_LOGGING_RULES="${QS_LOG_RULES:-qt.quick.hover.trace=true}" qs -p "$REPO" >> "$LOG" 2>&1) &
    QS_PID=$!
    QS_STARTED=$(date +%s)
  }
  start_qs
fi

# Background churn: keep opening/closing windows so the app-item Repeater's
# model is rebuilt while the pointer is mid-sweep. Keep churning across qs
# restarts — only the outer loop's STOP flag ends it.
touch "$WORK/.running"
churn() {
  local k=0
  while [ -f "$WORK/.running" ]; do
    foot --app-id="churn-$k" --title="churn-$k" >/dev/null 2>&1 &
    local fp=$!
    sleep 0.35
    kill "$fp" 2>/dev/null
    k=$(( (k + 1) % 1000 ))
  done
}
churn &

# Sweep the pointer back and forth along the dock strip (bottom centre),
# with periodic vertical bounces so the auto-hide dock slides out and the
# pointer re-enters over the reveal sliver — the reporter runs auto_hide.
# wlrctl pointer move takes relative deltas; each invocation is one motion
# event, so the sweep must walk in small steps: a single big jump only
# delivers hover at the landing point and never crosses item boundaries —
# which is exactly the transition the reporter's crash happens on.
wlrctl pointer move -5000 -5000   # clamp to (0,0)
wlrctl pointer move 200 1055      # onto the dock strip
START=$(date +%s)
pass=0
steps=0
sweep() {  # $1 = signed px per step, $2 = step count
  local dx=$1 n=$2 i
  for i in $(seq 1 "$n"); do
    wlrctl pointer move "$dx" 0 || return
    steps=$((steps + 1))
    kill -0 "$QS_PID" 2>/dev/null || return
  done
}
QS_RESTART="${QS_RESTART:-15}"
while kill -0 "$QS_PID" 2>/dev/null && [ $(( $(date +%s) - START )) -lt "$DURATION" ]; do
  # The real crash fires during qs STARTUP (delegates incubating + first
  # toplevels registering) with the pointer already on the strip. Restart qs
  # periodically so the sweep keeps hitting fresh startup windows.
  if [ "${QS_GDB:-0}" != "1" ] && [ $(( $(date +%s) - QS_STARTED )) -ge "$QS_RESTART" ]; then
    kill "$QS_PID" 2>/dev/null; wait "$QS_PID" 2>/dev/null
    start_qs
  fi
  sweep 16 96                       # left -> right, 16px steps over ~1536px
  sweep -16 96                      # right -> left
  wlrctl pointer move 0 -160        # leave the strip entirely (dock hides)
  wlrctl pointer move 0 160         # re-enter over the reveal sliver
  pass=$((pass + 1))
  if [ $((pass % 10)) -eq 0 ]; then
    echo "pass $pass ($steps motion events, $(($(date +%s) - START))s elapsed)"
    grim "$WORK/logs/sweep-$pass.png" 2>/dev/null || true
  fi
done
rm -f "$WORK/.running"

if kill -0 "$QS_PID" 2>/dev/null; then
  echo "SURVIVED $pass passes over $DURATION s — crash not reproduced"
  exit 0
else
  echo "CRASHED on pass $pass ($(($(date +%s) - START))s) — reproduced"
  echo "--- last log lines ---"
  tail -20 "$LOG"
  # Post-mortem from the core: load the qtdeclarative debug file with
  # add-symbol-file (ignores the debuglink CRC), then dump the stale child.
  CORE=$(find "$WORK" -maxdepth 1 -name "core" -o -name "core.*" | head -1)
  QSREAL=$(readlink -f "/proc/$QS_PID/exe" 2>/dev/null)
  if [ -z "$QSREAL" ]; then
    QSREAL=$(find "$(dirname "$(readlink -f "$(which qs)")")" -maxdepth 1 -name ".*-real" | head -1)
  fi
  if [ -n "$CORE" ]; then
    MAPS=$(gdb -batch "$QSREAL" -c "$CORE" -ex "info proc mappings" 2>/dev/null)
    QSLIB=$(echo "$MAPS" | grep -o '/gnu/store/[^ ]*libQt6Quick.so[^ ]*' | head -1)
    LIBBASE=$(echo "$MAPS" | awk -v lib="$QSLIB" 'index($0, lib) {print $1; exit}')
    DBG=$(find /gnu/store -path "*qtdeclarative-6.9.2-debug/lib/debug/gnu/store/*/lib/libQt6Quick.so.6.9.2.debug" 2>/dev/null | head -1)
    TEXTVA=$(readelf -W -S "$QSLIB" 2>/dev/null | awk '$2==".text" {print $4; exit}')
    TEXTVA=${TEXTVA#0x}; LIBBASE=${LIBBASE#0x}
    # first LOAD vaddr is 0, so .text runtime addr = first mapping start + .text vaddr
    TEXTADDR=$(printf '0x%x' $(( 0x$LIBBASE + 0x$TEXTVA )))
    echo "post-mortem: core=$CORE lib=$QSLIB base=$LIBBASE text=$TEXTADDR"
    gdb -batch "$QSREAL" -c "$CORE" \
        -ex "set pagination off" \
        -ex "add-symbol-file $DBG $TEXTADDR" \
        -ex "bt 14" \
        -ex "frame 1" -ex "info args" -ex "info locals" \
        -ex "frame 2" -ex "info args" -ex "info locals" \
        -ex "frame 3" -ex "info args" -ex "info locals" \
        > "$WORK/logs/postmortem.log" 2>&1
    tail -60 "$WORK/logs/postmortem.log"
  fi
  exit 1
fi
INNEREOF
