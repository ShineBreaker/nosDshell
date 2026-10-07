# Shared environment for the nested-niri harness. Source this file, do not
# execute it: `. "$(dirname "$0")/env.sh"`.
#
# What it does:
#   - resolves the isolated root ($NOSD_NIRI_DIR, default /tmp/nosd-niri-verify)
#     and refuses to run if it resolves somewhere unsafe
#   - exports the isolated HOME/XDG_* tree so the nested compositor and the
#     shell under test never touch the real session's config, state, caches,
#     IPC sockets, or notification bus
#   - scrubs compositor fingerprints (NIRI_SOCKET, HYPRLAND_*, LABWC_PID) so
#     services cannot accidentally reach the real compositor
#   - defines helpers used by the sibling scripts: niri_socket/wayland_socket
#     discovery, qs() IPC wrapper, niri_msg()

ISO="${NOSD_NIRI_DIR:-/tmp/nosd-niri-verify}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Same safety rule as repro-hover-crash.sh: the tree below ISO is wiped and
# repopulated, so it must never resolve to $HOME or a system path.
ISO_REAL="$(readlink -f "$ISO" 2>/dev/null || echo "$ISO")"
case "$ISO_REAL" in
  /|"$HOME"|"$HOME"/*|/etc|/usr|/gnu|/run/user/*|"")
    echo "refusing to run: NOSD_NIRI_DIR resolves to unsafe path '$ISO_REAL'" >&2
    return 1 2>/dev/null || exit 2 ;;
esac

# The real session's wayland socket — the compositor the nested niri runs as a
# window on. Prefer the caller's own WAYLAND_DISPLAY (that is the socket the
# invoking session is talking to), fall back to the first socket in the real
# runtime dir. Everything else under XDG_RUNTIME_DIR must stay real-session,
# only the wayland socket path crosses the boundary.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  case "$WAYLAND_DISPLAY" in
    /*) REAL_WL="$WAYLAND_DISPLAY" ;;
    *)  REAL_WL="/run/user/${UID:-1000}/$WAYLAND_DISPLAY" ;;
  esac
else
  REAL_WL="$(ls /run/user/"${UID:-1000}"/wayland-* 2>/dev/null | head -1)"
fi
[ -S "$REAL_WL" ] || { echo "no real wayland socket at '$REAL_WL'" >&2; return 1 2>/dev/null || exit 1; }
REAL_WL="$(readlink -f "$REAL_WL")"

export ISO REPO REAL_WL
# Capture the real home before we shadow it — used for well-known binary paths.
export HOME_REAL="$HOME"
export HOME="$ISO/home"
export XDG_CONFIG_HOME="$ISO/config"
export XDG_CACHE_HOME="$ISO/cache"
export XDG_STATE_HOME="$ISO/state"
export XDG_DATA_HOME="$ISO/data"
export XDG_RUNTIME_DIR="$ISO/runtime"
export NOSD_CONFIG_DIR="$ISO/config/nosdshell/"
export NOSD_CACHE_DIR="$ISO/cache/nosdshell/"
export XDG_CURRENT_DESKTOP=niri

# Compositor fingerprints: never let the nested side inherit a socket or pid
# that points at the real session (CompositorService, tray daemons and niri's
# own client code all probe these).
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID SWAYSOCK I3SOCK WAYLAND_DISPLAY

# quickshell binary: caller override, then PATH, then a one-off resolution via
# `guix shell` (same way verify.sh obtains it — nothing is installed into any
# profile). Never hardcode a guix store path; it breaks on every update.
if [ -z "${QS_BIN:-}" ]; then
  QS_BIN="$(command -v quickshell || command -v qs || true)"
fi
if [ -z "$QS_BIN" ] && command -v guix >/dev/null 2>&1; then
  QS_BIN="$(guix shell quickshell -- sh -c 'command -v quickshell' 2>/dev/null || true)"
fi
[ -n "$QS_BIN" ] || echo "warning: no quickshell binary found; set QS_BIN" >&2
export QS_BIN

# --- helpers ---------------------------------------------------------------

# The nested niri's own IPC socket (inside the isolated runtime dir).
niri_socket() { ls "$ISO/runtime"/niri.*.sock 2>/dev/null | head -1; }

# The wayland socket the nested niri exposes to clients running inside it.
wayland_socket() { ls "$ISO/runtime" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1; }

# Talk to the shell's IPC inside the nested env.
qs() {
  HOME="$ISO/home" XDG_CONFIG_HOME="$ISO/config" XDG_CACHE_HOME="$ISO/cache" \
  XDG_STATE_HOME="$ISO/state" XDG_DATA_HOME="$ISO/data" XDG_RUNTIME_DIR="$ISO/runtime" \
  NOSD_CONFIG_DIR="$ISO/config/nosdshell/" NOSD_CACHE_DIR="$ISO/cache/nosdshell/" \
  WAYLAND_DISPLAY="$(wayland_socket)" \
  "$QS_BIN" -p "$REPO" ipc call "$@"
}

# Talk to the nested niri's IPC (screenshot, layers, windows, ...).
niri_msg() {
  NIRI_SOCKET="$(niri_socket)" XDG_RUNTIME_DIR="$ISO/runtime" niri msg "$@"
}

# Wait until the shell IPC answers `state all` (max ~60 s). Fails fast if the
# recorded shell pid died.
wait_shell_ready() {
  local i
  for i in $(seq 1 120); do
    qs state all >/dev/null 2>&1 && return 0
    [ -f "$ISO/runtime/shell.pid" ] && ! kill -0 "$(cat "$ISO/runtime/shell.pid")" 2>/dev/null && {
      echo "shell died" >&2; tail -25 "$ISO/log/shell.log" >&2; return 1; }
    sleep 0.5
  done
  echo "shell IPC timeout" >&2; tail -25 "$ISO/log/shell.log" >&2; return 1
}
