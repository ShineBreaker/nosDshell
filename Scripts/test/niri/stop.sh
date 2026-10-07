#!/usr/bin/env bash
# Stop the nested niri and the shell under test, by pidfile only — the same
# rule as verify.sh: never pkill, the real session runs same-named processes.
#
# Usage:  Scripts/test/niri/stop.sh
set -uo pipefail
. "$(dirname "$0")/env.sh"

for name in shell niri; do
  pidfile="$ISO/runtime/$name.pid"
  [ -f "$pidfile" ] || continue
  pid="$(cat "$pidfile")"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    for i in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
    kill -0 "$pid" 2>/dev/null && { kill -9 "$pid" 2>/dev/null; echo "$name (pid $pid) killed -9"; } || echo "$name (pid $pid) stopped"
  else
    echo "$name: not running (stale pidfile $pid)"
  fi
  rm -f "$pidfile"
done
