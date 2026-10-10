#!/usr/bin/env bash
# Bootstrap the nested-niri verification environment: create the isolated
# HOME/XDG tree, write the niri config, and seed nosDshell settings.
#
# Usage:
#   Scripts/test/niri/bootstrap.sh [--settings FILE.json]
#
#   --settings FILE   deep-merged over the built-in seed (same semantics as
#                     verify.sh --settings)
#
# Knobs (environment):
#   NOSD_NIRI_DIR   isolated root        (default /tmp/nosd-niri-verify)
#   NIRI_OUT        nested output name   (default HEADLESS-1 — the name niri's
#                   winit backend gives its window output)
#   NIRI_W/NIRI_H   output resolution    (default 1920x1080)
#
# After bootstrap, use start-niri.sh then start-shell.sh.
set -uo pipefail
. "$(dirname "$0")/env.sh"

USER_SETTINGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --settings) USER_SETTINGS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$USER_SETTINGS" ] || [ -f "$USER_SETTINGS" ] || { echo "--settings file not found: $USER_SETTINGS" >&2; exit 1; }
[ -z "$USER_SETTINGS" ] || USER_SETTINGS="$(readlink -f "$USER_SETTINGS")"
export USER_SETTINGS

NIRI_OUT="${NIRI_OUT:-HEADLESS-1}"
NIRI_W="${NIRI_W:-1920}"
NIRI_H="${NIRI_H:-1080}"

mkdir -p "$ISO"/{home,config/niri,config/nosdshell,cache/nosdshell,state,data,log,runtime,shots/incoming}
chmod 700 "$ISO/runtime"

# --- niri config -------------------------------------------------------------
# Nested-mode gotchas encoded here (all verified 2026-10-07 on niri 26.04):
#   * winit outputs default to `transform: flipped vertically` — the whole
#     nested desktop renders upside down. Always pin `transform "normal"`.
#   * the hotkey-overlay ("Important Hotkeys") pops up on every start and
#     cannot be closed via `niri msg` under winit (msg windows returns []).
#     Suppress it with skip-at-startup.
#   * screenshot-path supports second resolution only — %f stays a literal in
#     the filename. Burst captures must move each file out immediately
#     (see shot.sh/burst.sh).
#   * prefer-no-csd: nested clients shouldn't draw their own decorations.
cat > "$ISO/config/niri/config.kdl" <<EOF
output "$NIRI_OUT" {
    mode "${NIRI_W}x${NIRI_H}"
    transform "normal"
}
layout {
    background-color "transparent"
}
prefer-no-csd
hotkey-overlay {
    skip-at-startup
}
window-rule {
    match app-id=r#"^.*$"#
    open-focused true
}
binds {
    Mod+Escape { quit; }
}
screenshot-path "$ISO/shots/incoming/%Y-%m-%d_%H-%M-%S.png"
EOF

# --- settings seed -----------------------------------------------------------
# Same rationale as verify.sh (keep the comments there in sync):
#   settings.json must exist or the SetupWizard eats the first frame;
#   settingsVersion MUST equal Commons/Settings.qml's settingsVersion or the
#   migration chain rewrites the seed back to Assets defaults at first load.
# shell-state.json marks changelog/telemetry prompts as already-seen.
SEED='{"settingsVersion":76,"dock":{"hideMode":"keep-showing","onlySameOutput":false},"general":{"telemetryEnabled":false,"showChangelogOnStartup":false}}'
export SEED
python3 - <<'PYEOF' || { echo "FATAL: settings seed write failed" >&2; exit 1; }
import json, os
def merge(a,b):
    for k,v in b.items():
        if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
        else: a[k]=v
base=json.loads(os.environ["SEED"])
uf=os.environ.get("USER_SETTINGS") or ""
if uf: merge(base, json.load(open(uf)))
open(os.environ["NOSD_CONFIG_DIR"].rstrip("/")+"/settings.json","w").write(json.dumps(base))
open(os.environ["NOSD_CACHE_DIR"].rstrip("/")+"/shell-state.json","w").write(
  json.dumps({"changelogState":{"lastSeenVersion":"4.7.8"},
              "telemetry":{"instanceId":"niri-verify"},
              "notificationsState":{"lastSeenTs":0}}))
PYEOF

echo "bootstrap ok: $ISO"
echo "  niri output: $NIRI_OUT ${NIRI_W}x${NIRI_H}"
echo "  real socket: $REAL_WL"
[ -z "$USER_SETTINGS" ] || echo "  user seed:   $USER_SETTINGS"
