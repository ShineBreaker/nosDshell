#!/usr/bin/env bash
# Isolated runtime verification for nosDshell (Noctalia v4 / Quickshell).
#
# Usage:
#   Scripts/test/verify.sh <out-name> [--settings FILE.json] [--scenes a,b,c]
#
# Shots land in $NOSD_VERIFY_DIR/shots/<out-name>/, shell log in
# $NOSD_VERIFY_DIR/logs/<out-name>.log.  NOSD_VERIFY_DIR defaults to
# /tmp/nosd-verify.  Everything runs under dbus-run-session with HOME and all
# XDG_* dirs redirected into $NOSD_VERIFY_DIR — the user's real session (niri)
# and dotfiles are never touched. The isolated config/cache/state dirs are
# wiped before each run for reproducibility.
#
# Scenes (default: all, lockscreen always runs last):
#   idle, taskbar, launcher, launcher-search, launcher-category, launcher-mini,
#   launcher-modeswap, control-center, cc-notifications, cc-quick-wifi,
#   cc-quick-bluetooth, cc-quick-display, cc-quick-vpn, cc-quick-basic,
#   settings, session-menu, notification,
#   osd-volume, audio-panel, network-panel, bluetooth-panel, battery-panel,
#   calendar-panel, media-panel, system-monitor, notification-history,
#   wallpaper, wallpaper-panel, dock, lockscreen
#   taskbar additionally emits a strip crop beside the full shot (below).
#   plus settings-tab scenes (open the settings panel on a specific tab,
#   names follow the openTab alias map in ControlCenterModules.qml):
#   settings-general, settings-userinterface, settings-audio,
#   settings-colorscheme, settings-dock, settings-launcher,
#   settings-wallpaper, settings-notifications, settings-osd,
#   settings-about, settings-bar, settings-connections, settings-controlcenter,
#   settings-desktopwidgets, settings-display, settings-hooks, settings-idle,
#   settings-lockscreen, settings-plugins, settings-sessionmenu,
#   settings-system, settings-systemmonitor
#   (tab names per IPCService _settingsTabMap; settings openTab <tab>)
#
# IPC targets available (Services/Control/IPCService.qml):
#   bar, settings, calendar, notifications, toast, idleInhibitor, launcher,
#   lockScreen, brightness, monitors, darkMode, nightLight, colorScheme,
#   volume, sessionMenu, controlCenter, dock, wallpaper, wifi, network,
#   bluetooth, airplaneMode, battery, powerProfile, media, state,
#   desktopWidgets, location, systemMonitor, plugin
#
# Runs under upstream `quickshell` by default; set QS_PKG=noctalia-qs to
# compare against the (archived) fork. All packages come from `guix shell` —
# nothing is installed into any profile.
#
# Environment knobs:
#   NOSD_VERIFY_DIR          isolated root (default /tmp/nosd-verify)
#   NOSD_SEED_DESKTOP_APPS   1 (default) = write fake .desktop entries into the
#                            isolated $XDG_DATA_HOME so launcher grids render
#   NOSD_SPAWN_WINDOWS       1 (default) = after qs is ready, start 2–3 sway
#                            windows with distinct app_ids so the dock's
#                            running/active-window states have real toplevels
#                            (DESIGN §3.1.2 indicator strip, §3.1.3 efficient
#                            fill + underline). Windows are parked floating at
#                            the top-right, shrunk, and never cover the dock
#                            strip. Set 0 to disable. PIDs are killed on exit.
#   NOSD_PAM_BAD=1           separate run: lockscreen-error scene only
#   NOSD_AUTOSTART_AUTH=1    seed general.autoStartAuth=true
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
export NOSD_CONFIG_DIR="$WORK/config/nosdshell/"
export NOSD_CACHE_DIR="$WORK/cache/nosdshell/"
mkdir -p "$NOSD_CONFIG_DIR" "$NOSD_CACHE_DIR"

