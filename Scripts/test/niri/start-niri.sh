#!/usr/bin/env bash
# Launch the nested niri (as a window on the real session's compositor) and
# wait until both its wayland socket and its IPC socket exist.
#
# Usage:  Scripts/test/niri/start-niri.sh
#
# Runs niri under dbus-run-session so it gets a private D-Bus bus — nothing
# (notification daemon, portals, status services) can claim names on the real
# session bus. WAYLAND_DISPLAY is pointed at the REAL session socket on
# purpose: that is what makes niri run nested instead of taking over a TTY.
set -uo pipefail
. "$(dirname "$0")/env.sh"

[ -f "$ISO/config/niri/config.kdl" ] || { echo "run bootstrap.sh first" >&2; exit 1; }

# The inner script records its own pid BEFORE exec'ing niri, so niri.pid
# always holds the compositor's real pid (dbus-run-session's pid differs and
# killing it would not necessarily reap the compositor).
cat > "$ISO/runtime/start-niri-inner.sh" <<EOF
#!/usr/bin/env bash
set -uo pipefail
export HOME="$ISO/home"
export XDG_CONFIG_HOME="$ISO/config"
export XDG_CACHE_HOME="$ISO/cache"
export XDG_STATE_HOME="$ISO/state"
export XDG_DATA_HOME="$ISO/data"
export XDG_RUNTIME_DIR="$ISO/runtime"
export WAYLAND_DISPLAY="$REAL_WL"
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID SWAYSOCK I3SOCK
echo \$\$ > "$ISO/runtime/niri.pid"
exec niri > "$ISO/log/niri.log" 2>&1
EOF
chmod +x "$ISO/runtime/start-niri-inner.sh"

dbus-run-session -- "$ISO/runtime/start-niri-inner.sh" &

# Wait for the wayland socket (clients) ...
for i in $(seq 1 100); do
  [ -n "$(wayland_socket)" ] && break
  { [ -f "$ISO/runtime/niri.pid" ] && ! kill -0 "$(cat "$ISO/runtime/niri.pid")" 2>/dev/null; } && { echo "niri died"; tail -20 "$ISO/log/niri.log" >&2; exit 1; }
  sleep 0.2
done
[ -n "$(wayland_socket)" ] || { echo "wayland socket never appeared" >&2; tail -20 "$ISO/log/niri.log" >&2; exit 1; }
# ... and the niri IPC socket (niri msg).
for i in $(seq 1 100); do
  [ -n "$(niri_socket)" ] && break
  sleep 0.2
done
[ -n "$(niri_socket)" ] || { echo "niri IPC socket never appeared" >&2; exit 1; }

echo "niri up: pid $(cat "$ISO/runtime/niri.pid"), socket $(basename "$(niri_socket)"), wayland $(wayland_socket)"
