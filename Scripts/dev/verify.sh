#!/usr/bin/env bash
# Isolated runtime verification for nosDshell (Noctalia v4 / Quickshell).
#
# Usage:
#   Scripts/dev/verify.sh <out-name> [--settings FILE.json] [--scenes a,b,c]
#
# Shots land in $NOSD_VERIFY_DIR/shots/<out-name>/, shell log in
# $NOSD_VERIFY_DIR/logs/<out-name>.log.  NOSD_VERIFY_DIR defaults to
# /tmp/nosd-verify.  Everything runs under dbus-run-session with HOME and all
# XDG_* dirs redirected into $NOSD_VERIFY_DIR — the user's real session (niri)
# and dotfiles are never touched. The isolated config/cache/state dirs are
# wiped before each run for reproducibility.
#
# Scenes (default: all, lockscreen always runs last):
#   idle, launcher, control-center, settings, session-menu, notification,
#   osd-volume, audio-panel, network-panel, bluetooth-panel, battery-panel,
#   calendar-panel, media-panel, system-monitor, notification-history,
#   wallpaper, dock, lockscreen
#   plus settings-tab scenes (open the settings panel on a specific tab):
#   settings-general, settings-userinterface, settings-audio,
#   settings-colorscheme, settings-dock, settings-launcher,
#   settings-wallpaper, settings-notifications, settings-osd
#   (tab names per IPCService _settingsTabMap; settings openTab <tab>)
#
# IPC targets available (Services/Control/IPCService.qml):
#   bar, settings, calendar, notifications, toast, idleInhibitor, launcher,
#   lockScreen, brightness, monitors, darkMode, nightLight, colorScheme,
#   volume, sessionMenu, controlCenter, dock, wallpaper, wifi, network,
#   bluetooth, airplaneMode, battery, powerProfile, media, state,
#   desktopWidgets, location, systemMonitor, plugin
#
# Requires the `noctalia-qs` fork (stock quickshell lacks PwAudioSpectrum and
# fails to load this repo). All packages come from `guix shell` — nothing is
# installed into any profile.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK="${NOSD_VERIFY_DIR:-/tmp/nosd-verify}"

# --- args ----------------------------------------------------------------
OUT_NAME=""
USER_SETTINGS=""
SCENES_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --settings) USER_SETTINGS="$2"; shift 2 ;;
    --scenes)   SCENES_ARG="$2";    shift 2 ;;
    -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
    *)          [ -z "$OUT_NAME" ] && OUT_NAME="$1" || { echo "unknown arg: $1" >&2; exit 2; }; shift ;;
  esac
done
[ -n "$OUT_NAME" ] || { echo "usage: verify.sh <out-name> [--settings F.json] [--scenes a,b,c]" >&2; exit 2; }
[[ "$OUT_NAME" =~ ^[A-Za-z0-9._-]+$ && "$OUT_NAME" != "." && "$OUT_NAME" != ".." ]] || { echo "out-name must be a plain name: $OUT_NAME" >&2; exit 2; }