# --- seed test .desktop apps into the isolated XDG_DATA_HOME -----------------
# The headless image has (almost) no .desktop files, so the launcher grid would
# be empty. NOSD_SEED_DESKTOP_APPS=1 (default) writes a small set spanning the
# 11 DDE categories into $XDG_DATA_HOME/applications/ so grid/category scenes
# have something to render. Never touches the user's real dirs.
if [ "${NOSD_SEED_DESKTOP_APPS:-1}" = "1" ]; then
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
  write_app nosd-firefox       "Firefox"        "firefox"                 "firefox"                "Network;WebBrowser"     "Browse the web"
  write_app nosd-thunderbird   "Thunderbird"    "thunderbird"             "thunderbird"            "Network;Email"          "Email and news client"
  write_app nosd-telegram      "Telegram"       "telegram"                "telegram-desktop"       "Network;InstantMessaging" "Instant messaging"
  write_app nosd-vlc           "VLC Media Player" "vlc"                   "vlc"                    "AudioVideo;Video;Player" "Play audio and video"
  write_app nosd-rhythmbox     "Rhythmbox"      "rhythmbox"               "rhythmbox"              "AudioVideo;Audio"       "Music player"
  write_app nosd-gimp          "GIMP"           "gimp"                    "gimp"                   "Graphics;2DGraphics"    "Image editor"
  write_app nosd-inkscape      "Inkscape"       "inkscape"                "inkscape"               "Graphics;VectorGraphics" "Vector graphics editor"
  write_app nosd-steam         "Steam"          "steam"                   "steam"                  "Game"                   "Game platform"
  write_app nosd-0ad           "0 A.D."         "0ad"                     "0ad"                    "Game;StrategyGame"      "Real-time strategy game"
  write_app nosd-writer        "LibreOffice Writer" "libreoffice-writer"  "libreoffice --writer"   "Office;WordProcessor"   "Word processor"
  write_app nosd-calc          "LibreOffice Calc"   "libreoffice-calc"    "libreoffice --calc"     "Office;Spreadsheet"     "Spreadsheet"
  write_app nosd-evince        "Document Viewer"    "evince"              "evince"                 "Office;Viewer"          "View PDF documents"
  write_app nosd-feedreader    "Feed Reader"    "internet-news-reader"    "feedreader"             "News;"                  "Read RSS feeds"
  write_app nosd-okular        "Okular"         "okular"                  "okular"                 "Office;TextEditor"      "Document viewer"
  write_app nosd-vscode        "Visual Studio Code" "code"                "code"                   "Development;IDE"        "Code editor"
  write_app nosd-gitg          "gitg"           "git"                     "gitg"                   "Development;RevisionControl" "Git client"
  write_app nosd-files         "Files"          "system-file-manager"     "nautilus"               "System;FileManager"     "File manager"
  write_app nosd-terminal      "Terminal"       "utilities-terminal"      "alacritty"              "System;TerminalEmulator" "Terminal emulator"
  write_app nosd-settings      "Settings"       "preferences-system"      "gnome-control-center"   "System;Settings"        "System settings"
  write_app nosd-imageviewer   "Image Viewer"   "eog"                     "eog"                    "Graphics;Viewer"        "View images"
  write_app nosd-pluma         "Pluma Text Editor" "accessories-text-editor" "pluma"               "Utility;TextEditor"     "Text editor"
  update-desktop-database "$XDG_DATA_HOME/applications" 2>/dev/null || true
fi

