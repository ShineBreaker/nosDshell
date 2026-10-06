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

PKGS="${QS_PKG:-quickshell} sway foot wlrctl grim pipewire wireplumber dbus
font-google-noto font-google-noto-sans-cjk papirus-icon-theme adwaita-icon-theme
qtwayland qtmultimedia qt5compat python coreutils findutils grep gawk procps"

export WORK REPO LOG DURATION
guix shell $PKGS -- bash <<'INNEREOF'
set -uo pipefail
cd "$WORK"

unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID
export XDG_CURRENT_DESKTOP=sway

SWAY_PID=""; QS_PID=""
cleanup() {
  [ -n "$QS_PID" ]   && { qs -p "$REPO" kill 2>/dev/null; kill "$QS_PID" 2>/dev/null; }
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

# The real-world crash fires during qs STARTUP (~2s in, services still
# loading, dock delegates incubating) while the pointer is already parked
# on the dock strip. So: park the virtual pointer on the strip FIRST, then
# start sweeping the moment qs launches — never wait for it to be ready.
wlrctl pointer move -5000 -5000   # clamp to (0,0) before any surface exists
wlrctl pointer move 200 1055      # onto where the dock strip will appear
swaymsg 'for_window [app_id=".*"] floating enable, resize set 360 170, move position 1400 60' 2>/dev/null
for i in 0 1 2; do foot --app-id="repro-$i" --title="win-$i" >/dev/null 2>&1 & sleep 0.4; done

qs -p "$REPO" > "$LOG" 2>&1 &
QS_PID=$!

# Background churn: keep opening/closing windows so the app-item Repeater's
# model is rebuilt while the pointer is mid-sweep. If qs dies, the loop's
# `kill -0` below reports it.
churn() {
  local k=0
  while kill -0 "$QS_PID" 2>/dev/null; do
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
while kill -0 "$QS_PID" 2>/dev/null && [ $(( $(date +%s) - START )) -lt "$DURATION" ]; do
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

if kill -0 "$QS_PID" 2>/dev/null; then
  echo "SURVIVED $pass passes over $DURATION s — crash not reproduced"
  exit 0
else
  echo "CRASHED on pass $pass ($(($(date +%s) - START))s) — reproduced"
  echo "--- last log lines ---"
  tail -20 "$LOG"
  exit 1
fi
INNEREOF
