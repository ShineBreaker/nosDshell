#!/usr/bin/env bash
# Launch nosDshell inside the nested niri and wait until its IPC answers.
#
# Usage:  Scripts/test/niri/start-shell.sh
#
# Runs on the nested niri's wayland socket with the same isolated env — the
# shell's settings, caches, IPC socket and (on the private bus) notification
# service never touch the real session. Keep logging on: unlike a human's
# debug run, a verification run lives on shell.log — silencing categorized
# Qt logs here would also swallow the TypeError/ReferenceError you are
# supposed to catch.
set -uo pipefail
. "$(dirname "$0")/env.sh"

[ -n "$(niri_socket)" ] || { echo "no nested niri socket — run start-niri.sh first" >&2; exit 1; }
[ -n "$QS_BIN" ] || { echo "no quickshell binary; set QS_BIN" >&2; exit 1; }

# Old instance around? stop.sh cleans by pidfile; refuse to double-launch
# rather than racing two shells on the same IPC socket.
if [ -f "$ISO/runtime/shell.pid" ] && kill -0 "$(cat "$ISO/runtime/shell.pid")" 2>/dev/null; then
  echo "shell already running (pid $(cat "$ISO/runtime/shell.pid")); stop.sh first" >&2
  exit 1
fi

HOME="$ISO/home" XDG_CONFIG_HOME="$ISO/config" XDG_CACHE_HOME="$ISO/cache" \
XDG_STATE_HOME="$ISO/state" XDG_DATA_HOME="$ISO/data" XDG_RUNTIME_DIR="$ISO/runtime" \
NOSD_CONFIG_DIR="$ISO/config/nosdshell/" NOSD_CACHE_DIR="$ISO/cache/nosdshell/" \
XDG_CURRENT_DESKTOP=niri WAYLAND_DISPLAY="$(wayland_socket)" \
"$QS_BIN" -p "$REPO" > "$ISO/log/shell.log" 2>&1 &
echo $! > "$ISO/runtime/shell.pid"

wait_shell_ready && echo "shell ready (pid $(cat "$ISO/runtime/shell.pid"))"