# --- seed: no wizards/popups, dock always visible -------------------------
# settings.json existing at all  -> Settings.shouldOpenSetupWizard stays false
#   (fresh-install flag only fires on missing file, Commons/Settings.qml:159)
# general.showChangelogOnStartup=false  -> UpdateService skips changelog popup
#   (UpdateService.qml:321)
# general.telemetryEnabled=false        -> TelemetryService never pings
# shell-state.json changelogState.lastSeenVersion >= telemetryIntroVersion
#   (4.0.2) -> UpdateService.shouldShowTelemetryWizard() false
#   (UpdateService.qml:211-225); also marks changelog "seen" for v4.7.8
# settingsVersion must match Commons/Settings.qml`settingsVersion` (67): a
# mismatch makes Settings run the versioned migrations on first load, which
# rewrite the seed's dock.*/general.* keys back to Assets defaults before the
# run starts (verified: seed 64 vs runtime 67 lost displayMode/onlySameOutput
# and let the setup wizard take over the screen). Keep in lockstep.
# dock.displayMode gates the fashion dock's auto-hide; efficient (taskbar)
# mode uses dock.hideMode instead.
# dock.onlySameOutput=false: the headless sway reports toplevel .screens as a
# list the Quickshell ShellScreen object never satisfies, so leaving the
# default true silently drops every running app from the dock (verified: with
# it on, no toplevel reaches dockApps; off, all three appear).
SEED='{"settingsVersion":68,"dock":{"displayMode":"always_visible","onlySameOutput":false},"general":{"telemetryEnabled":false,"showChangelogOnStartup":false}}'

# minimal sway config
cat > "$WORK/sway/config" <<'EOF'
output * resolution 1920x1080 position 0 0
output * bg #1d2430 solid_color
EOF

PKGS="${QS_PKG:-quickshell} sway grim dbus imagemagick libnotify pipewire wireplumber
font-google-noto font-google-noto-sans-cjk papirus-icon-theme adwaita-icon-theme
qtwayland qtmultimedia qt5compat qtimageformats python foot
coreutils findutils grep gawk procps"

# --- inner script --------------------------------------------------------
INNER="$WORK/inner-verify.sh"
cat > "$INNER" <<'INNEREOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$WORK"

SCENES_ORDER="idle taskbar launcher launcher-search launcher-category launcher-mini launcher-modeswap
control-center cc-notifications cc-quick-wifi
cc-quick-bluetooth cc-quick-display cc-quick-vpn cc-quick-basic
settings session-menu notification
osd-volume osd-brightness audio-panel network-panel bluetooth-panel
battery-panel calendar-panel media-panel system-monitor notification-history
settings-general settings-userinterface settings-audio settings-colorscheme
settings-dock settings-launcher settings-wallpaper settings-notifications
settings-osd settings-about settings-bar settings-connections
settings-controlcenter settings-desktopwidgets settings-display settings-hooks
settings-idle settings-lockscreen settings-plugins settings-sessionmenu
settings-system settings-systemmonitor notification-actions notification-long osd-overdrive toast \
wallpaper wallpaper-panel dock dock-menu dock-submenu locksscreen" 
if [ -n "$SCENES_ARG" ]; then
  WANTED=" ${SCENES_ARG//,/ } "
  SELECTED=""
  for s in $SCENES_ORDER; do [[ "$WANTED" == *" $s "* ]] && SELECTED="$SELECTED $s"; done
  # lockscreen always last even if listed earlier. Strip the longer name first:
  # substituting "lockscreen" inside "lockscreen-error" would leave "-error".
  SELECTED="${SELECTED// lockscreen-error/}"
  SELECTED="${SELECTED// lockscreen/}"
  [[ "$WANTED" == *" lockscreen "* ]] && SELECTED="$SELECTED lockscreen"
  # lockscreen-error is absent from SCENES_ORDER on purpose (it must not run in
  # the default set) and needs its own invocation because the PAM failure is a
  # process-level env var (Quickshell.env, read at shell start):
  #   NOSD_PAM_BAD=1 ./verify.sh <run>-lockerr --scenes lockscreen-error
  [[ "$WANTED" == *" lockscreen-error "* ]] && SELECTED="$SELECTED lockscreen-error"
else
  SELECTED="$SCENES_ORDER"
fi
export SELECTED
echo "scenes:$SELECTED"