# --- safety: never wipe real dirs ----------------------------------------
WORK_REAL=$(readlink -f "$WORK" 2>/dev/null || echo "$WORK")
case "$WORK_REAL" in
  /|"$HOME"|"$HOME"/*|/etc|/usr|/gnu|/run/user/*|"")
    echo "refusing to run: NOSD_VERIFY_DIR resolves to unsafe path '$WORK_REAL'" >&2; exit 2 ;;
esac

OUT="$WORK/shots/$OUT_NAME"
LOG="$WORK/logs/$OUT_NAME.log"

# wipe isolated state for reproducibility (only inside $WORK)
rm -rf "$WORK"/{config,cache,state,data,home,runtime} "$OUT"
mkdir -p "$OUT" "$WORK"/{logs,home,config,cache,state,data,runtime,sway}
chmod 700 "$WORK/runtime"

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$WORK/config"
export XDG_CACHE_HOME="$WORK/cache"
export XDG_STATE_HOME="$WORK/state"
export XDG_DATA_HOME="$WORK/data"
export XDG_RUNTIME_DIR="$WORK/runtime"
export NOCTALIA_CONFIG_DIR="$WORK/config/noctalia/"
export NOCTALIA_CACHE_DIR="$WORK/cache/noctalia/"
mkdir -p "$NOCTALIA_CONFIG_DIR" "$NOCTALIA_CACHE_DIR"

# --- seed: no wizards/popups, dock always visible -------------------------
# settings.json existing at all  -> Settings.shouldOpenSetupWizard stays false
#   (fresh-install flag only fires on missing file, Commons/Settings.qml:159)
# general.showChangelogOnStartup=false  -> UpdateService skips changelog popup
#   (UpdateService.qml:321)
# general.telemetryEnabled=false        -> TelemetryService never pings
# shell-state.json changelogState.lastSeenVersion >= telemetryIntroVersion
#   (4.0.2) -> UpdateService.shouldShowTelemetryWizard() false
#   (UpdateService.qml:211-225); also marks changelog "seen" for v4.7.8
# settingsVersion:59 skips the v0->59 migration chain (no-op for real users,
# just noise in verify logs)
SEED='{"settingsVersion":59,"dock":{"displayMode":"always_visible"},"general":{"telemetryEnabled":false,"showChangelogOnStartup":false}}'

# minimal sway config
cat > "$WORK/sway/config" <<'EOF'
output * resolution 1920x1080 position 0 0
output * bg #1d2430 solid_color
EOF

PKGS="noctalia-qs sway grim dbus imagemagick libnotify pipewire wireplumber
font-google-noto font-google-noto-sans-cjk papirus-icon-theme adwaita-icon-theme
qtwayland qtmultimedia qt5compat qtimageformats python
coreutils findutils grep gawk procps"

# --- inner script --------------------------------------------------------
INNER="$WORK/inner-verify.sh"
cat > "$INNER" <<'INNEREOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$WORK"

SCENES_ORDER="idle launcher control-center settings session-menu notification
osd-volume osd-brightness audio-panel network-panel bluetooth-panel
battery-panel calendar-panel media-panel system-monitor notification-history
settings-general settings-userinterface settings-audio settings-colorscheme
settings-dock settings-launcher settings-wallpaper settings-notifications
settings-osd
wallpaper dock lockscreen"
if [ -n "$SCENES_ARG" ]; then
  WANTED=" ${SCENES_ARG//,/ } "
  SELECTED=""
  for s in $SCENES_ORDER; do [[ "$WANTED" == *" $s "* ]] && SELECTED="$SELECTED $s"; done
  # lockscreen always last even if listed earlier
  SELECTED="${SELECTED// lockscreen/}"
  [[ "$WANTED" == *" lockscreen "* ]] && SELECTED="$SELECTED lockscreen"
else
  SELECTED="$SCENES_ORDER"
fi
export SELECTED
echo "scenes:$SELECTED"

# seed settings.json (deep-merge user file over built-in seed) + shell-state
python3 - <<'PYEOF'
import json, os
def merge(a,b):
    for k,v in b.items():
        if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
        else: a[k]=v
base=json.loads(os.environ["SEED"])
uf=os.environ.get("USER_SETTINGS") or ""
if uf: merge(base, json.load(open(uf)))
open(os.environ["NOCTALIA_CONFIG_DIR"].rstrip("/")+"/settings.json","w").write(json.dumps(base))
open(os.environ["NOCTALIA_CACHE_DIR"].rstrip("/")+"/shell-state.json","w").write(
  json.dumps({"changelogState":{"lastSeenVersion":"4.7.8"},
              "telemetry":{"instanceId":"verify"},
              "notificationsState":{"lastSeenTs":0}}))
PYEOF

dbus-run-session -- bash <<'DBUSEOF'
set -uo pipefail

SWAY_PID=""; QS_PID=""; PW_PID=""; WP_PID=""
cleanup() {
  [ -n "$QS_PID" ]   && { qs -p "$REPO" kill 2>/dev/null; kill "$QS_PID" 2>/dev/null; }
  [ -n "$WP_PID" ]   && kill "$WP_PID" 2>/dev/null
  [ -n "$PW_PID" ]   && kill "$PW_PID" 2>/dev/null
  [ -n "$SWAY_PID" ] && { swaymsg exit 2>/dev/null; kill "$SWAY_PID" 2>/dev/null; }
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

# pipewire on the private bus so AudioService / volume OSD work
pipewire   > "$WORK/logs/pipewire.log"   2>&1 & PW_PID=$!
wireplumber > "$WORK/logs/wireplumber.log" 2>&1 & WP_PID=$!
sleep 1

qs -p "$REPO" > "$LOG" 2>&1 &
QS_PID=$!
for i in $(seq 1 60); do
  qs -p "$REPO" ipc call state all >/dev/null 2>&1 && break
  kill -0 "$QS_PID" 2>/dev/null || { echo "qs exited early — see $LOG"; exit 1; }
  sleep 0.5
done
sleep 6

shot() { grim "$OUT/$1.png" && echo "saved $1.png"; }
call() { local s="${!#}"; set -- "${@:1:$#-1}"; echo "ipc: $*"; qs -p "$REPO" ipc call "$@" 2>&1; sleep "$s"; }
toggle() { call "$1" "$2" "${3:-1.5}"; shot "$4"; call "$1" "$2" 0.5; }

run_scene() {
  case "$1" in
    idle)                 shot idle ;;
    launcher)             toggle launcher toggle 1.5 launcher ;;
    control-center)       toggle controlCenter toggle 1.5 control-center ;;
    settings)             call settings open 2; shot settings; call settings toggle 0.5 ;;
    settings-*)           call settings openTab "${1#settings-}" 2; shot "$1"; call settings toggle 0.5 ;;
    session-menu)         toggle sessionMenu toggle 1.5 session-menu ;;
    notification)         notify-send -a noctalia-verify "Baseline notification" \
                            "This is the default notification look." 2>/dev/null
                          sleep 0.8; shot notification ;;
    osd-volume)           call volume increase 0.4; call volume increase 0.4
                          call volume increase 0.4; shot osd-volume ;;
    osd-brightness)       call brightness increase 0.4; shot osd-brightness ;;
    audio-panel)          toggle volume togglePanel 1.5 audio-panel ;;
    network-panel)        toggle network togglePanel 1.5 network-panel ;;
    bluetooth-panel)      toggle bluetooth togglePanel 1.5 bluetooth-panel ;;
    battery-panel)        toggle battery togglePanel 1.5 battery-panel ;;
    calendar-panel)       toggle calendar toggle 1.5 calendar-panel ;;
    media-panel)          toggle media toggle 1.5 media-panel ;;
    system-monitor)       toggle systemMonitor toggle 1.5 system-monitor ;;
    notification-history) toggle notifications toggleHistory 1.5 notification-history ;;
    wallpaper)            call wallpaper set "$REPO/Assets/Wallpaper/noctalia.png" 2
                          shot wallpaper ;;
    dock)                 call dock toggle 1.5; shot dock; call dock toggle 1.5 ;;
    lockscreen)           call lockScreen lock 2.5; shot lockscreen ;;
    *)                    echo "unknown scene: $1" ;;
  esac
}
for s in $SELECTED; do run_scene "$s"; done
echo "=== DONE ==="
DBUSEOF
INNEREOF
chmod +x "$INNER"

export WORK REPO OUT LOG SCENES_ARG SEED USER_SETTINGS
guix shell $PKGS -- bash "$INNER"
STATUS=$?

echo "================ error summary ($LOG) ================"
grep -nE "ReferenceError|TypeError|is not defined|Cannot assign|Unable to|qml.*error|\.qml:[0-9]+" "$LOG" 2>/dev/null | head -60
COUNT=$(grep -cE "ReferenceError|TypeError|is not defined|Cannot assign|Unable to|Error" "$LOG" 2>/dev/null)
echo "---- total matching lines: $COUNT"
ls -la "$OUT"

NPNG=$(find "$OUT" -name "*.png" | wc -l)
[ "$NPNG" -eq 0 ] && { echo "FAIL: no screenshots produced" >&2; exit 1; }
[ "$STATUS" -ne 0 ] && exit "$STATUS"
exit 0
