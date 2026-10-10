#!/usr/bin/env bash
# Performance benchmark for nosDshell — one invocation = one measurement round.
#
# Usage:
#   Scripts/test/bench.sh            # run one round, print two metric lines
#   NOSD_BENCH_DIR=/tmp/x Scripts/test/bench.sh
#
# stdout carries EXACTLY two machine-parseable lines (written last, from a
# file, so dbus-activated helper processes that inherit stdout cannot pollute
# them; everything else goes to stderr):
#   metric: startup_ms = <int>
#   metric: panel_toggle_ms = <int>
#
# Metric definitions (the judgement calls are deliberate, documented here):
#
#   startup_ms
#     From the epoch-ms just before forking `qs -p <repo>` to the moment the
#     shell log contains the SECOND "---------------------------" separator.
#     The first separator is shell.qml's root Component.onCompleted (engine
#     alive, settings not yet loaded); the second one is the main UI Loader's
#     Component.onCompleted (shell.qml:97) which only runs after I18n +
#     Settings + ShellState finished loading and the whole UI tree
#     (Background/Dock/OSD/Launcher windows/...) has been instantiated — i.e.
#     "the shell is up". Log polling runs at 20 ms granularity, so the figure
#     carries up to ~20 ms of quantisation noise. Verified equivalent to the
#     IPC-ready gate verify.sh uses (the deferred IPCService.init fires a
#     Qt.callLater after that same separator), but without the ~100 ms/call
#     `qs ipc` process overhead in the polling loop.
#
#   panel_toggle_ms
#     End-to-end "open the launcher panel" latency: from the epoch-ms just
#     before issuing `qs ipc call launcher toggle` to the first screenshot in
#     which the screen-centre crop (760,390 400x300) differs from the
#     pre-open baseline hash. The launcher is a fullscreen surface, so the
#     first pixel change in that crop == the panel's first animated frame has
#     been rendered and composited — this is the "panel visible" judgement.
#     The crop deliberately avoids the bar edges (the clock ticks every
#     second); with desktopWidgets disabled the centre is a static wallpaper
#     while no panel is open, so hash equality/exclusivity is unambiguous.
#     Polling = grim crop (~25 ms, measured on headless sway) + md5sum +
#     10 ms sleep, so granularity is ~40 ms; the figure also includes the
#     `qs ipc` client process startup + socket round trip (tens of ms,
#     constant across runs). Slightly pessimistic in absolute terms, honest
#     for before/after comparisons: everything from IPC delivery through QML
#     binding evaluation, delegate construction, first-frame render and
#     composition lands inside the measured window.
#     One warm-up open/close runs first (the very first open pays cold
#     delegate/icon caches), then 3 measured opens with the MEDIAN reported.
#     Each close is polled until the crop returns to the baseline hash (the
#     close fade holds the surface mapped briefly) plus a 0.3 s settle, so
#     rounds never overlap.
#
# Environment notes:
#   - Same isolation as Scripts/test/verify.sh: dbus-run-session, headless
#     sway (WLR_BACKENDS=headless), HOME/XDG_* redirected into NOSD_BENCH_DIR
#     (default /tmp/nosd-bench), user session never touched. Only PIDs this
#     script started are killed on exit.
#   - Renders through the headless-sway software rasteriser: absolute values
#     are pessimistic vs a real GPU session; relative deltas are the point.
#   - Fake .desktop entries (same set as verify.sh) are seeded so the
#     launcher grid renders a realistic delegate population.
#   - No foot windows are spawned (the dock runs with an empty toplevel set)
#     to keep the round free of extra process jitter.
#   - sway exposes no layer-surface query (no get_layers IPC type, layer
#     shells absent from get_tree — both verified), hence the screenshot
#     polling above.
#
# Repetition protocol: the CALLER runs this script 3 times and takes the
# per-metric median for the final number.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK="${NOSD_BENCH_DIR:-/tmp/nosd-bench}"
LOG="$WORK/logs/bench.log"
METRICS="$WORK/metrics.txt"