# where is the dock? crop geometry for the taskbar scene + crops.sh default.
# Read the same merged view the shell gets: Assets/settings-default.json +
# the user seed, so --settings {"dock":{"position":"top"}} is honoured.
DOCK_POSITION=$(python3 - "$USER_SETTINGS" <<'PYEOF'
import json,os,sys
base=json.load(open(os.environ["REPO"]+"/Assets/settings-default.json"))
if sys.argv[1]:
    def merge(a,b):
        for k,v in b.items():
            if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
            else: a[k]=v
    merge(base, json.load(open(sys.argv[1])))
sys.stdout.write(base.get("dock",{}).get("position","bottom"))
PYEOF
)
export DOCK_POSITION
# fashion thickness = iconSize*1.5 (Commons/Style.qml:467); efficient taskbars
# are ~40 px. 100 px headroom covers both plus the 2 px hidden sliver.
DOCK_STRIP_PX=100
export DOCK_STRIP_PX
echo "dock.position=$DOCK_POSITION strip=${DOCK_STRIP_PX}px"

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
if os.environ.get("NOSD_AUTOSTART_AUTH") or os.environ.get("NOSD_PAM_BAD"):
    base.setdefault("general",{})["autoStartAuth"]=True
open(os.environ["NOSD_CONFIG_DIR"].rstrip("/")+"/settings.json","w").write(json.dumps(base))
open(os.environ["NOSD_CACHE_DIR"].rstrip("/")+"/shell-state.json","w").write(
  json.dumps({"changelogState":{"lastSeenVersion":"4.7.8"},
              "telemetry":{"instanceId":"verify"},
              "notificationsState":{"lastSeenTs":0}}))
PYEOF

dbus-run-session -- bash <<'DBUSEOF'
set -uo pipefail

# Scrub compositor-detection env inherited from the invoking session: a stray
# NIRI_SOCKET/HYPRLAND signature makes CompositorService connect to the user's
# real compositor and leak its windows into "isolated" shots.
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID
export XDG_CURRENT_DESKTOP=sway

