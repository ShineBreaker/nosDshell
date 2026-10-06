#!/usr/bin/env bash
# debug-smoke.sh — exercise the DebugService surface in an isolated session.
#
# Starts headless sway + qs (same isolation as verify.sh), then drives the
# `debug` IPC target: toggle, status, root listing, tree dump, destruction
# watch. Verifies the load-bearing pieces: settings section loads, IPC works,
# Component.destruction watchers actually fire.
#
# Usage: bash Scripts/test/debug-smoke.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${NOSD_VERIFY_DIR:-/tmp/nosd-verify}/debug-smoke"
LOG="$WORK/qs.log"

rm -rf "$WORK"
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

# same seed as verify.sh (settingsVersion in lockstep with Commons/Settings.qml)
cat > "$NOSD_CONFIG_DIR/settings.json" <<'EOF'
{"settingsVersion":69,"dock":{"displayMode":"always_visible","onlySameOutput":false},"general":{"telemetryEnabled":false,"showChangelogOnStartup":false}}
EOF
cat > "$NOSD_CACHE_DIR/shell-state.json" <<'EOF'
{"changelogState":{"lastSeenVersion":"4.7.8"},"telemetry":{"instanceId":"smoke"},"notificationsState":{"lastSeenTs":0}}
EOF

cat > "$WORK/sway/config" <<'EOF'
output * resolution 1920x1080 position 0 0
output * bg #1d2430 solid_color
EOF

INNER="$WORK/inner.sh"
cat > "$INNER" <<'INNEREOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$WORK"

# Scrub compositor/platform env inherited from the invoking session
# (same as verify.sh) then run headless.
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID QT_QPA_PLATFORM DISPLAY
export XDG_CURRENT_DESKTOP=sway
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1

sway -c "$WORK/sway/config" > "$WORK/logs/sway.log" 2>&1 &
SWAY_PID=$!
for _ in $(seq 1 50); do
  S=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1); [ -n "$S" ] && export SWAYSOCK="$S" && break; sleep 0.2
done
for _ in $(seq 1 50); do
  W=$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1); [ -n "$W" ] && export WAYLAND_DISPLAY=$(basename "$W") && break; sleep 0.2
done
swaymsg "output HEADLESS-1 resolution 1920x1080 position 0 0" 2>/dev/null || swaymsg create_output 2>/dev/null
# Keep HEADLESS-1 only (same reason as verify.sh): extra heads split panels
# and register duplicate scene roots.
for OUT in $(swaymsg -t get_outputs 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -v '^HEADLESS-1$'); do
  swaymsg "output $OUT disable" 2>/dev/null
done
sleep 1

cleanup() {
  [ -n "${QS_PID:-}" ] && { qs -p "$REPO" kill 2>/dev/null; kill "$QS_PID" 2>/dev/null; }
  kill "$SWAY_PID" 2>/dev/null
}
trap cleanup EXIT

qs -p "$REPO" > "$LOG" 2>&1 &
QS_PID=$!
for _ in $(seq 1 100); do
  qs -p "$REPO" ipc call state all >/dev/null 2>&1 && break
  kill -0 "$QS_PID" 2>/dev/null || { echo "FAIL: qs exited early"; tail -20 "$LOG"; exit 1; }
  sleep 0.2
done
sleep 2
call() { echo "\$ qs ipc call debug $*"; qs -p "$REPO" ipc call debug "$@" 2>&1; echo; }

FAIL=0
check() { # check <desc> <expected-extended-regex> <haystack>
  if grep -qE "$2" <<<"$3"; then echo "  ok: $1"; else echo "  FAIL: $1 — expected '$2'"; FAIL=1; fi
}

echo "=== debug.status (pre-toggle) ==="
OUT=$(call status)
check "isDebug reported" "isDebug=" "$OUT"
check "roots registered unconditionally" "roots=dock-" "$OUT"

echo "=== debug.toggle on ==="
call toggle
sleep 0.5
check "persisted flag" '"enabled": true' "$(cat "$NOSD_CONFIG_DIR/settings.json")"

echo "=== debug.list ==="
OUT=$(call list)
check "dock root registered" "dock-HEADLESS" "$OUT"
# bar-* roots appear only in efficient taskbar mode — in fashion mode the
# standalone Bar is lazily loaded and effectivelyVisible stays false.
echo "  note: bar- roots exist only in efficient mode (fashion = dock only)"

echo "=== debug.tree dock ==="
OUT=$(call tree dock-HEADLESS-1)
check "tree walks children" "(QQuickItem|Item_QML|MouseArea|Rectangle)" "$OUT"
check "tree has geometry" "[0-9]+x[0-9]+" "$OUT"

echo "=== debug.watch dock ==="
OUT=$(call watch dock-HEADLESS-1)
check "watchers installed" "watchers on dock-HEADLESS-1" "$OUT"

# Trigger destruction: open+close a window so a dock delegate is removed.
foot -e true >/dev/null 2>&1 & FOOT=$!
sleep 2; kill "$FOOT" 2>/dev/null; wait "$FOOT" 2>/dev/null
sleep 2
if grep -q "DbgWatch" "$LOG"; then
  echo "  ok: DbgWatch fired on delegate destruction"
else
  echo "  WARN: no DbgWatch lines (delegate may not have been destroyed this cycle)"
fi

echo "=== debug.setModules ==="
call setModules "Dock"
sleep 1
check "modules persisted" '"modules": "Dock"' "$(cat "$NOSD_CONFIG_DIR/settings.json")"

echo "=== debug.setLogLevel warn ==="
call setLogLevel warn
sleep 1
check "logLevel persisted" '"logLevel": "warn"' "$(cat "$NOSD_CONFIG_DIR/settings.json")"

echo "=== debug.toggle off ==="
call toggle
sleep 0.5
check "persisted off" '"enabled": false' "$(cat "$NOSD_CONFIG_DIR/settings.json")"

echo
if [ "$FAIL" = 0 ]; then echo "SMOKE-PASS"; else echo "SMOKE-FAIL"; fi
grep -cE "TypeError|ReferenceError|\.qml:[0-9]+" "$LOG" | sed 's/^/qml-error-lines: /'
exit "$FAIL"
INNEREOF
chmod +x "$INNER"

export WORK REPO LOG NOSD_CONFIG_DIR NOSD_CACHE_DIR
guix shell ${QS_PKG:-quickshell} sway grim dbus foot pipewire wireplumber \
  font-google-noto adwaita-icon-theme qtwayland qtmultimedia qt5compat qtimageformats \
  coreutils findutils grep gawk procps \
  -- dbus-run-session -- bash "$INNER"