# --- safety: never wipe real dirs (mirrors verify.sh) -----------------------
WORK_REAL=$(readlink -f "$WORK" 2>/dev/null || echo "$WORK")
case "$WORK_REAL" in
  /|"$HOME"|"$HOME"/*|/etc|/usr|/gnu|/run/user/*|"")
    echo "refusing to run: NOSD_BENCH_DIR resolves to unsafe path '$WORK_REAL'" >&2; exit 2 ;;
esac

rm -rf "$WORK"/{config,cache,state,data,home,runtime,logs,sway} "$METRICS"
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

# --- seed fake .desktop apps (same set as verify.sh) ------------------------
mkdir -p "$XDG_DATA_HOME/applications"
write_app() { # write_app <file> <Name> <Icon> <Exec> <Categories> <Comment>
  cat > "$XDG_DATA_HOME/applications/$1.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Exec=$4
Icon=$3
Comment=$6
Categories=$5
Terminal=false
EOF
}
write_app nosd-firefox     "Firefox"            "firefox"               "firefox"              "Network;WebBrowser"       "Browse the web"
write_app nosd-thunderbird "Thunderbird"        "thunderbird"           "thunderbird"          "Network;Email"            "Email and news client"
write_app nosd-telegram    "Telegram"           "telegram-desktop"      "telegram-desktop"     "Network;InstantMessaging" "Instant messaging"
write_app nosd-vlc         "VLC Media Player"   "vlc"                   "vlc"                  "AudioVideo;Video;Player"  "Play audio and video"
write_app nosd-rhythmbox   "Rhythmbox"          "rhythmbox"             "rhythmbox"            "AudioVideo;Audio"         "Music player"
write_app nosd-gimp        "GIMP"               "gimp"                  "gimp"                 "Graphics;2DGraphics"      "Image editor"
write_app nosd-inkscape    "Inkscape"           "inkscape"              "inkscape"             "Graphics;VectorGraphics"  "Vector graphics editor"
write_app nosd-steam       "Steam"              "steam"                 "steam"                "Game"                     "Game platform"
write_app nosd-0ad         "0 A.D."             "0ad"                   "0ad"                  "Game;StrategyGame"        "Real-time strategy game"
write_app nosd-writer      "LibreOffice Writer" "libreoffice-writer"    "libreoffice --writer" "Office;WordProcessor"     "Word processor"
write_app nosd-calc        "LibreOffice Calc"   "libreoffice-calc"      "libreoffice --calc"   "Office;Spreadsheet"       "Spreadsheet app"
write_app nosd-evince      "Document Viewer"    "evince"                "evince"               "Office;Viewer"            "View PDF documents"
write_app nosd-vscode      "Visual Studio Code" "code"                  "code"                 "Development;IDE"          "Code editor"
write_app nosd-gitg        "gitg"               "git"                   "gitg"                 "Development;RevisionControl" "Git client"
write_app nosd-files       "Files"              "system-file-manager"   "nautilus"             "System;FileManager"       "File manager"
write_app nosd-terminal    "Terminal"           "utilities-terminal"    "alacritty"            "System;TerminalEmulator"  "Terminal emulator"
write_app nosd-settings    "Settings"           "preferences-system"    "gnome-control-center" "System;Settings"          "System settings"
write_app nosd-imageviewer "Image Viewer"       "eog"                   "eog"                  "Graphics;Viewer"          "View images"
write_app nosd-pluma       "Pluma Text Editor"  "accessories-text-editor" "pluma"             "Utility;TextEditor"       "Text editor"

# --- seed settings.json / shell-state.json (no wizard, no telemetry) --------
# Same rationale as verify.sh — settings.json existing at all keeps the setup
# wizard away; telemetry/changelog popups disabled; shell-state marks the
# changelog/telemetry intro as seen. settingsVersion must match
# Commons/Settings.qml or migrations rewrite the seed.
cat > "$NOSD_CONFIG_DIR/settings.json" <<'EOF'
{"settingsVersion":75,"dock":{"hideMode":"keep-showing","onlySameOutput":false},"general":{"telemetryEnabled":false,"showChangelogOnStartup":false}}
EOF
cat > "$NOSD_CACHE_DIR/shell-state.json" <<'EOF'
{"changelogState":{"lastSeenVersion":"4.7.8"},"telemetry":{"instanceId":"bench"},"notificationsState":{"lastSeenTs":0}}
EOF

# --- minimal headless sway config -------------------------------------------
cat > "$WORK/sway/config" <<'EOF'
output * resolution 1920x1080 position 0 0
output * bg #1d2430 solid_color
EOF

PKGS="quickshell sway dbus grim pipewire wireplumber
font-google-noto font-google-noto-sans-cjk papirus-icon-theme adwaita-icon-theme
qtwayland qtmultimedia qt5compat qtimageformats coreutils"

# --- inner script ------------------------------------------------------------
INNER="$WORK/inner-bench.sh"
cat > "$INNER" <<'INNEREOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$WORK"

dbus-run-session -- bash <<'DBUSEOF'
set -uo pipefail

now_ms() { date +%s%3N; }

# Both separators are Logger.i("Shell", "---...") lines; counting lines keeps
# this robust against the ANSI colour codes Logger wraps them in.
ready_sep_count() { grep -c -- '---------------------------' "$LOG" 2>/dev/null || true; }

# Screen-centre crop hash: the launcher is fullscreen, the crop avoids the
# ticking bar clock, desktopWidgets are off and the wallpaper is static, so
# the centre changes iff a panel (or its fade) is on screen.
CENTER_GEOM="760,390 400x300"
center_hash() { grim -g "$CENTER_GEOM" - 2>/dev/null | md5sum | cut -d' ' -f1; }

# Scrub compositor-detection env inherited from the invoking session (verify.sh).
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID
export XDG_CURRENT_DESKTOP=sway

QS_PID=""; SWAY_PID=""; PW_PID=""; WP_PID=""
cleanup() {
  [ -n "$QS_PID" ]   && { qs -p "$REPO" kill >/dev/null 2>&1; kill "$QS_PID" 2>/dev/null; }
  [ -n "$WP_PID" ]   && kill "$WP_PID" 2>/dev/null
  [ -n "$PW_PID" ]   && kill "$PW_PID" 2>/dev/null
  [ -n "$SWAY_PID" ] && { swaymsg exit >/dev/null 2>&1; kill "$SWAY_PID" 2>/dev/null; }
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
echo "SWAYSOCK=$SWAYSOCK WAYLAND_DISPLAY=$WAYLAND_DISPLAY" >&2
swaymsg "output HEADLESS-1 resolution 1920x1080 position 0 0" 2>/dev/null || swaymsg create_output 2>/dev/null
for EXTRA_OUT in $(swaymsg -t get_outputs 2>/dev/null | grep -o '"name":[[:space:]]*"[^"]*"' | grep -o '"[^"]*"[[:space:]]*$' | tr -d '"' | grep -v '^HEADLESS-1$'); do
  swaymsg "output $EXTRA_OUT disable" 2>/dev/null
done

# pipewire on the private bus so AudioService takes its normal startup path
pipewire    > "$WORK/logs/pipewire.log"   2>&1 & PW_PID=$!
wireplumber > "$WORK/logs/wireplumber.log" 2>&1 & WP_PID=$!
sleep 1

# --- metric 1: startup_ms ----------------------------------------------------
T0=$(now_ms)
qs -p "$REPO" > "$LOG" 2>&1 &
QS_PID=$!
STARTUP_MS=""
for i in $(seq 1 1500); do
  if [ "$(ready_sep_count)" -ge 2 ] 2>/dev/null; then
    STARTUP_MS=$(( $(now_ms) - T0 ))
    break
  fi
  kill -0 "$QS_PID" 2>/dev/null || { echo "FATAL: qs exited early — see $LOG" >&2; exit 1; }
  sleep 0.02
done
[ -n "$STARTUP_MS" ] || { echo "FATAL: shell never became ready in time" >&2; exit 1; }
echo "startup: ready after ${STARTUP_MS} ms (second log separator)" >&2

# sanity: IPC must answer once ready (not part of the timing)
qs -p "$REPO" ipc call state all >/dev/null 2>&1 || { echo "FATAL: IPC not answering after ready" >&2; exit 1; }

# settle: let the deferred-service Qt.callLater block + delayedInitTimer (1.5 s)
# finish so toggle measurements run against a steady shell
sleep 6

# calibration (diagnostic only, stderr): median round trip of a no-op IPC call
# — the fixed `qs ipc` client-process cost that every panel_toggle_ms sample
# carries on top of the actual shell-side open latency.
IPC_OH=""
for r in 1 2 3; do
  T=$(now_ms)
  qs -p "$REPO" ipc call state all >/dev/null 2>&1
  IPC_OH="$IPC_OH$(( $(now_ms) - T ))
"
done
IPC_OH_MED=$(printf '%s' "$IPC_OH" | sort -n | sed -n '2p')
echo "ipc_overhead(state all) median: ${IPC_OH_MED} ms (included in every panel_toggle_ms sample)" >&2

# --- metric 2: panel_toggle_ms ------------------------------------------------
# NOSD_BENCH_PANEL picks which panel the toggle metric drives:
#   launcher (default) — fullscreen launcher, centre crop
#   controlCenter      — DDE control centre, right-side crop (panel spans
#                        roughly x>=1440 on the 1920x1080 headless output)
PANEL_TARGET="${NOSD_BENCH_PANEL:-launcher}"
case "$PANEL_TARGET" in
  launcher)      IPC_TARGET="launcher";      CENTER_GEOM="760,390 400x300" ;;
  controlCenter) IPC_TARGET="controlCenter"; CENTER_GEOM="1500,450 300x300" ;;
  *) echo "FATAL: unknown NOSD_BENCH_PANEL '$PANEL_TARGET' (launcher|controlCenter)" >&2; exit 1 ;;
esac
echo "panel target: $IPC_TARGET, crop: $CENTER_GEOM" >&2

BASE=$(center_hash)
[ -n "$BASE" ] || { echo "FATAL: baseline screenshot failed" >&2; exit 1; }

open_ms() { # echoes the measured open latency, fails (rc 1) on timeout
  local t0 cur
  t0=$(now_ms)
  qs -p "$REPO" ipc call "$IPC_TARGET" toggle >/dev/null 2>&1
  for i in $(seq 1 100); do
    cur=$(center_hash)
    if [ -n "$cur" ] && [ "$cur" != "$BASE" ]; then
      echo $(( $(now_ms) - t0 ))
      return 0
    fi
    sleep 0.01
  done
  return 1
}
close_and_wait() { # close, then poll until the centre is back to wallpaper
  qs -p "$REPO" ipc call "$IPC_TARGET" toggle >/dev/null 2>&1
  for i in $(seq 1 100); do
    local cur; cur=$(center_hash)
    [ "$cur" = "$BASE" ] && break
    sleep 0.01
  done
  sleep 0.3
}

# warm-up open/close: pays the cold delegate/icon caches, not measured
open_ms >/dev/null || { echo "FATAL: warm-up open timed out" >&2; exit 1; }
close_and_wait

SAMPLES=""
for r in 1 2 3; do
  V=$(open_ms) || { echo "FATAL: measured open #$r timed out" >&2; exit 1; }
  echo "panel_toggle round $r: ${V} ms" >&2
  SAMPLES="$SAMPLES$V
"
  close_and_wait
done
MEDIAN=$(printf '%s' "$SAMPLES" | sort -n | sed -n '2p')
echo "panel_toggle samples(ms): $(printf '%s' "$SAMPLES" | tr '\n' ' ')median=$MEDIAN" >&2

# --- metrics land in a file; the outer script owns stdout --------------------
printf 'metric: startup_ms = %s\nmetric: panel_toggle_ms = %s\n' "$STARTUP_MS" "$MEDIAN" > "$METRICS"
echo "metrics written to $METRICS" >&2
DBUSEOF
INNEREOF
chmod +x "$INNER"

export WORK REPO LOG METRICS
# stdout is reserved for the metric lines re-emitted below; everything the
# inner run prints (including dbus-activated helpers) already goes to stderr
# or log files.
guix shell $PKGS -- bash "$INNER" >&2
STATUS=$?
if [ "$STATUS" -ne 0 ] || [ ! -s "$METRICS" ]; then
  echo "FATAL: benchmark round failed (status $STATUS), see $WORK/logs/" >&2
  exit 1
fi
cat "$METRICS"
exit 0