SWAY_PID=""; QS_PID=""; PW_PID=""; WP_PID=""
FOOT_PIDS=""
cleanup() {
  [ -n "$QS_PID" ]   && { qs -p "$REPO" kill 2>/dev/null; kill "$QS_PID" 2>/dev/null; }
  [ -n "$WP_PID" ]   && kill "$WP_PID" 2>/dev/null
  [ -n "$PW_PID" ]   && kill "$PW_PID" 2>/dev/null
  [ -n "$SWAY_PID" ] && { swaymsg exit 2>/dev/null; kill "$SWAY_PID" 2>/dev/null; }
  for P in $FOOT_PIDS; do kill "$P" 2>/dev/null; done
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
# wlroots headless can expose a second HEADLESS-n at the same position; a second
# surface splits panels/OSD and grim only captures one. Keep HEADLESS-1 only.
for OUT in $(swaymsg -t get_outputs 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -v '^HEADLESS-1$'); do
  echo "disabling extra output: $OUT"
  swaymsg "output $OUT disable" 2>/dev/null
done

# pipewire on the private bus so AudioService / volume OSD work
pipewire   > "$WORK/logs/pipewire.log"   2>&1 & PW_PID=$!
wireplumber > "$WORK/logs/wireplumber.log" 2>&1 & WP_PID=$!
sleep 1

# lockscreen-error run: point LockContext at a PAM service that does not exist
# so pam.start() fails (onError -> showFailure) without typing anything; the
# seed turns on general.autoStartAuth so PAM starts with no user interaction.
if [ -n "${NOSD_PAM_BAD:-}" ]; then
  export NOSD_PAM_SERVICE="nosd-verify-nonexistent"
  echo "NOSD_PAM_BAD set: NOSD_PAM_SERVICE=$NOSD_PAM_SERVICE"
fi

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

# --- real windows so the dock shows running/active apps --------------------
# NOSD_SPAWN_WINDOWS=1 (default): the headless sway starts with no windows, so
# ToplevelManager.toplevels is empty and the dock's running/active states
# (DESIGN §3.1.2 indicator strip, §3.1.3 efficient fill + underline) never
# render. Spawn 3 foot windows with distinct app_ids (last one focused), park
# them floating at the top-right shrunk:
#   - ToplevelManager.toplevels is the quickshell global toplevel registry, not
#     a per-workspace list, so parking beats switching workspaces (Dock.qml:404
#     reads it directly; a workspace switch would also empty the scene). Floating
#     keeps them off the desktop area the other scenes shoot.
#   - the dock itself anchors bottom by default, so top-right parking never
#     covers the taskbar strip that crop_range() cuts.
# App_ids are chosen to resolve in papirus/adwaita so the icons differ.
# NB: specs must be an array, one invocation per element; a single string gets
# word-split by `for spec in $specs` and each word becomes its own argv.
spawn_verify_windows() {
  [ "${NOSD_SPAWN_WINDOWS:-1}" = "1" ] || { echo "NOSD_SPAWN_WINDOWS=0: skipping"; return; }
  command -v foot >/dev/null || { echo "foot not found: skipping windows"; return; }
  local specs=(
    "foot"
    "foot --app-id=org.gnome.Calculator --title=Calculator"
    "foot --app-id=org.gnome.Nautilus --title=Files"
  )
  # for_window rules must be registered BEFORE the windows exist: sway applies
  # them at surface-creation time, and a bare `swaymsg ... floating enable`
  # after the fact misses the already-mapped node ("No matching node").
  swaymsg 'for_window [app_id="foot"] floating enable' 2>/dev/null
  swaymsg 'for_window [app_id="org.gnome.Calculator"] floating enable' 2>/dev/null
  swaymsg 'for_window [app_id="org.gnome.Nautilus"] floating enable' 2>/dev/null
  # park coordinates + size also up front; sway honours them on map.
  local k=0
  for a in org.gnome.Calculator org.gnome.Nautilus foot; do
    swaymsg "for_window [app_id=\"$a\"] move position 1500 $((60 + k * 220))" 2>/dev/null
    swaymsg "for_window [app_id=\"$a\"] resize set 360 170" 2>/dev/null
    k=$((k + 1))
  done
  local i=0 spec
  for spec in "${specs[@]}"; do
    # shellcheck disable=SC2086 # spec is a deliberate word-split argv
    foot $spec > "$WORK/logs/foot-$i.log" 2>&1 &
    FOOT_PIDS="$FOOT_PIDS $!"
    i=$((i + 1))
    sleep 0.8
  done
  sleep 1.5
  # con_id lookup needs the tree, and the tree is the only reliable id source
  # (app_id matching through swaymsg criteria works for rules, not for ad-hoc
  # commands). Python parses the JSON instead of grep-by-context, which picks
  # up the wrong node when panes nest.
  local moved=0
  for A in org.gnome.Calculator org.gnome.Nautilus foot; do
    local C
    C=$(swaymsg -t get_tree 2>/dev/null | python3 -c "
import json,sys
t=json.load(sys.stdin)
def walk(n):
    if n.get('app_id')=='$A':
        yield n
    for c in n.get('nodes',[]):
        yield from walk(c)
    for c in n.get('floating_nodes',[]):
        yield from walk(c)
ns=list(walk(t))
print(ns[0]['id'] if ns else '')
")
    [ -n "$C" ] || continue
    swaymsg "[con_id=$C] move position 1500 $((60 + moved * 220))" 2>/dev/null
    swaymsg "[con_id=$C] resize set 360 170" 2>/dev/null
    moved=$((moved + 1))
  done
  sleep 0.5
  echo "spawned windows: $FOOT_PIDS (moved $moved)"
}
spawn_verify_windows

# dock strip rectangle "<x>,<y> <w>x<h>" for imagemagick, from DOCK_POSITION.
# Screen is 1920x1080 (sway config + swaymsg create_output above).
crop_range() {
  local h="${DOCK_STRIP_PX:-100}" w=1920
  # imagemagick geometry is WxH+X+Y (offset form needs the 'x' size first);
  # "X,Y WxH" is PIL syntax and convert silently emits the uncropped image.
  case "${DOCK_POSITION:-bottom}" in
    top)    echo "${w}x${h}+0+0" ;;
    bottom) echo "${w}x${h}+0+$((1080 - h))" ;;
    left)   echo "${h}x1080+0+0" ;;
    right)  echo "${h}x1080+$((1920 - h))+0" ;;
    *)      echo "${w}x${h}+0+$((1080 - h))" ;;
  esac
}
run_scene() {
  case "$1" in
    idle)                 shot idle ;;
    # Full screen plus the docked-edge strip crop, with the spawned windows
    # parked top-right so the running/active items are visible.
    taskbar)              shot taskbar
                          convert "$OUT/taskbar.png" -crop "$(crop_range)" +repage \
                                  "$OUT/taskbar-strip.png" && echo "saved taskbar-strip.png" ;;
    launcher)             toggle launcher toggle 1.5 launcher ;;
    # DDE launcher (DESIGN §3.4): app search, command provider, category mode.
    # Each shot is taken while the launcher stays open; the launcher is closed
    # once at the end of the scene.
    launcher-search)      call launcher toggle 1.5; shot launcher-search-open
                          call launcher setSearchText "fire" 1.2; shot launcher-search-app
                          call launcher setSearchText ">" 1.2;      shot launcher-search-cmd
                          call launcher setSearchText "2+2*8" 1.2;  shot launcher-search-calc
                          call launcher setSearchText "" 0.5;      call launcher toggle 0.5 ;;
    # Category mode: nav column + filtered grid, then back to free mode.
    launcher-category)    call launcher toggle 1.5; shot launcher-category-free
                          call launcher switchDisplayMode 0.6; shot launcher-category-open
                          call launcher selectCategory "Internet" 1.2; shot launcher-category-internet
                          call launcher switchDisplayMode 0.6
                          call launcher toggle 0.5 ;;
    # Mini mode: floating panel anchored 1 px from the bar, search + results.
    launcher-mini)        call launcher switchMode mini 1
                          call launcher toggle 1.5; shot launcher-mini-open
                          call launcher setSearchText "chr" 1.2; shot launcher-mini-search
                          call launcher setSearchText "" 0.5
                          call launcher toggle 0.5
                          call launcher switchMode fullscreen 0.8 ;;
    # Live mode swap: switch while the view is open (gxde-launcher
    # launchersys.cpp:238-246). The query must carry across both ways.
    launcher-modeswap)    call launcher switchMode mini 1
                          call launcher toggle 1.5
                          call launcher setSearchText "chr" 0.8
                          call launcher switchMode fullscreen 1.5; shot launcher-modeswap-full
                          call launcher switchMode mini 1.5;        shot launcher-modeswap-mini
                          call launcher setSearchText "" 0.5
                          call launcher toggle 0.5
                          call launcher switchMode fullscreen 0.8 ;;
    control-center)       toggle controlCenter toggle 1.5 control-center ;;
    # DDE control center: bell page (3 notifications seeded so the list has content)
    cc-notifications)     notify-send -a nosdshell-verify "Notification one" \
                            "First test body for the history list." 2>/dev/null
                          notify-send -a nosdshell-verify "Notification two" \
                            "Second test body, longer line to check elide." 2>/dev/null
                          notify-send -a nosdshell-verify "Notification three" \
                            "Third body with an action" 2>/dev/null
                          sleep 1; toggle controlCenter notifications 1.5 cc-notifications ;;
    # quick-control pages: open the frame, select the page, shoot, close
    cc-quick-*)           local p="${1#cc-quick-}"
                          call controlCenter open 1.5
                          call controlCenter quickPage "$p" 1.2
                          shot "$1"
                          call controlCenter toggle 0.5 ;;
    settings)             call settings open 2; shot settings; call settings toggle 0.5 ;;
    settings-*)           call settings openTab "${1#settings-}" 5; shot "$1"; call settings toggle 0.5 ;;
    session-menu)         toggle sessionMenu toggle 1.5 session-menu ;;
    notification)         notify-send -a nosdshell-verify "Baseline notification" \
                            "This is the default notification look." 2>/dev/null
                          sleep 0.8; shot notification ;;
    osd-volume)           call volume increase 0.4; call volume increase 0.4
                          call volume increase 0.4; shot osd-volume ;;
    osd-brightness)       call brightness increase 0.4; shot osd-brightness ;;
    osd-overdrive)        call volume increase 0.4
                          call volume increase 0.4; call volume increase 0.4
                          call volume increase 0.4; shot osd-overdrive ;;
    notification-actions) # notify-send -A blocks until a reply/close, so it
                          # must run in the background with a hard timeout —
                          # in the foreground it would hang the whole scene run.
                          timeout 8 notify-send -a nosdshell-verify -A "yes=好的" -A "no=算了" \
                          "Actions" "Pick one of the action buttons." \
                          > "$WORK/notify-actions.out" 2>&1 &
                          sleep 1.2; shot notification-actions ;;
    notification-long)    notify-send -a nosdshell-verify "Long body" \
                          "第一行 第一行 第一行 第一行 第一行 第一行 第一行 第一行 第一行"$'\n'"第二行 第二行 第二行 第二行 第二行 第二行 第二行 第二行"$'\n'"第三行 第三行 第三行 第三行 第三行 第三行 第三行 第三行" 2>/dev/null
                          sleep 0.8; shot notification-long ;;
    toast)                call toast send '{"title":"Toast 标题","body":"这是 toast 正文","type":"notice"}' 1.5
                          shot toast ;;
    audio-panel)          toggle volume togglePanel 1.5 audio-panel ;;
    network-panel)        toggle network togglePanel 1.5 network-panel ;;
    bluetooth-panel)      toggle bluetooth togglePanel 1.5 bluetooth-panel ;;
    battery-panel)        toggle battery togglePanel 1.5 battery-panel ;;
    calendar-panel)       toggle calendar toggle 1.5 calendar-panel ;;
    media-panel)          toggle media toggle 1.5 media-panel ;;
    system-monitor)       toggle systemMonitor toggle 1.5 system-monitor ;;
    notification-history) toggle notifications toggleHistory 1.5 notification-history ;;
    wallpaper)            call wallpaper set "$REPO/Assets/Wallpaper/nosdshell.png" 2
                          shot wallpaper ;;
    wallpaper-panel)      toggle wallpaper toggle 1.5 wallpaper-panel ;;
    dock)                 call dock toggle 1.5; shot dock; call dock toggle 1.5 ;;
    dock-menu)            call dock showSettingsMenu 1.5; shot dock-menu ;;
    dock-submenu)         call dock showSettingsSubmenu 1.5; shot dock-submenu ;;
    lockscreen)           call lockScreen lock 2.5; shot lockscreen ;;
    # Requires NOSD_PAM_BAD=1 (separate verify run): LockContext then uses a
    # nonexistent PAM service, so pam.start() errors out and LockContext lands
    # in showFailure — the DDE error tooltip (white card, alert text, arrow up).
    lockscreen-error)
      if [ -n "${NOSD_PAM_BAD:-}" ]; then
        call lockScreen lock 3
        # autoStartAuth + a dead PAM service ⇒ onError ⇒ showFailure
        sleep 2; shot lockscreen-error
      else
        echo "lockscreen-error needs NOSD_PAM_BAD=1 (separate verify run)"
      fi
      ;;
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
