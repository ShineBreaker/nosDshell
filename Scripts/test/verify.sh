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
#   launcher-dismiss,
#   launcher-modeswap, control-center, cc-notifications, cc-quick-wifi,
#   cc-quick-bluetooth, cc-quick-vpn, cc-quick-basic,
#   settings, session-menu, notification,
#   osd-volume, audio-panel, network-panel, bluetooth-panel, battery-panel,
#   calendar-panel, media-panel, system-monitor, notification-history,
#   wallpaper, wallpaper-panel, dock, lockscreen
#   taskbar additionally emits a strip crop beside the full shot (below).
#   idle-inhibit is off the default set (needs its own seed): Keep Awake must
#   suppress the shell's own screenOff; run e.g.
#     ./verify.sh <run> --settings <seed>.json --scenes idle-inhibit
#   with seed {"idle":{"enabled":true,"screenOffTimeout":20,"lockTimeout":0,
#   "suspendTimeout":0,"fadeDuration":1}} — exits non-zero if screenOff fires
#   while inhibited, or never fires after the inhibitor is released.
#   dark-mode-system is off the default set too: it needs NOSD_FAKE_PORTAL=1
#   to fake the xdg desktop portal's colour-scheme response.
#   plus settings-tab scenes (open the settings panel on a specific tab,
#   names follow the openTab alias map in ControlCenterModules.qml):
#   settings-general, settings-userinterface, settings-audio,
#   settings-colorscheme, settings-dock, settings-launcher,
#   settings-wallpaper, settings-notifications, settings-osd,
#   settings-about, settings-advanced, settings-connections, settings-controlcenter, 
#   settings-desktopwidgets, settings-display, settings-hooks, settings-idle,
#   settings-lockscreen, settings-plugins, settings-sessionmenu,
#   settings-system, settings-systemmonitor
#   (tab names per IPCService _settingsTabMap; settings openTab <tab>)
#   settings-subpage is off the default set (needs its own seed — see the
#   scene comment): drives the §3.5.3 二级页 rows on the dock tab.
#   settings-reset is off the default set too (own seed): clicks a widget
#   gear, asserts the 重置为默认值 button rebuilds the entry as defaults.
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
#   NOSD_FAKE_PORTAL=1       dark-mode-system scene: fake the xdg desktop
#                            portal response so the colour-scheme setting can
#                            flip without a real portal
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

# --settings must survive the `cd "$WORK"` below: canonicalize to an absolute
# path now and fail loudly if missing (a silently-unread seed leaves
# settings.json absent -> fresh install -> SetupWizard eats the whole run).
if [ -n "$USER_SETTINGS" ]; then
  USER_SETTINGS="$(readlink -f "$USER_SETTINGS" 2>/dev/null || echo "$USER_SETTINGS")"
  [ -f "$USER_SETTINGS" ] || { echo "--settings file not found or unreadable: $USER_SETTINGS" >&2; exit 2; }
fi

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
# settingsVersion is read from Commons/Settings.qml (the single source): a
# stale number makes Settings run the versioned migrations on first load,
# which rewrite the seed's dock.*/general.* keys back to Assets defaults
# before the run starts (verified: seed 64 vs runtime 67 lost
# displayMode/onlySameOutput and let the setup wizard take over the screen).
# dock.hideMode gates the taskbar auto-hide in both modes (DESIGN §3.1.1):
# keep-showing reserves space, keep-hidden auto-hides, smart-hide hides on overlap.
# dock.onlySameOutput=false: the headless sway reports toplevel .screens as a
# list the Quickshell ShellScreen object never satisfies, so leaving the
# default true silently drops every running app from the dock (verified: with
# it on, no toplevel reaches dockApps; off, all three appear).
SEED_SV=$(sed -n 's/.*readonly property int settingsVersion: *\([0-9][0-9]*\).*/\1/p' "$REPO/Commons/Settings.qml")
SEED="{\"settingsVersion\":$SEED_SV,\"dock\":{\"hideMode\":\"keep-showing\",\"onlySameOutput\":false},\"general\":{\"telemetryEnabled\":false,\"showChangelogOnStartup\":false}}"

# minimal sway config
cat > "$WORK/sway/config" <<'EOF'
output * resolution 1920x1080 position 0 0
output * bg #1d2430 solid_color
EOF

PKGS="${QS_PKG:-quickshell} sway grim dbus imagemagick libnotify pipewire wireplumber
font-google-noto font-google-noto-sans-cjk papirus-icon-theme adwaita-icon-theme
qtwayland qtmultimedia qt5compat qtimageformats python python-dbus python-pygobject python-pillow foot
coreutils findutils grep gawk procps"

# --- inner script --------------------------------------------------------
INNER="$WORK/inner-verify.sh"
cat > "$INNER" <<'INNEREOF'
#!/usr/bin/env bash
set -uo pipefail
cd "$WORK"

SCENES_ORDER="idle taskbar launcher launcher-search launcher-category launcher-mini launcher-dismiss launcher-modeswap launcher-handoff
control-center cc-switch cc-page cc-slider cc-notifications cc-notif-groups cc-quick-wifi
cc-quick-bluetooth cc-quick-vpn cc-quick-basic cc-quick-cards
cc-collapse cc-geom settings-cc-pages
settings session-menu notification
osd-volume osd-brightness audio-panel network-panel bluetooth-panel
battery-panel calendar-panel media-panel system-monitor notification-history
settings-general settings-userinterface settings-audio settings-colorscheme
settings-dock settings-launcher settings-wallpaper settings-notifications
settings-osd settings-about settings-advanced settings-connections
settings-controlcenter settings-desktopwidgets settings-display settings-hooks
settings-idle settings-lockscreen settings-plugins settings-sessionmenu
settings-system settings-systemmonitor notification-actions notification-icon notification-long notification-resave osd-overdrive toast \
wallpaper wallpaper-panel dock dock-menu dock-submenu dock-widget-menu bar-widget-menu notification-shadow lockscreen settings-tree" 
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
  # settings-<tab>/<sub> names are generated, not listed in SCENES_ORDER —
  # pass any requested ones through in the order given.
  for s in $WANTED; do
    case "$s" in
      settings-*/*|settings-scroll-*|settings-themeswitch|settings-search|settings-combo|settings-combo-scheme|settings-subpage|settings-reset|dock-fullscreen|dock-battery-wheel|dock-context-menu|dock-widget-settings|taskbar-settings-write|taskbar-add-widgets|efficient-taskbar|fashion-dock|dark-mode-system|idle-inhibit|usb-panel) [[ " $SELECTED " == *" $s "* ]] || SELECTED="$SELECTED $s" ;;
    esac
  done
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
# Edge of the bar window, mirroring Settings.getBarPositionForScreen:
# the fashion status bar's own position when enabled, else the taskbar edge.
BAR_POSITION=$(python3 - "$USER_SETTINGS" <<'PYEOF'
import json,os,sys
base=json.load(open(os.environ["REPO"]+"/Assets/settings-default.json"))
if sys.argv[1]:
    def merge(a,b):
        for k,v in b.items():
            if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
            else: a[k]=v
    merge(base, json.load(open(sys.argv[1])))
dock=base.get("dock",{}); bar=base.get("bar",{})
pos=dock.get("position","bottom")
if dock.get("mode","efficient")=="fashion" and bar.get("enabled",False):
    pos=bar.get("position","top")
sys.stdout.write(pos)
PYEOF
)
export BAR_POSITION
# dock.mode from the merged view — efficient-taskbar skips itself in fashion.
DOCK_MODE=$(python3 - "$USER_SETTINGS" <<'PYEOF'
import json,os,sys
base=json.load(open(os.environ["REPO"]+"/Assets/settings-default.json"))
if sys.argv[1]:
    def merge(a,b):
        for k,v in b.items():
            if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
            else: a[k]=v
    merge(base, json.load(open(sys.argv[1])))
sys.stdout.write(base.get("dock",{}).get("mode","efficient"))
PYEOF
)
export DOCK_MODE
# fashion thickness = iconSize*1.5 (Commons/Style.qml:467); efficient taskbars
# are ~40 px. 100 px headroom covers both plus the 2 px hidden sliver.
DOCK_STRIP_PX=100
export DOCK_STRIP_PX
echo "dock.position=$DOCK_POSITION strip=${DOCK_STRIP_PX}px"

# seed settings.json (deep-merge user file over built-in seed) + shell-state
# Fail fast: without -e a python traceback would otherwise leave settings.json
# absent and the run would silently degrade into the SetupWizard fresh-install
# path (see hermes verify-matrix §0.1/§3.3).
python3 - <<'PYEOF' || { echo "FATAL: settings seed write failed" >&2; exit 1; }
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

# Seed the wallpaper directory before the shell starts — WallpaperService
# scans once at startup, so files added mid-run are invisible to the strip.
# Unique hues per index so a strip scroll is visible as a positional change.
mkdir -p "$WORK/home/Pictures/Wallpapers"
python3 - <<PYEOF
from PIL import Image
import colorsys
for i in range(1, 15):
    r, g, b = (int(c * 255) for c in colorsys.hsv_to_rgb(i / 15.0, 0.55, 0.75))
    Image.new("RGB", (320, 180), (r, g, b)).save("$WORK/home/Pictures/Wallpapers/wp%02d.png" % i)
PYEOF
cp "$REPO/Assets/Wallpaper/deepin15-desktop.jpg" "$WORK/home/Pictures/Wallpapers/deepin15-desktop.jpg" 2>/dev/null || true

# Plugin fixture for the settings-reset scene. PluginRegistry scans the plugin
# dir once at startup, so the manifest/settings must exist before qs launches.
# The seeded settings.json carries non-default values plus a stale key — the
# reset must restore manifest.metadata.defaultSettings and drop the stale key.
case " $SELECTED " in
  *" settings-reset "*)
    PDIR="$NOSD_CONFIG_DIR/plugins/testreset"
    mkdir -p "$PDIR"
    cat > "$PDIR/manifest.json" <<'PLUGINEOF'
{"id":"testreset","name":"TestReset","version":"1.0.0","author":"verify","description":"reset fixture","entryPoints":{"settings":"Settings.qml"},"metadata":{"defaultSettings":{"accent":"red","level":1,"notes":"default-note"}}}
PLUGINEOF
    cat > "$PDIR/Settings.qml" <<'PLUGINEOF'
import QtQuick
Item {
  property var pluginApi
  implicitWidth: 420
  implicitHeight: 40
  function saveSettings() { pluginApi.saveSettings() }
  Text {
    color: "white"
    text: "accent=" + (pluginApi.pluginSettings.accent || "?") + " level=" + pluginApi.pluginSettings.level
  }
}
PLUGINEOF
    cat > "$PDIR/settings.json" <<'PLUGINEOF'
{"accent":"blue","level":9,"notes":"user-changed","staleKey":"x"}
PLUGINEOF
    cat > "$NOSD_CONFIG_DIR/plugins.json" <<'PLUGINEOF'
{"version":2,"states":{"testreset":{"enabled":true,"sourceUrl":""}},"sources":[]}
PLUGINEOF
    ;;
  # Bundled usb-drive-manager: force its dock widget visible with zero USB
  # devices so the scene can click it and shoot the empty-state panel. The
  # plugin ships builtin+enabled; only the widget's hideWhenEmpty must flip.
  *" usb-panel "*)
    mkdir -p "$NOSD_CONFIG_DIR/plugins/usb-drive-manager"
    cat > "$NOSD_CONFIG_DIR/plugins/usb-drive-manager/settings.json" <<'PLUGINEOF'
{"hideWhenEmpty":false}
PLUGINEOF
    ;;
esac

dbus-run-session -- bash <<'DBUSEOF'
set -uo pipefail

# Scrub compositor-detection env inherited from the invoking session: a stray
# NIRI_SOCKET/HYPRLAND signature makes CompositorService connect to the user's
# real compositor and leak its windows into "isolated" shots.
unset NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE LABWC_PID
export XDG_CURRENT_DESKTOP=sway

SWAY_PID=""; QS_PID=""; PW_PID=""; WP_PID=""
FOOT_PIDS=""; FPORTAL_PID=""
cleanup() {
  [ -n "$QS_PID" ]   && { qs -p "$REPO" kill 2>/dev/null; kill "$QS_PID" 2>/dev/null; }
  [ -n "$WP_PID" ]   && kill "$WP_PID" 2>/dev/null
  [ -n "$PW_PID" ]   && kill "$PW_PID" 2>/dev/null
  [ -n "$SWAY_PID" ] && { swaymsg exit 2>/dev/null; kill "$SWAY_PID" 2>/dev/null; }
  [ -n "$FPORTAL_PID" ] && kill "$FPORTAL_PID" 2>/dev/null
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
for EXTRA_OUT in $(swaymsg -t get_outputs 2>/dev/null | grep -o '"name":[[:space:]]*"[^"]*"' | grep -o '"[^"]*"[[:space:]]*$' | tr -d '"' | grep -v '^HEADLESS-1$'); do
  echo "disabling extra output: $EXTRA_OUT"
  swaymsg "output $EXTRA_OUT disable" 2>/dev/null
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

# dark-mode-system run: own org.freedesktop.portal.Desktop on the private bus
# so DarkModeService's ReadOne + SettingChanged watch hit a controllable fake
# (Scripts/test/fake-portal.py). NOSD_FAKE_PORTAL sets the initial value
# (1 = prefer-dark, 2 = prefer-light); the scene flips it via the Emit method.
if [ -n "${NOSD_FAKE_PORTAL:-}" ]; then
  python3 "$REPO/Scripts/test/fake-portal.py" "$NOSD_FAKE_PORTAL" \
      > "$WORK/logs/fake-portal.log" 2>&1 &
  FPORTAL_PID=$!
  echo "NOSD_FAKE_PORTAL set: initial color-scheme=$NOSD_FAKE_PORTAL"
fi

# cc-notif-groups: the page's day buckets and per-app grouping need history
# entries that notify-send can't produce (yesterday/earlier timestamps,
# several app names). Seed the persistence file the service reads via
# NOSD_NOTIF_HISTORY_FILE (Services/System/NotificationService.qml) before
# qs starts, with times relative to launch.
if [[ " $SELECTED " == *" cc-notif-groups "* ]]; then
  export NOSD_NOTIF_HISTORY_FILE="$WORK/notification-history.json"
  python3 - "$NOSD_NOTIF_HISTORY_FILE" <<'PYEOF'
import json,sys,time
now=int(time.time()*1000); H=3600000; D=24*H
def n(i,app,s,b,ts):
    return {"id":f"seed-{i}","summary":s,"body":b,"appName":app,"urgency":1,
            "timestamp":ts,"originalImage":"","cachedImage":"",
            "actionsJson":"[]","originalId":i}
# Newest-first (loadHistory appends in file order). gamma-cal sits between
# alpha-mail entries on purpose: same-bucket same-app grouping must merge
# non-adjacent rows, not just contiguous runs.
items=[
  n(1,"beta-chat","Beta ping","Beta body, today.",now-10*60000),
  n(2,"alpha-mail","Alpha third","Newest alpha body, today.",now-30*60000),
  n(3,"gamma-cal","Gamma today","Gamma body splitting the alpha run.",now-45*60000),
  n(4,"alpha-mail","Alpha second","Middle alpha body.",now-1*H),
  n(5,"alpha-mail","Alpha first","Oldest alpha body, today.",now-2*H),
  n(6,"alpha-mail","Alpha yesterday 2","Alpha body from yesterday.",now-D-1*H),
  n(7,"gamma-cal","Gamma yesterday","Meeting moved to 明天.",now-D-3*H),
  n(8,"alpha-mail","Alpha yesterday 1","Older alpha body, yesterday.",now-D-5*H),
  n(9,"beta-chat","Beta earlier 2","Beta body from three days ago.",now-3*D),
  n(10,"beta-chat","Beta earlier 1","Older beta body, three days ago.",now-3*D-2*H),
]
json.dump({"notifications":items},open(sys.argv[1],"w"))
PYEOF
  echo "cc-notif-groups: seeded $NOSD_NOTIF_HISTORY_FILE"
fi

QT_LOGGING_RULES="${NOSD_QT_LOGGING:-}" qs -p "$REPO" > "$LOG" 2>&1 &
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
    # Keep a second workspace alive (occupied but unfocused) so the Workspace
    # widget has more than one square to draw — a bare `swaymsg workspace 2`
    # round-trip would let sway destroy the empty workspace again.
    [ "$A" = "org.gnome.Nautilus" ] && swaymsg "[con_id=$C] move to workspace number 2" 2>/dev/null
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
    # Category mode: nav column + filtered grid; a re-click on the active nav
    # row deselects back to "all" (vinput real click on the 网络 row).
    launcher-category)    call launcher toggle 1.5; shot launcher-category-free
                          call launcher switchDisplayMode 0.6; shot launcher-category-open
                          call launcher selectCategory "Internet" 1.2; shot launcher-category-internet
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          "$VINPUT" vinput click 80 100 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot launcher-category-deselect
                          call launcher switchDisplayMode 0.6
                          call launcher toggle 0.5 ;;
    # Mini mode: floating panel anchored 1 px from the bar, search + results,
    # then the two-level category list via real clicks on the switch row and
    # a bucket row (1920x1080: window left edge ~637, switch row y~990,
    # first bucket row centers ~600/636).
    launcher-mini)        call launcher switchMode mini 1
                          call launcher toggle 1.5; shot launcher-mini-open
                          call launcher setSearchText "chr" 1.2; shot launcher-mini-search
                          call launcher setSearchText "" 0.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          "$VINPUT" vinput click 750 990 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot launcher-mini-categories
                          "$VINPUT" vinput click 750 620 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot launcher-mini-category-apps
                          "$VINPUT" vinput click 750 990 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot launcher-mini-back-list
                          "$VINPUT" vinput click 750 990 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot launcher-mini-back-all
                          call launcher toggle 0.5
                          call launcher switchMode fullscreen 0.8 ;;
    # Dismissal + activation: clicking an app row must launch-and-close,
    # clicking empty wallpaper must retract the launcher (the launcher windows
    # are standalone Top-layer surfaces — the wallpaper MouseArea only sees
    # events while MainScreen's input mask covers the desktop), and the search
    # field must be empty on reopen when clearSearchOnClose is on (default).
    launcher-dismiss)     call launcher switchMode mini 1
                          call launcher toggle 1.5; shot launcher-dismiss-open
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # first app row (~y620 in the 1920x1080 mini window)
                          "$VINPUT" vinput click 800 620 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2; shot launcher-dismiss-appclick
                          # reopen, type a query, click empty wallpaper -> close
                          call launcher toggle 1.5
                          call launcher setSearchText "chr" 1.0
                          shot launcher-dismiss-typed
                          "$VINPUT" vinput click 300 300 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2; shot launcher-dismiss-outside
                          # reopen -> search field must be empty again
                          call launcher toggle 1.5; shot launcher-dismiss-reopen
                          call launcher toggle 0.5
                          # fullscreen: cell click activates (window closes),
                          # margin click on empty canvas retracts too
                          call launcher switchMode fullscreen 1.2
                          call launcher toggle 1.5; shot launcher-dismiss-full
                          "$VINPUT" vinput click 960 400 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2; shot launcher-dismiss-cellclick
                          call launcher toggle 1.5
                          "$VINPUT" vinput click 60 540 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2; shot launcher-dismiss-canvas ;;
    # Exclusive-grab handoff: the fullscreen launcher's top-right settings and
    # power buttons must close the launcher BEFORE their target panel opens,
    # otherwise the new controls sit under an exclusive keyboard grab.
    launcher-handoff)     call launcher toggle 1.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # settings gear, top-right (1920x1080: ~1827,33)
                          "$VINPUT" vinput click 1827 33 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.5; shot launcher-handoff-settings
                          call settings toggle 0.8
                          call launcher toggle 1.5
                          # power button, top-right (~1877,33)
                          "$VINPUT" vinput click 1877 33 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2; shot launcher-handoff-session
                          call sessionMenu toggle 0.5 ;;
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
    # Quick-switch row: inject a real click on the first switch cell
    # (bottom-left of the quick-control strip) and compare before/after.
    cc-switch)            call controlCenter toggle 1.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          qs -p "$REPO" ipc call debug hit opened 1610 1015 > "$WORK/logs/cc-switch-hit.txt" 2>&1 || true
                          shot cc-switch-before
                          "$VINPUT" vinput click 1610 1015 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2
                          shot cc-switch-after
                          qs -p "$REPO" ipc call debug opened 1 > "$WORK/logs/cc-switch-opened.txt" 2>&1 || true
                          call controlCenter toggle 0.5 ;;
    # Page-indicator chevron clicks. The dots row (and thus the chevrons'
    # x) shifts with pageCount — probe the indicator row for the actual
    # NIconButtonHot positions instead of hardcoding x. On 1920x1080 the
    # indicator row sits at y≈1058, centred on the panel at x≈1716.
    cc-page)              call controlCenter toggle 1.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          shot cc-page-0
                          NEXT_X="" PREV_X=""
                          for x in $(seq 1730 4 1900); do
                            qs -p "$REPO" ipc call debug hit opened "$x" 1058 2>/dev/null \
                              | grep -q 'NIconButtonHot' && { NEXT_X=$x; break; }
                          done
                          for x in $(seq 1700 -4 1540); do
                            qs -p "$REPO" ipc call debug hit opened "$x" 1058 2>/dev/null \
                              | grep -q 'NIconButtonHot' && { PREV_X=$x; break; }
                          done
                          echo "cc-page: chevrons at prev=$PREV_X next=$NEXT_X" >> "$WORK/logs/vinput.log"
                          if [ -n "$NEXT_X" ]; then
                            "$VINPUT" vinput click "$NEXT_X" 1058 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0; shot cc-page-1
                            "$VINPUT" vinput click "$NEXT_X" 1058 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0; shot cc-page-2
                          fi
                          if [ -n "$PREV_X" ]; then
                            "$VINPUT" vinput click "$PREV_X" 1058 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0; shot cc-page-back
                          fi
                          call controlCenter toggle 0.5 ;;
    # Volume + brightness slider drags. 1920x1080: volume groove y≈895 (knob
    # starts ~0.4 → x≈1682), brightness groove y≈942 (knob ~1.0 → x≈1885).
    cc-slider)            call controlCenter toggle 1.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          qs -p "$REPO" ipc call debug hit opened 1685 895 > "$WORK/logs/cc-slider-hit.txt" 2>&1 || true
                          qs -p "$REPO" ipc call debug hit opened 1885 942 >> "$WORK/logs/cc-slider-hit.txt" 2>&1 || true
                          shot cc-slider-0
                          "$VINPUT" vinput drag 1685 895 1590 895 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot cc-slider-vol-left
                          "$VINPUT" vinput drag 1595 895 1790 895 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot cc-slider-vol-right
                          "$VINPUT" vinput drag 1885 942 1700 942 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0; shot cc-slider-bri-left
                          call controlCenter toggle 0.5 ;;
    # DDE control center: bell page (3 notifications seeded so the list has content)
    cc-notifications)     notify-send -a nosdshell-verify "Notification one" \
                            "First test body for the history list." 2>/dev/null
                          notify-send -a nosdshell-verify "Notification two" \
                            "Second test body, longer line to check elide." 2>/dev/null
                          notify-send -a nosdshell-verify "Notification three" \
                            "Third body with an action" 2>/dev/null
                          sleep 1; toggle controlCenter notifications 1.5 cc-notifications ;;
    # Multi-app, multi-day grouping exercise. The history file is seeded
    # before qs launches (see the NOSD_NOTIF_HISTORY_FILE block above), so
    # this scene only drives the UI: collapsed buckets → expanded group →
    # swipe-dismiss → clear-all. Anchor items carry objectName markers
    # (notifCard / notifMore / notifClearAll); debug tree prints global
    # coords, so their centres are direct click points.
    cc-notif-groups)      call controlCenter notifications 1.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          notif_pos() {
                            python3 - "$WORK/logs/cc-notif-tree.txt" "$1" <<'PYEOF'
import re,sys
name=sys.argv[2]
for line in open(sys.argv[1],encoding="utf-8",errors="replace"):
    if "hidden" in line:
        continue
    m=re.search(r"@(-?\d+),(-?\d+)",line); w=re.search(r" (\d+)x(\d+) ",line)
    if m and w and ('"%s"' % name) in line:
        print(int(m.group(1))+int(w.group(1))//2, int(m.group(2))+int(w.group(2))//2)
        break
PYEOF
                          }
                          notif_tree() {
                            # The anchors sit ~19 levels deep; the IPC call
                            # occasionally drops its socket mid-write, so give
                            # it a second try before giving up on the marks.
                            for try in 1 2; do
                              qs -p "$REPO" ipc call debug tree cc-HEADLESS-1 20 \
                                > "$WORK/logs/cc-notif-tree.txt" 2>&1 \
                                && grep -q notifCard "$WORK/logs/cc-notif-tree.txt" && return 0
                              sleep 0.5
                            done
                            return 1
                          }
                          notif_tree
                          shot cc-notif-groups
                          # Expand the first collapsed group via "还有 N 条".
                          MORE=$(notif_pos notifMore)
                          if [ -n "$MORE" ]; then
                            qs -p "$REPO" ipc call debug hit opened $MORE >> "$WORK/logs/cc-notif-hit.txt" 2>&1 || true
                            "$VINPUT" vinput click $MORE 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            notif_tree
                            shot cc-notif-group-open
                          else
                            echo "cc-notif-groups: no collapsed group found" >> "$WORK/logs/vinput.log"
                          fi
                          # Swipe-dismiss the first visible card: a horizontal
                          # drag well past max(110, 30% width).
                          CARD=$(notif_pos notifCard)
                          if [ -n "$CARD" ]; then
                            set -- $CARD
                            "$VINPUT" vinput drag "$1" "$2" "$(( $1 + 320 ))" "$2" \
                              2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot cc-notif-swiped
                          else
                            echo "cc-notif-groups: no notifCard found" >> "$WORK/logs/vinput.log"
                          fi
                          # Clear-all empties the list; the header row hides.
                          # The list is bottom-anchored, so every removal moves
                          # ALL rows — re-dump the tree for fresh coords.
                          notif_tree
                          CLEAR=$(notif_pos notifClearAll)
                          if [ -n "$CLEAR" ]; then
                            qs -p "$REPO" ipc call debug hit opened $CLEAR >> "$WORK/logs/cc-notif-hit.txt" 2>&1 || true
                            "$VINPUT" vinput click $CLEAR 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot cc-notif-cleared
                          else
                            echo "cc-notif-groups: no notifClearAll found" >> "$WORK/logs/vinput.log"
                          fi
                          call controlCenter toggle 0.5 ;;
    # quick-control pages: open the frame, select the page, shoot, close
    cc-quick-*)           local p="${1#cc-quick-}"
                          call controlCenter open 1.5
                          call controlCenter quickPage "$p" 1.2
                          shot "$1"
                          call controlCenter toggle 0.5 ;;
    # Geometry forensics: dump the painted scene tree (global bounds of every
    # item) on the cards page and on the Wi-Fi page, so notification-to-strip
    # gaps can be read off element edges rather than guessed from pixels.
    cc-geom)              notify-send -a nosdshell-verify "Notification one" \
                            "First test body for the history list." 2>/dev/null
                          notify-send -a nosdshell-verify "Notification two" \
                            "Second test body, longer line to check elide." 2>/dev/null
                          notify-send -a nosdshell-verify "Notification three" \
                            "Third body with an action" 2>/dev/null
                          sleep 1
                          call controlCenter open 1.5
                          qs -p "$REPO" ipc call debug opened 40 > "$WORK/logs/cc-geom-cards.txt" 2>&1 || true
                          call controlCenter quickPage wifi 1.2
                          qs -p "$REPO" ipc call debug opened 40 > "$WORK/logs/cc-geom-wifi.txt" 2>&1 || true
                          call controlCenter quickPage basic 1.2
                          call controlCenter quickPage cards 1.2
                          qs -p "$REPO" ipc call debug opened 40 > "$WORK/logs/cc-geom-back2cards.txt" 2>&1 || true
                          shot cc-geom
                          call controlCenter toggle 0.5 ;;
    # Collapse chevron, bottom-right corner: one constant screen position
    # folds the strip to the indicator band and re-expands it. Probe the
    # corner for the plain NIconButton (the page chevrons are
    # NIconButtonHot) like cc-page does; on 1920x1080 it lands ~x1900,y1058.
    cc-collapse)          call controlCenter open 1.5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          COLLAPSE_X=""
                          for x in $(seq 1900 -4 1840); do
                            qs -p "$REPO" ipc call debug hit opened "$x" 1058 2>/dev/null \
                              | grep -q 'NIconButton_' && { COLLAPSE_X=$x; break; }
                          done
                          qs -p "$REPO" ipc call debug hit opened "${COLLAPSE_X:-1900}" 1058 > "$WORK/logs/cc-collapse-hit.txt" 2>&1 || true
                          shot cc-collapse-before
                          if [ -n "$COLLAPSE_X" ]; then
                            "$VINPUT" vinput click "$COLLAPSE_X" 1058 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0; shot cc-collapse-collapsed
                            # Same coordinates must expand it again — the button
                            # does not move between states.
                            "$VINPUT" vinput click "$COLLAPSE_X" 1058 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0; shot cc-collapse-expanded
                          fi
                          call controlCenter toggle 0.5 ;;
    settings)             call settings open 2; shot settings; call settings toggle 0.5 ;;
    # Forensics: open the all-settings page in the frame, dump the paint-order
    # scene tree, then inject REAL pointer events (zwlr_virtual_pointer via
    # tools/nosd-helpers vinput) at the rail column: hit-test probe -> click ->
    # jitter-click -> screenshot. If a click lands, the scrolled module header
    # in settings-click.png differs from settings-tree.png.
    settings-tree)        call settings openTab general 5
                          shot settings-tree
                          swaymsg -t get_outputs > "$WORK/logs/sway-outputs.json" 2>&1
                          qs -p "$REPO" ipc call debug list > "$WORK/logs/cc-roots.txt" 2>&1
                          qs -p "$REPO" ipc call debug opened 16 > "$WORK/logs/cc-tree.txt" 2>&1
                          echo "tree → $WORK/logs/cc-tree.txt"
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          if [ -x "$VINPUT" ]; then
                            for y in 105 159 213 267 321; do
                              qs -p "$REPO" ipc call debug hit opened 1540 "$y" >> "$WORK/logs/cc-hit.txt" 2>&1 || true
                            done
                            # The rail delegates are 56x34 cells on a ~54 px
                            # stride — the old fixed row (105/159/…) lands in
                            # the 20 px gaps between cells and never reaches a
                            # delegate. Probe down the column, collect every
                            # delegate-centre hit, and click a mid-list module
                            # (idx 8, sound): idx 0 would be a no-op — it is
                            # already the selected module at scroll top.
                            RAIL_HITS=()
                            for y in $(seq 64 2 1040); do
                              HIT_OUT=$(qs -p "$REPO" ipc call debug hit opened 1540 "$y" 2>/dev/null || true)
                              echo "$HIT_OUT" >> "$WORK/logs/cc-hit.txt"
                              echo "$HIT_OUT" | tail -1 | grep -q 'QQuickMouseArea.*56x34' && RAIL_HITS+=("$y")
                            done
                            # One centre per cell: hits repeat along a cell's
                            # height, so dedupe by stepping across each run.
                            RAIL_CENTERS=()
                            prev=-99
                            for y in "${RAIL_HITS[@]}"; do
                              [ $((y - prev)) -gt 10 ] && RAIL_CENTERS+=("$((y + 14))")
                              prev=$y
                            done
                            RAIL_Y="${RAIL_CENTERS[8]:-${RAIL_CENTERS[-1]:-267}}"
                            echo "rail delegate hit at y: $RAIL_Y (centers: ${RAIL_CENTERS[*]})" >> "$WORK/logs/cc-hit.txt"
                            "$VINPUT" vinput click 1540 "$RAIL_Y" 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot settings-click
                            # Guard against select-but-never-scroll: the rail
                            # must move the module content, not only the
                            # highlight. Assert both the flickable's real
                            # contentY (describe prints it) and content-region
                            # pixels — the rail column is outside the region.
                            qs -p "$REPO" ipc call debug opened 16 > "$WORK/logs/cc-tree-after-click.txt" 2>&1 || true
                            if ! { grep -v hidden "$WORK/logs/cc-tree-after-click.txt" | grep -Eq "interactive:true contentY:[1-9][0-9]{2,}/"; }; then
                              echo "FAIL settings-tree: rail click did not scroll content (contentY ~0)"
                              SCENE_FAIL=1
                            fi
                            python3 - "$OUT/settings-tree.png" "$OUT/settings-click.png" >> "$WORK/logs/cc-hit.txt" 2>&1 <<'PYEOF' || SCENE_FAIL=1
from PIL import Image, ImageChops
import sys
# Region = module content only (below the banner zone, right of the rail).
a = Image.open(sys.argv[1]).convert('RGB')
b = Image.open(sys.argv[2]).convert('RGB')
box = (1600, 300, min(a.size[0], b.size[0], 1900), min(a.size[1], b.size[1], 1000))
d = ImageChops.difference(a.crop(box), b.crop(box))
n = sum(1 for p in d.getdata() if p != (0, 0, 0))
print("rail-click content-region diff pixels:", n)
if n < 5000:
    print("FAIL settings-tree: content identical after rail click")
    sys.exit(1)
PYEOF
                            "$VINPUT" vinput jclick 1540 "${RAIL_CENTERS[2]:-105}" 2 2 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot settings-jclick
                            # Branch test: click outside the panel. If the
                            # panel closes the whole injection path works and
                            # the rail alone is broken; if it stays open the
                            # injector itself is at fault.
                            qs -p "$REPO" ipc call debug hit opened 400 400 >> "$WORK/logs/cc-hit.txt" 2>&1 || true
                            qs -p "$REPO" ipc call debug hit main-HEADLESS-1 400 400 >> "$WORK/logs/cc-hit.txt" 2>&1 || true
                            "$VINPUT" vinput click 400 400 2>>"$WORK/logs/vinput.log" || true
                            sleep 1
                            shot settings-outside-click
                            qs -p "$REPO" ipc call debug opened 1 > "$WORK/logs/cc-after-outside.txt" 2>&1 || true
                          else
                            echo "vinput binary missing: cargo build --release --manifest-path tools/nosd-helpers/Cargo.toml"
                          fi
                          call settings toggle 0.5 ;;
    # settings-scroll-<tab>: page-long tabs don't fit the ~980 px viewport —
    # inject real wheel scrolls through the module view and shot each step.
    settings-scroll-*)    local tab="${1#settings-scroll-}"
                          call settings openTab "$tab" 5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          shot "settings-scroll-${tab}-0"
                          # Wheel over row padding (x 1600), not at x 1750 —
                          # that lands on combo/spin fields which eat the axis.
                          qs -p "$REPO" ipc call debug hit opened 1600 540 >> "$WORK/logs/scroll-hit.txt" 2>&1 || true
                          qs -p "$REPO" ipc call debug hit opened 1750 540 >> "$WORK/logs/scroll-hit.txt" 2>&1 || true
                          for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
                            "$VINPUT" vinput scroll 1600 540 720 2>/dev/null || true
                            sleep 1.0
                            shot "settings-scroll-${tab}-${i}"
                          done
                          call settings toggle 2 ;;
    # Live theme-switch with settings open: catches stale/leftover regions at
    # the panel edges that a fresh-open screenshot can't.
    settings-themeswitch) call settings openTab general 3
                          qs -p "$REPO" ipc call debug list > "$WORK/logs/ts-roots.txt" 2>&1
                          qs -p "$REPO" ipc call debug tree cc-HEADLESS-1 10 > "$WORK/logs/ts-tree.txt" 2>&1
                          qs -p "$REPO" ipc call debug tree cc-HEADLESS-1 40 >> "$WORK/logs/ts-tree.txt" 2>&1 || true
                          swaymsg -t get_tree > "$WORK/logs/sway-tree.json" 2>&1
                          for x in 1445 1460 1480 1500; do
                            for y in 150 400 650; do
                              qs -p "$REPO" ipc call debug hit main-HEADLESS-1 $x $y >> "$WORK/logs/ts-hit.txt" 2>&1 || true
                              qs -p "$REPO" ipc call debug hit cc-HEADLESS-1 $x $y >> "$WORK/logs/ts-hit.txt" 2>&1 || true
                            done
                          done
                          qs -p "$REPO" ipc call debug tree main-HEADLESS-1 8 > "$WORK/logs/ts-main-tree.txt" 2>&1
                          call colorScheme set Gruvbox 2; shot themeswitch-gruv
                          call colorScheme set Deepin 2; shot themeswitch-deepin
                          call colorScheme set Gruvbox 2; shot themeswitch-gruv2
                          call settings toggle 2 ;;
    # settings search end-to-end: inject text via `debug set` (vinput has no
    # keyboard), shot the dropdown, hit-test + real-click the first result.
    settings-search)      call settings openTab general 3
                          qs -p "$REPO" ipc call debug set cc-HEADLESS-1 settingsSearchInput text 夜间 >> "$WORK/logs/search.log" 2>&1
                          sleep 0.5
                          shot settings-search-results
                          qs -p "$REPO" ipc call debug hit cc-HEADLESS-1 1700 115 >> "$WORK/logs/search.log" 2>&1 || true
                          qs -p "$REPO" ipc call debug hit cc-HEADLESS-1 1700 150 >> "$WORK/logs/search.log" 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          if [ -x "$VINPUT" ]; then
                            "$VINPUT" vinput click 1700 115 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot settings-search-clicked
                            # The edge-sheet scrim must stay non-interactive:
                            # a click beside the frame still closes the panel.
                            "$VINPUT" vinput click 800 500 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot settings-search-outside
                          fi
                          call settings toggle 1 ;;
    # ComboBox popup on a settings page: find the first combo field by its
    # caret glyph (the row position scrolls between runs), real-click it open,
    # shoot the popup — the menu surface must stay opaque over page text and
    # rows must not clip.
    settings-combo)       call settings openTab colorscheme 3
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          shot settings-combo-page
                          COMBO_Y=$(python3 - "$OUT/settings-combo-page.png" 2>>"$WORK/logs/caret-scan.log" <<'PYEOF'
from PIL import Image
import sys
im = Image.open(sys.argv[1]).convert('RGB')
# The caret is a small light glyph ~12px left of the field's right edge.
# A field row counts when >=3 bright pixels cluster within a 12px window.
for y in range(180, 800):
    hits = sum(1 for x in range(1878, 1904)
               if all(c > 110 for c in im.getpixel((x, y))))
    if hits >= 3:
        print(y + 4)
        break
PYEOF
)
                          echo "combo field caret at y: $COMBO_Y"
                          if [ -n "$COMBO_Y" ] && [ -x "$VINPUT" ]; then
                            "$VINPUT" vinput click 1795 $COMBO_Y 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot settings-combo-popup
                          fi
                          call settings toggle 1 ;;
    # Same as settings-combo but for the LAST combo on the colorscheme page
    # (调色板生成方法) — a combo near the bottom of a scrolled module view is
    # where popup placement/width bugs show up.
    settings-combo-scheme) call settings openTab colorscheme 8
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # No manual scrolls here: the module view stacks ALL
                          # modules in one column and openTab already scrolls to
                          # the colorscheme section — extra scrolls overshoot
                          # into neighbouring modules. The section lands with
                          # the gated combos near the fold; enabling 使用壁纸
                          # 颜色 (the real user's config) brings the scheme
                          # method combo alive. Field bands: ~30 px runs of
                          # field fill (~76 lum disabled, ~98 enabled) down the
                          # caret column; a card's ✓ badge sits on much darker
                          # card bg (~30) so it can't fake a field. x1860 sits
                          # left of the caret so the glyph can't split the band.
                          shot settings-combo-scheme-page
                          fields() { python3 - "$1" <<'PYEOF'
from PIL import Image
import sys
im = Image.open(sys.argv[1]).convert('RGB')
runs, start = [], None
for y in range(180, 900):
    lum = sum(im.getpixel((1860, y))) / 3
    infield = 71 < lum < 110
    if infield and start is None:
        start = y
    elif not infield and start is not None:
        runs.append((start, y - 1)); start = None
out = []
for r in runs:
    if not 15 <= r[1] - r[0] <= 45:
        continue
    cy = (r[0] + r[1]) // 2
    # enabled field: caret or value text is bright; disabled dims to ~140
    caret = max(max(im.getpixel((x, y))) for x in range(1868, 1892)
                for y in range(cy - 4, cy + 5))
    text = max(max(im.getpixel((x, y))) for x in range(1765, 1805)
               for y in range(cy - 4, cy + 5))
    out.append((cy, caret > 170 or text > 190))
print(",".join("%d:%d" % (cy, en) for cy, en in out))
PYEOF
                          }
                          FIELDS=$(fields "$OUT/settings-combo-scheme-page.png")
                          echo "scheme fields: $FIELDS"
                          GATED_TOP=$(python3 - "$OUT/settings-combo-scheme-page.png" <<'PYEOF' 2>>"$WORK/logs/caret-scan.log"
from PIL import Image
import sys
im = Image.open(sys.argv[1]).convert('RGB')
runs, start = [], None
for y in range(180, 900):
    lum = sum(im.getpixel((1860, y))) / 3
    infield = 71 < lum < 110
    if infield and start is None:
        start = y
    elif not infield and start is not None:
        runs.append((start, y - 1)); start = None
found = [r for r in runs if 15 <= r[1] - r[0] <= 45]
# The gated combos are the two DISABLED bands; other enabled fields (e.g.
# 深色模式计划) may sit above them. The toggle lives one row above the
# first disabled band.
dis = [r for r in found if r[0] > 430]
print(dis[0][0] if dis else "")
PYEOF
)
                          # The toggle persists across runs, so only flip it
                          # when the gated fields are actually still disabled —
                          # otherwise the click would turn the feature OFF.
                          GATED_OFF=$(echo "$FIELDS" | tr ',' '\n' | awk -F: '$1 > 430 && $2 == 0' | head -1)
                          if [ -n "$GATED_TOP" ] && [ -n "$GATED_OFF" ] && [ -x "$VINPUT" ]; then
                            # The 使用壁纸颜色 toggle row sits one row (~64 px)
                            # directly above the FIRST gated combo field; aim at
                            # the switch itself (row right edge) — the far-left
                            # label area can sit outside the row's click area.
                            "$VINPUT" vinput click 1870 $((GATED_TOP - 64)) 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot settings-combo-scheme-enabled
                            FIELDS=$(fields "$OUT/settings-combo-scheme-enabled.png")
                            echo "after toggle: $FIELDS"
                          fi
                          # Click the LAST enabled field — once the toggle is on
                          # that is the 调色板生成方法 combo at the bottom of the
                          # section, the case the user reported. Enabling
                          # wallpaper colors triggers an async theme regen, so
                          # the first click can land mid-reflow: check for the
                          # field's accent focus border (popup open = focused)
                          # and retry once.
                          COMBO_Y=$(python3 -c "
import sys
last=[p for p in '$FIELDS'.split(',') if p.endswith(':1')]
print(last[-1].split(':')[0] if last else '')" )
                          if [ -n "$COMBO_Y" ] && [ -x "$VINPUT" ]; then
                            popup_open() { python3 - "$1" "$2" <<'PYEOF'
from PIL import Image
import sys
im, cy = Image.open(sys.argv[1]).convert('RGB'), int(sys.argv[2])
# accent border around the field rect: scan a band around its top/bottom
# edges (field ~30 px tall, border 1-2 px) for a long run of accent pixels
# (verify accent ≈ 255,182,135 — R>G>B peach).
acc = lambda p: p[0] > 180 and 120 < p[1] < 215 and p[2] < 170 and p[0] > p[1] > p[2]
for dy in range(-22, 23):
    if sum(1 for x in range(1650, 1900) if acc(im.getpixel((x, cy + dy)))) > 80:
        print("yes"); sys.exit()
print("")
PYEOF
                            }
                            "$VINPUT" vinput click 1810 $COMBO_Y 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot settings-combo-scheme-popup
                            if [ -z "$(popup_open "$OUT/settings-combo-scheme-popup.png" "$COMBO_Y")" ]; then
                              "$VINPUT" vinput click 1810 $COMBO_Y 2>>"$WORK/logs/vinput.log" || true
                              sleep 1.0
                              shot settings-combo-scheme-popup
                            fi
                          fi
                          call settings toggle 1 ;;
    # A fullscreen window must fully release the dock strip: the dock slides
    # off AND its Overlay-layer surface must stop claiming input there.
    # Probe dockContainer's scene position (off-surface = slid), then inject a
    # real click where the dock was — if the strip still owns input, the click
    # can wake the dock (dockHovered) instead of reaching the fullscreen app.
    # NOTE: sway/niri refuse fullscreen on floating containers — the spawned
    # verify windows are floated, so un-float the focused one first.
    dock-fullscreen)      swaymsg floating disable 2>/dev/null
                          swaymsg fullscreen enable 2>/dev/null
                          sleep 1.5
                          swaymsg -t get_tree > "$WORK/logs/dock-fs-sway-tree.json" 2>&1 || true
                          shot dock-fs-off
                          qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 4 > "$WORK/logs/dock-fs-tree.txt" 2>&1 || true
                          qs -p "$REPO" ipc call debug hit dock-HEADLESS-1 960 1050 >> "$WORK/logs/dock-fs-hit.txt" 2>&1 || true
                          qs -p "$REPO" ipc call debug hit main-HEADLESS-1 960 1050 >> "$WORK/logs/dock-fs-hit.txt" 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          if [ -x "$VINPUT" ]; then
                            "$VINPUT" vinput click 960 1050 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot dock-fs-click
                          fi
                          swaymsg fullscreen disable 2>/dev/null
                          swaymsg floating enable 2>/dev/null ;;
    # Pages group (control-center settings): the module view stacks the
    # sub-tabs vertically (NTabView.stacked — no inner tab strip to click),
    # so scroll the module column until the 页面 group comes into view.
    settings-launcher)    call settings openTab launcher 5
                          shot settings-launcher ;;
    settings-cc-pages)    call settings openTab controlcenter 5
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          for i in 1 2 3 4; do
                            "$VINPUT" vinput scroll 1700 540 60 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.6
                            shot "settings-cc-pages-$i"
                          done
                          call settings toggle 2 ;;
    # settings-subpage — §3.5.3 guardrail: the 配置插件 rows must push the
    # widgets editor as a 二级页 (slide in from the right, header retitles,
    # back pops) instead of toggling an inline collapsible block. Off the
    # default set — needs its own seed because the 状态栏 group renders only
    # when the status bar is on, and the per-monitor row needs an enabled
    # screen override:
    #   {"bar":{"enabled":true,
    #           "screenOverrides":[{"name":"HEADLESS-1","enabled":true}]}}
    #   ./verify.sh <run> --settings <seed>.json --scenes settings-subpage
    settings-subpage)    call settings openTab dock/1 5
                         shot settings-subpage-row
                         VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                         [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                         SROOT=cc-HEADLESS-1
                         # `debug find` walks the whole subtree by objectName
                         # (no depth cap, no coordinate probing) and returns
                         # describe(): "<type> WxH @x,y" in scene coords — on
                         # the single 1920 output that equals screen coords.
                         fxy() { # <objectName> → "cx cy" screen centre, or ""
                           local d w h x y
                           d=$(qs -p "$REPO" ipc call debug find "$SROOT" "$1" 2>/dev/null)
                           echo "$1 → $d" >> "$WORK/logs/subpage-find.txt"
                           case "$d" in *hidden*|*"no item"*) return;; esac
                           read w h x y < <(echo "$d" | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\) @\([0-9][0-9]*\),\([0-9][0-9]*\).*/\1 \2 \3 \4/p')
                           [ -n "${x:-}" ] && echo $((x + w / 2)) $((y + h / 2))
                         }
                         read RX RY < <(fxy nextPage-barWidgets)
                         if [ -z "${RX:-}" ]; then
                           echo "FAIL settings-subpage: next-page row not found (bar.enabled seeded?)"
                           SCENE_FAIL=1
                         else
                           "$VINPUT" vinput click "$RX" "$RY" 2>>"$WORK/logs/vinput.log" || true
                           sleep 1.2
                           shot settings-subpage-page
                           PG=$(qs -p "$REPO" ipc call debug find "$SROOT" widgetsEditorPage 2>/dev/null)
                           echo "widgetsEditorPage → $PG" >> "$WORK/logs/subpage-find.txt"
                           case "$PG" in *@*) : ;; *)
                             echo "FAIL settings-subpage: click did not push the widgets editor"
                             SCENE_FAIL=1 ;; esac
                           # §3.5.3: back pops the page instead of closing.
                           read BX BY < <(fxy settingsBack)
                           if [ -n "${BX:-}" ]; then
                             "$VINPUT" vinput click "$BX" "$BY" 2>>"$WORK/logs/vinput.log" || true
                             sleep 1.0
                             shot settings-subpage-back
                             GONE=$(qs -p "$REPO" ipc call debug find "$SROOT" settingsSubpage 2>/dev/null)
                             echo "settingsSubpage after back → $GONE" >> "$WORK/logs/subpage-find.txt"
                             case "$GONE" in *"no item"*) : ;; *)
                               echo "FAIL settings-subpage: back did not pop the page"
                               SCENE_FAIL=1 ;; esac
                           else
                             echo "FAIL settings-subpage: header back button not found"
                             SCENE_FAIL=1
                           fi
                           # Per-monitor row on dock/2 (seeded override → visible).
                           call settings openTab dock/2 4
                           read MX MY < <(fxy nextPage-monitorWidgets-HEADLESS-1)
                           if [ -n "${MX:-}" ]; then
                             "$VINPUT" vinput click "$MX" "$MY" 2>>"$WORK/logs/vinput.log" || true
                             sleep 1.2
                             shot settings-subpage-monitor
                             qs -p "$REPO" ipc call debug find "$SROOT" widgetsEditorPage 2>/dev/null \
                               | grep -q "@" \
                               || { echo "FAIL settings-subpage: monitor row did not push its editor"; SCENE_FAIL=1; }
                             [ -n "${BX:-}" ] && "$VINPUT" vinput click "$BX" "$BY" 2>>"$WORK/logs/vinput.log" || true
                             sleep 0.6
                           else
                             echo "settings-subpage: no monitor row (screenOverrides seeded?) — skipped"
                           fi
                         fi
                         call settings toggle 0.5 ;;
    # settings-reset — the "重置为默认值" button every settings dialog now
    # carries (common.reset-to-default), driven over four storage paths:
    #   1. dock plugin instance   dock/3 gear → BarWidgetSettingsDialog
    #      (setDockPluginSettings replace — the seed value must not survive)
    #   2. bar widget instance    dock/1 → nextPage → left-section gear
    #      (same dialog, section write path)
    #   3. plugin-owned settings  plugins/0 gear → NPluginSettingsPopup →
    #      plugins/testreset/settings.json must equal manifest defaults
    #      exactly (stale seeded keys dropped, not merged)
    #   4. desktop widget         desktopwidgets gear →
    #      DesktopWidgetSettingsDialog → monitorWidgets entry rebuilt as
    #      {id,x,y,scale} + metadata defaults (geometry preserved)
    # Off the default set — needs a seed putting non-default Clock values on
    # the three settings.json paths; the testreset plugin fixture is written
    # by this script before qs starts (PluginRegistry scans plugins once):
    #   {"bar":{"enabled":true,
    #           "widgets":{"left":[{"id":"Launcher"},
    #                      {"id":"Clock","clockColor":"primary","lineSpacing":9}]}},
    #    "dock":{"plugins":[{"id":"Clock","clockColor":"primary","lineSpacing":9}]},
    #    "desktopWidgets":{"enabled":true,"monitorWidgets":[{"name":"HEADLESS-1",
    #      "widgets":[{"id":"Clock","x":123,"y":45,"scale":1.5,
    #                  "clockStyle":"analog","clockColor":"primary",
    #                  "staleKey":"x"}]}]}}
    #   ./verify.sh <run> --settings <seed>.json --scenes settings-reset
    settings-reset)      VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                         [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                         SROOT=cc-HEADLESS-1
                         SF="$(echo "$NOSD_CONFIG_DIR" | sed 's:/$::')/settings.json"
                         fxy() { # <objectName> → "cx cy" screen centre, or ""
                           local d w h x y
                           # Dialog buttons live on the popupMenuWindow surface
                           # (dialogs are hosted there for the blur region);
                           # editor tiles live under the cc panel root.
                           for r in "$SROOT" popupMenuWindow-HEADLESS-1; do
                             d=$(qs -p "$REPO" ipc call debug find "$r" "$1" 2>/dev/null)
                             echo "$r $1 → $d" >> "$WORK/logs/reset-find.txt"
                             case "$d" in *hidden*|*"no item"*|"") ;; *) break;; esac
                           done
                           case "$d" in *hidden*|*"no item"*|"") return;; esac
                           read w h x y < <(echo "$d" | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\) @\([0-9][0-9]*\),\([0-9][0-9]*\).*/\1 \2 \3 \4/p')
                           [ -n "${x:-}" ] && echo $((x + w / 2)) $((y + h / 2))
                         }
                         # Assert the on-disk Clock entry is back to defaults:
                         # seeded clockColor/lineSpacing must be gone. FileView
                         # flushes late — poll the file for a few seconds.
                         reset_assert() { # <dock|bar>
                           local i
                           for i in 1 2 3 4 5 6; do
                             python3 - "$SF" "$1" <<'PYEOF' && return 0
import json,sys
d=json.load(open(sys.argv[1]))
where=sys.argv[2]
if where=="dock":
    cand=[w for w in d.get("dock",{}).get("plugins",[]) if w.get("id")=="Clock"]
elif where=="cc":
    cand=[w for w in d.get("controlCenter",{}).get("shortcuts",{}).get("left",[]) if w.get("id")=="CustomButton"]
elif where=="desktop":
    mw=d.get("desktopWidgets",{}).get("monitorWidgets",[])
    cand=[]
    for m in mw:
        cand += [w for w in m.get("widgets",[]) if w.get("id")=="Clock"]
else:
    cand=[w for w in d.get("bar",{}).get("widgets",{}).get("left",[]) if w.get("id")=="Clock"]
if not cand:
    sys.exit(1)
e=cand[0]
bad=[k for k,v in e.items() if k=="clockColor" and v!="none"]
if where=="cc":
    # CustomButton default icon is "heart"; the seeded stale key must be gone.
    if e.get("icon")!="heart" or "staleKey" in e:
        bad.append("cc")
elif where=="desktop":
    # Desktop Clock defaults: digital style; geometry must survive the reset.
    if e.get("clockStyle")!="digital" or e.get("x")!=123 or e.get("y")!=45 or e.get("scale")!=1.5 or "staleKey" in e:
        bad.append("desktop")
else:
    if e.get("lineSpacing")!=2:
        bad.append("lineSpacing")
print("settings-reset %s entry: %s" % (where, json.dumps(e)))
sys.exit(1 if bad else 0)
PYEOF
                             sleep 1
                           done
                           echo "FAIL settings-reset: Clock entry not reset on disk ($1)"
                           SCENE_FAIL=1
                         }
                         # Plugin-owned settings live in their own file — assert
                         # it ends up exactly equal to the manifest defaults
                         # (stale keys dropped, not merged).
                         plugin_assert() {
                           local i pf="$(echo "$NOSD_CONFIG_DIR" | sed 's:/$::')/plugins/testreset/settings.json"
                           for i in 1 2 3 4 5 6; do
                             python3 - "$pf" <<'PYEOF' && return 0
import json,sys
e=json.load(open(sys.argv[1]))
want={"accent":"red","level":1,"notes":"default-note"}
print("settings-reset plugin entry: %s" % json.dumps(e))
sys.exit(0 if e==want else 1)
PYEOF
                             sleep 1
                           done
                           echo "FAIL settings-reset: plugin settings not reset on disk"
                           SCENE_FAIL=1
                         }
                         dialog_reset() { # <gearName> <resetName> <closeName> <label>
                           local gname="$1" rname="$2" cname="$3" tag="$4" gx gy bx by cx cy i
                           # Delegates incubate lazily — retry the find.
                           for i in 1 2 3 4; do
                             read gx gy < <(fxy "$gname")
                             [ -n "${gx:-}" ] && break
                             sleep 1
                           done
                           if [ -z "${gx:-}" ]; then
                             echo "FAIL settings-reset: gear not found: $gname ($tag)"
                             SCENE_FAIL=1; return
                           fi
                           "$VINPUT" vinput click "$gx" "$gy" 2>>"$WORK/logs/vinput.log" || true
                           sleep 1.2
                           shot "settings-reset-$tag-dialog"
                           read bx by < <(fxy "$rname")
                           if [ -z "${bx:-}" ]; then
                             echo "FAIL settings-reset: reset button not found ($tag)"
                             SCENE_FAIL=1; return
                           fi
                           "$VINPUT" vinput click "$bx" "$by" 2>>"$WORK/logs/vinput.log" || true
                           sleep 1.2
                           shot "settings-reset-$tag-done"
                           # Modal blocks the next navigation — close it.
                           read cx cy < <(fxy "$cname")
                           [ -n "${cx:-}" ] && "$VINPUT" vinput click "$cx" "$cy" 2>>"$WORK/logs/vinput.log" || true
                           sleep 0.6
                         }
                         # Path 1: dock plugin instance (PluginsSubTab gear →
                         # BarWidgetSettingsDialog; both modes now use the
                         # sectioned editor whose plugins zone is "right", the
                         # write still lands on dock.plugins).
                         call settings openTab dock/3 5
                         dialog_reset widgetGear-right-Clock widgetSettingsReset widgetSettingsClose dock
                         reset_assert dock || SCENE_FAIL=1
                         # Path 2: bar widget instance on the pushed 二级页.
                         call settings openTab dock/1 4
                         read px py < <(fxy nextPage-barWidgets)
                         [ -n "${px:-}" ] && "$VINPUT" vinput click "$px" "$py" 2>>"$WORK/logs/vinput.log" || true
                         sleep 1.2
                         dialog_reset widgetGear-left-Clock widgetSettingsReset widgetSettingsClose bar
                         reset_assert bar || SCENE_FAIL=1
                         # Path 3: plugin-owned settings (installed-plugin gear →
                         # NPluginSettingsPopup → plugins/<id>/settings.json).
                         call settings openTab plugins/0 5
                         dialog_reset pluginSettingsGear-testreset pluginSettingsReset pluginSettingsClose plugin
                         plugin_assert || SCENE_FAIL=1
                         # Path 4: desktop widget instance — settings fields go
                         # back to metadata defaults while x/y/scale survive.
                         call settings openTab desktopwidgets 5
                         dialog_reset widgetGear-HEADLESS-1-Clock widgetSettingsReset widgetSettingsClose desktop
                         reset_assert desktop || SCENE_FAIL=1
                         # Path 5: control-center shortcut widget (CustomButton)
                         # → controlCenter.shortcuts.left entry.
                         call settings openTab controlcenter/1 5
                         dialog_reset widgetGear-left-CustomButton widgetSettingsReset widgetSettingsClose cc
                         reset_assert cc || SCENE_FAIL=1
                         call settings toggle 0.5 ;;
    # settings-<tab> or settings-<tab>/<sub>: subtab names go through IPC
    # openTab ("tab/sub"); the shot filename flattens the slash.
    settings-*)           call settings openTab "${1#settings-}" 5; shot "$(echo "$1" | tr '/' '_')"; call settings toggle 2 ;;
    session-menu)         toggle sessionMenu toggle 1.5 session-menu ;;
    notification)         notify-send -a nosdshell-verify "Baseline notification" \
                            "This is the default notification look." 2>/dev/null
                          sleep 0.8; shot notification ;;
    # Monochrome app icon on the bubble: *-symbolic sources are tinted to the
    # tile ink (ThemeIcons.isSymbolicPath); other artwork renders untouched.
    notification-icon)    notify-send -a nosdshell-verify -i "$REPO/Scripts/test/assets/audio-volume-high-symbolic.png" \
                            "Symbolic icon" "Monochrome *-symbolic app icon on the tile." 2>/dev/null
                          sleep 0.8; shot notification-icon
                          notify-send -a nosdshell-verify -i "$REPO/Scripts/test/assets/audio-volume-high-symbolic.png" \
                            "Symbolic icon 2" "Second symbolic send after a live popup." 2>/dev/null
                          sleep 0.8; shot notification-icon-2
                          notify-send -a nosdshell-verify -i "$REPO/Assets/DDE/gxde-control-center/src/frame/modules/accounts/themes/dark/icons/nav_accounts.svg" \
                            "White artwork" "Non-symbolic artwork stays raw (negative control)." 2>/dev/null
                          sleep 0.8; shot notification-icon-art ;;
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
    # Image + 3-line body on one bubble; 5 captures ~0.6 s apart prove the
    # drop shadow stays put (an NDropShadow inside its own source fed back
    # frame to frame and the shape drifted).
    notification-shadow)  notify-send -a nosdshell-verify -i "$REPO/Scripts/test/assets/audio-volume-high-symbolic.png" \
                          "Tall notification" "第一行 第一行 第一行 第一行 第一行 第一行 第一行"$'\n'"第二行 第二行 第二行 第二行 第二行 第二行 第二行"$'\n'"第三行 第三行 第三行 第三行 第三行 第三行" 2>/dev/null
                          sleep 0.8
                          for i in 1 2 3 4 5; do shot "notification-shadow-$i"; sleep 0.6; done ;;
    # DND toggles write Settings -> onSettingsSaved; the notification server
    # must survive that save (it used to destroy+recreate and race the bus
    # name, cua P4). The notify-send afterwards proves the name is still held.
    notification-resave)  call notifications enableDND 1.2
                          call notifications disableDND 1.2
                          notify-send -a nosdshell-verify "After settings save" \
                            "Server must still own org.freedesktop.Notifications." 2>/dev/null
                          sleep 0.8; shot notification-resave ;;
    toast)                call toast send '{"title":"Toast 标题","body":"这是 toast 正文","type":"notice"}' 1.5
                          shot toast ;;
    audio-panel)          toggle volume togglePanel 1.5 audio-panel ;;
    # Bounded-list guardrail: the Wi‑Fi list viewport must size from the
    # content column's implicit height and stay capped at
    # Style.popupListMaxHeight — never equal to the full content extent and
    # never the ~12 px sliver the flickable's -1 auto-mode produced on first
    # open. The first `debug opened` poll lands inside the first layout
    # passes, so a regression surfaces in network-panel-early.txt; the settled
    # dump additionally shows the capped viewport vs taller content.
    network-panel)        cat > "$WORK/netgeom.py" <<'PYEOF'
import re, sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().splitlines()
sv_h = fl_h = content_h = None
for i, l in enumerate(lines):
    if 'NScrollView' in l and sv_h is None:
        # Geometry prints after the pointer: "TYPE(0x…) WxH @x,y" — matching
        # WxH anywhere would catch the hex address itself (0x7f → "0x7").
        m = re.search(r'\)\s+(\d+)x(\d+)', l)
        if m: sv_h = int(m.group(2))
        for j in range(i + 1, min(i + 8, len(lines))):
            if 'QQuickFlickable' in lines[j]:
                m = re.search(r'\)\s+(\d+)x(\d+)', lines[j])
                if m: fl_h = int(m.group(2))
                c = re.search(r'contentY:[-\d]+/([-\d]+)', lines[j])
                if c: content_h = int(c.group(1))
                break
if sv_h is None:
    print("FAIL network-panel: NScrollView not in opened panel tree"); sys.exit(1)
if sv_h <= 40:
    print(f"FAIL network-panel: list viewport collapsed to {sv_h}px"); sys.exit(1)
# Preferred height is capped at Style.popupListMaxHeight (300); fillHeight may
# add a little column slack on top, so bound at cap + one row, never content.
if sv_h > 320:
    print(f"FAIL network-panel: list viewport {sv_h}px exceeds cap 300 (+slack)"); sys.exit(1)
if content_h is not None and content_h > 320 and sv_h >= content_h:
    print(f"FAIL network-panel: viewport {sv_h}px grew with content {content_h}px"); sys.exit(1)
print(f"network-panel geometry ok: viewport {sv_h}px (flickable {fl_h}, content {content_h})")
PYEOF
                          call network togglePanel 0.3
                          for _ in $(seq 1 15); do
                            qs -p "$REPO" ipc call debug opened 24 > "$WORK/logs/network-panel-early.txt" 2>/dev/null || true
                            grep -q "NScrollView" "$WORK/logs/network-panel-early.txt" && break
                            sleep 0.4
                          done
                          python3 "$WORK/netgeom.py" "$WORK/logs/network-panel-early.txt" || SCENE_FAIL=1
                          sleep 1.2
                          shot network-panel
                          qs -p "$REPO" ipc call debug opened 24 > "$WORK/logs/network-panel-settled.txt" 2>&1 || true
                          python3 "$WORK/netgeom.py" "$WORK/logs/network-panel-settled.txt" || SCENE_FAIL=1
                          call network togglePanel 0.5 ;;
    bluetooth-panel)      toggle bluetooth togglePanel 1.5 bluetooth-panel ;;
    battery-panel)        toggle battery togglePanel 1.5 battery-panel ;;
    calendar-panel)       toggle calendar toggle 1.5 calendar-panel ;;
    media-panel)          toggle media toggle 1.5 media-panel ;;
    system-monitor)       toggle systemMonitor toggle 1.5 system-monitor ;;
    notification-history) toggle notifications toggleHistory 1.5 notification-history ;;
    wallpaper)            call wallpaper set "$REPO/Assets/Wallpaper/nosdshell.png" 2
                          shot wallpaper ;;
    wallpaper-panel)      call wallpaper toggle 2
                          shot wallpaper-panel
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # Wheel down on the strip scrolls right — the left
                          # chevron should appear and thumbs should shift.
                          # The thumbnail band sits ~y890-970 on 1080p; aim at
                          # the middle of a thumb, clear of the chevron zone.
                          # NOTE: in the verify sway, virtual-pointer axis
                          # events never reach the nosdshell-background layer
                          # surface (clicks do) — the wheel path is exercised
                          # here for documentation but only the chevron click
                          # below is asserted. On real compositors niri/sway
                          # deliver axis events to layer surfaces normally.
                          "$VINPUT" vinput scroll 960 930 600 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.9
                          shot wallpaper-panel-scrolled
                          # Mechanical check: click the right chevron — the
                          # strip must page right regardless of wheel delivery.
                          # Chevron center is ~(1888,945) — the strip band is
                          # y890-970 and the button hugs the right edge.
                          "$VINPUT" vinput click 1888 945 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.9
                          shot wallpaper-panel-paged
                          # Wheel up scrolls back left.
                          "$VINPUT" vinput scroll 960 930 -600 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.9
                          shot wallpaper-panel-scrolled-back
                          # Hover a thumbnail: the three slot buttons appear
                          # (浅色 / 深色 / 都用). The virtual pointer dies when
                          # vinput exits, which sends a leave and resets hover
                          # before the shot — hold it alive in the background.
                          VINPUT_HOLD_MS=3000 "$VINPUT" vinput move 400 930 2>>"$WORK/logs/vinput.log" &
                          VP=$!
                          sleep 1.0
                          shot wallpaper-panel-hover
                          wait $VP
                          call wallpaper toggle 1 ;;
    dock)                 call dock toggle 1.5; shot dock; call dock toggle 1.5 ;;
    dock-menu)            call dock showSettingsMenu 1.5; shot dock-menu ;;
    dock-submenu)         call dock showSettingsSubmenu 1.5; shot dock-submenu ;;
    # Widget context menu on a dock plugin: find the Clock item in the dock
    # scene tree (document roots describe() as Clock_QML_*), rclick it with a
    # real pointer event, then verify the menu rows render — the trailing
    # "widget-settings" entry must be there (DESIGN §3.3, cua P2).
    dock-widget-menu)     qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 12 > "$WORK/logs/dock-tree.txt" 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # Tree coords are window-local; the dock window is a
                          # strip flush to the docked edge, so the cross axis
                          # maps via DOCK_POSITION (bottom/top here).
                          CLOCK_POS=$(DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/dock-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("DOCK_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
dock_w = dock_h = 0
clock = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if dock_h == 0:
        dock_w, dock_h = int(w.group(1)), int(w.group(2))  # DockContent root
    if "Clock_QML" in line and clock is None:
        cx, cy = int(m.group(1)) + int(w.group(1)) // 2, int(m.group(2)) + int(w.group(2)) // 2
        if pos == "bottom":
            cy += scr["height"] - dock_h
        elif pos == "right":
            cx += scr["width"] - dock_w
        clock = (cx, cy)
if clock:
    print(*clock)
PYEOF
)
                          echo "clock at: $CLOCK_POS"
                          if [ -n "$CLOCK_POS" ]; then
                            "$VINPUT" vinput rclick $CLOCK_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot dock-widget-menu
                            # Hover a menu row — the accent hover rect rides the
                            # row radius (Style.radiusRow) against the rounded frame.
                            qs -p "$REPO" ipc call debug hit opened 10 10 > "$WORK/logs/dock-menu-hit.txt" 2>&1 || true
                            # Menu opens just above the widget — its first row
                            # centre sits ~70 px above the widget centre on a
                            # 1920x1080 bottom dock.
                            MENU_X=$(( ${CLOCK_POS%% *} - 45 ))
                            MENU_Y=$(( ${CLOCK_POS#* } - 70 ))
                            "$VINPUT" vinput move $MENU_X $MENU_Y 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.8
                            shot dock-widget-menu-hover
                            "$VINPUT" vinput click 300 300 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.8
                          else
                            echo "clock widget not found in dock tree"
                          fi ;;
    # Bundled usb-drive-manager: widget is hidden by default with zero
    # devices (hideWhenEmpty) — the seed above forces it visible. Click it
    # to open the panel on the empty state, then assert the panel is a
    # bounded popup (viewport never follows content past popupListMaxHeight).
    usb-panel)            qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 14 > "$WORK/logs/usb-dock-tree.txt" 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          USB_POS=$(DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/usb-dock-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("DOCK_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
dock_w = dock_h = 0
widget = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if dock_h == 0:
        dock_w, dock_h = int(w.group(1)), int(w.group(2))  # DockContent root
    if "BarWidget_QML" in line and widget is None:
        cx, cy = int(m.group(1)) + int(w.group(1)) // 2, int(m.group(2)) + int(w.group(2)) // 2
        if pos == "bottom":
            cy += scr["height"] - dock_h
        elif pos == "right":
            cx += scr["width"] - dock_w
        widget = (cx, cy)
if widget:
    print(*widget)
PYEOF
)
                          echo "usb widget at: $USB_POS"
                          if [ -n "$USB_POS" ]; then
                            "$VINPUT" vinput click $USB_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.4
                            shot usb-panel
                            qs -p "$REPO" ipc call debug opened 12 > "$WORK/logs/usb-opened.txt" 2>&1 || true
                            python3 - "$WORK/logs/usb-opened.txt" <<'PYEOF' || SCENE_FAIL=1
import re,sys
lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
# The panel card (Panel_QMLTYPE), not the fullscreen PluginPanelSlot host.
for l in lines:
    if "Panel_QMLTYPE" not in l:
        continue
    g = re.search(r" (-?\d+)x(-?\d+) @", l)
    if not g:
        continue
    w, h = int(g.group(1)), int(g.group(2))
    # Empty state must be a real card, bounded (0.7*1080 = 756 ceiling).
    if h <= 40 or h > 756:
        print(f"FAIL usb-panel: panel {w}x{h} outside bounds"); sys.exit(1)
    break
else:
    print("FAIL usb-panel: no Panel_QMLTYPE card in opened tree"); sys.exit(1)
PYEOF
                            "$VINPUT" vinput click 300 300 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.6
                          else
                            echo "FAIL usb-panel: widget not found in dock tree"; SCENE_FAIL=1
                          fi ;;
    # Widget context menu on a BAR widget — the efficient taskbar or the
    # fashion status bar (bar-HEADLESS-1). The menu must open inside the
    # edge that actually hosts the widget (PanelService.surfaceEdgeOf,
    # DESIGN §3.13): a status-bar widget's menu sits below a top status
    # bar, not at the taskbar edge.
    bar-widget-menu)    qs -p "$REPO" ipc call debug tree bar-HEADLESS-1 12 > "$WORK/logs/bar-tree.txt" 2>&1 || true
                          if grep -q 'unknown root' "$WORK/logs/bar-tree.txt"; then
                            echo "bar-widget-menu: skipped (no bar window in this config)"
                            return 0
                          fi
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # Tree coords are window-local; the bar window is a
                          # strip flush to BAR_POSITION (see getBarPositionForScreen).
                          CLOCK_POS=$(BAR_POSITION="$BAR_POSITION" python3 - "$WORK/logs/bar-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("BAR_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
bar_w = bar_h = 0
clock = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if bar_h == 0:
        bar_w, bar_h = int(w.group(1)), int(w.group(2))  # bar window root
    if "Clock_QML" in line and clock is None:
        cx, cy = int(m.group(1)) + int(w.group(1)) // 2, int(m.group(2)) + int(w.group(2)) // 2
        if pos == "bottom":
            cy += scr["height"] - bar_h
        elif pos == "right":
            cx += scr["width"] - bar_w
        clock = (cx, cy)
if clock:
    print(*clock)
PYEOF
)
                          echo "bar clock at: $CLOCK_POS"
                          if [ -n "$CLOCK_POS" ]; then
                            "$VINPUT" vinput rclick $CLOCK_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.2
                            shot bar-widget-menu
                            "$VINPUT" vinput click 300 300 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.8
                          else
                            echo "clock widget not found in bar tree"
                          fi ;;
    # Efficient-mode taskbar polish (DESIGN §3.1.1): the launcher icon right-
    # click opens the dark launcher DockMenu (task manager / dock settings /
    # launcher settings), empty-space right-click opens the light taskbar
    # settings menu, an app icon right-click opens the dark app menu — and
    # clicking its Pin row must actually write dock.pinnedApps. The taskbar
    # IS the bar window here (BarService.hasBarOnScreen: efficient => true).
    # Needs an efficient seed:
    #   echo '{"dock":{"mode":"efficient"}}' > eff.json
    #   ./verify.sh <run> --settings eff.json --scenes efficient-taskbar
    efficient-taskbar)    if [ "$DOCK_MODE" != "efficient" ]; then
                            echo "efficient-taskbar: skipped (dock.mode=$DOCK_MODE, needs --settings dock.mode=efficient)"
                            return 0
                          fi
                          qs -p "$REPO" ipc call debug list > "$WORK/logs/eff-roots.txt" 2>&1 || true
                          qs -p "$REPO" ipc call debug tree bar-HEADLESS-1 16 > "$WORK/logs/eff-bar-tree.txt" 2>&1 || true
                          if grep -qE 'unknown root|Target not found' "$WORK/logs/eff-bar-tree.txt"; then
                            echo "efficient-taskbar: no bar window (roots: $(cat "$WORK/logs/eff-roots.txt"))"; return 0
                          fi
                          # Guardrail (Bar.qml widgetFillsZone): delegates in the
                          # stretched left zone must stay packed — a stretch with
                          # no filling delegate lets Qt spread items ∝ implicit
                          # widths, which once pushed Launcher/Workspace apart.
                          python3 - "$WORK/logs/eff-bar-tree.txt" "$(echo "$NOSD_CONFIG_DIR" | sed 's:/$::')/settings.json" <<'PYEOF' || SCENE_FAIL=1
import json,re,sys
tree=open(sys.argv[1],encoding="utf-8",errors="replace").read().splitlines()
try:
    gap=json.load(open(sys.argv[2])).get("bar",{}).get("widgetSpacing",6)
except Exception:
    gap=6
lines=[(len(l)-len(l.lstrip()),l) for l in tree]
start=next((i for i,(d,l) in enumerate(lines) if '"leftSection"' in l and 'Layout' in l),None)
if start is None:
    print("efficient-taskbar: no leftSection in tree")
    sys.exit(1)
# ColumnLayout => vertical dock: pack along y using height (groups 4,2).
vert='ColumnLayout' in lines[start][1]
pos,size=(4,2) if vert else (3,1)
ind=lines[start][0]
xs=[]
for d,l in lines[start+1:]:
    if d<=ind: break
    m=re.search(r'BarWidgetLoader\S*.*?(\d+)x(\d+) @(-?\d+),(-?\d+)',l)
    if d==ind+2 and m and 'hidden' not in l and int(m.group(size))>0:
        xs.append((int(m.group(pos)),int(m.group(size))))
bad=[(a,b) for a,b in zip(xs,xs[1:]) if b[0]-(a[0]+a[1])!=gap]
if bad:
    print(f"FAIL efficient-taskbar: left-zone delegates not packed (spacing={gap}): {bad} in {xs}")
    sys.exit(1)
print(f"efficient-taskbar: left-zone packing OK {xs} (spacing={gap})")

# Guardrail (Taskbar.zoneAvailable): taskbar items in the centered zone must
# sit at itemLongLength unless the zone's real free span — the symmetric
# clearance between the packed clusters, same formula as Bar.qml — forces a
# proportional shrink. A self-referential bound (items sizing off their own
# allocated width) once froze the zone's width so every new window shrank
# the items a little more.
wm=re.search(r'window \S+ (\d+)x(\d+)',tree[0])
cIdx=next((i for i,(d,l) in enumerate(lines) if '"centerSection"' in l and 'Layout' in l),None)
rIdx=next((i for i,(d,l) in enumerate(lines) if '"rightSection"' in l and 'Layout' in l),None)
items=[]
if cIdx is not None:
    cInd=lines[cIdx][0]
    for d,l in lines[cIdx+1:]:
        if d<=cInd: break
        m=re.search(r'"taskbarAppItem"\s+(\d+)x(\d+)',l)
        if m: items.append((int(m.group(1)),int(m.group(2))))
if items and wm and rIdx is not None:
    rm=re.search(r'(\d+)x(\d+) @(-?\d+),(-?\d+)',lines[rIdx][1])
    lm=re.search(r'(\d+)x(\d+) @(-?\d+),(-?\d+)',lines[start][1])
    rX,rY=int(rm.group(3)),int(rm.group(4))
    lX,lY,lW,lH=int(lm.group(3)),int(lm.group(4)),int(lm.group(1)),int(lm.group(2))
    if vert:
        barLen,leftEnd,rightStart,barH=int(wm.group(2)),lY+lH,rY,int(wm.group(1))
    else:
        barLen,leftEnd,rightStart,barH=int(wm.group(1)),lX+lW,rX,int(wm.group(2))
    mid=barLen/2
    bound=max(0,2*min(mid-leftEnd,rightStart-mid)-2*gap)
    itemLen=round(barH*1.4)
    expect=min(itemLen,bound//len(items)) if bound>0 else itemLen
    got=[i[0] if not vert else i[1] for i in items]
    off=[w for w in got if abs(w-expect)>1]
    if off:
        print(f"FAIL efficient-taskbar: taskbar items {got} not at expected long length {expect} (itemLong={itemLen}, bound={bound}, n={len(items)})")
        sys.exit(1)
    print(f"efficient-taskbar: taskbar item long length OK {got} (expect={expect})")
PYEOF
                          # Workspace-switch animation: the active WorkspacePill
                          # widens ~2.2x; after `swaymsg workspace 2` its width
                          # must still be travelling. A State/Transition pair
                          # once named a never-declared "inactive" state, so the
                          # switch snapped instead of animating — sample widths
                          # for ~1.2s and require at least one in-flight frame
                          # strictly between the narrow and wide finals.
                          swaymsg "workspace 1" >/dev/null 2>&1 || true
                          sleep 0.4
                          swaymsg "workspace 2" >/dev/null 2>&1 || true
                          python3 - "$REPO" <<'PYEOF' || SCENE_FAIL=1
import re,subprocess,sys,time
def sizes():
    t=subprocess.run(["qs","-p",sys.argv[1],"ipc","call","debug","tree","bar-HEADLESS-1","16"],capture_output=True,text=True).stdout.splitlines()
    out=[]
    for l in t:
        m=re.search(r'WorkspacePill\S*\)\s+(\d+)x(\d+) @(-?\d+),(-?\d+)',l)
        if m and 'hidden' not in l:
            out.append((int(m.group(3)),int(m.group(1)),int(m.group(2))))
    return sorted(out)
base=sizes()
if len(base)<2:
    print("efficient-taskbar: <2 workspace pills, switch-anim check skipped")
    sys.exit(0)
# Animated axis: horizontal bar widens width, vertical dock widens height.
ws=[w for x,w,h in base]; hs=[h for x,w,h in base]
axi=1 if max(ws)-min(ws)>=max(hs)-min(hs) else 2
vals=lambda s:[p[axi] for p in s]
narrow=min(vals(base)); wide=max(vals(base))
if wide-narrow<8:
    print(f"efficient-taskbar: active pill not widened (sizes {base}), switch-anim check skipped")
    sys.exit(0)
deadline=time.time()+1.2
last=[]
while time.time()<deadline:
    s=sizes()
    if s: last=s
    if any(narrow+2<v<wide-2 for v in vals(s)):
        print(f"efficient-taskbar: workspace-switch animation OK mid={s} (narrow={narrow} wide={wide} axis={'wh'[axi-1]})")
        sys.exit(0)
    time.sleep(0.08)
if not last:
    print("efficient-taskbar: workspace pills vanished, switch-anim check skipped")
    sys.exit(0)
print(f"FAIL efficient-taskbar: workspace switch snapped — no in-flight size in {(narrow,wide)}: {last}")
sys.exit(1)
PYEOF
                          swaymsg "workspace 1" >/dev/null 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          # Window-local tree coords → screen coords: the
                          # efficient taskbar is a full-width strip on
                          # DOCK_POSITION (default bottom).
                          ANCHORS=$(DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/eff-bar-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("DOCK_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
bar_w = bar_h = 0
launcher = app = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if bar_h == 0:
        bar_w, bar_h = int(w.group(1)), int(w.group(2))
        continue
    cx, cy = int(m.group(1)) + int(w.group(1)) // 2, int(m.group(2)) + int(w.group(2)) // 2
    if pos == "bottom":
        cy += scr["height"] - bar_h
    elif pos == "top":
        pass
    elif pos == "left":
        pass
    elif pos == "right":
        cx += scr["width"] - bar_w
    if "Launcher_QML" in line and launcher is None:
        launcher = (cx, cy)
    if '"taskbarAppItem"' in line and app is None:
        app = (cx, cy)
# empty taskbar space: horizontal centreline of the strip, well right of
# the packed app items and left of the plugin row
if pos in ("bottom","top"):
    ey = scr["height"] - bar_h // 2 if pos == "bottom" else bar_h // 2
    empty = (scr["width"] // 2, ey)
else:
    ex = bar_w // 2 if pos == "left" else scr["width"] - bar_w // 2
    empty = (ex, scr["height"] // 2)
print(*launcher, *app, *empty) if launcher and app else print("")
PYEOF
)
                          LAUNCHER_POS=$(echo "$ANCHORS" | awk '{print $1, $2}')
                          APP_POS=$(echo "$ANCHORS" | awk '{print $3, $4}')
                          EMPTY_POS=$(echo "$ANCHORS" | awk '{print $5, $6}')
                          echo "eff-taskbar anchors: launcher=$LAUNCHER_POS app=$APP_POS empty=$EMPTY_POS"
                          [ -n "$LAUNCHER_POS" ] || { echo "launcher/app items not found"; return 0; }
                          # 1. launcher icon right-click → dark launcher menu
                          "$VINPUT" vinput rclick $LAUNCHER_POS 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2
                          shot efficient-launcher-menu
                          qs -p "$REPO" ipc call debug tree "dockmenu-launcher-$DOCK_POSITION" 10 > "$WORK/logs/eff-launcher-menu.txt" 2>&1 || true
                          "$VINPUT" vinput click 960 500 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.8
                          # 2. empty strip right-click → light settings menu
                          "$VINPUT" vinput rclick $EMPTY_POS 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2
                          shot efficient-taskbar-menu
                          "$VINPUT" vinput click 960 500 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.8
                          # 3. app icon right-click → dark app menu, then
                          # click the Pin row and assert pinnedApps grew.
                          PINS_BEFORE=$(python3 -c "import json;print(len(json.load(open('$NOSD_CONFIG_DIR/settings.json')).get('dock',{}).get('pinnedApps',[])))" 2>/dev/null || echo 0)
                          "$VINPUT" vinput rclick $APP_POS 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2
                          shot efficient-app-menu
                          qs -p "$REPO" ipc call debug tree "dockmenu-app-$DOCK_POSITION" 10 > "$WORK/logs/eff-app-menu.txt" 2>&1 || true
                          # Popup top-left in screen coords: bottom taskbar →
                          # menu sits above the item, centred on it.
                          PIN_POS=$(APP_POS="$APP_POS" DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/eff-app-menu.txt" "$WORK/logs/eff-bar-tree.txt" <<'PYEOF'
import os,re,sys
ax,ay = map(int, os.environ["APP_POS"].split(" "))
pos = os.environ.get("DOCK_POSITION","bottom")
# item height from the bar tree (taskbarAppItem rect), needed because the
# popup anchors to the item EDGE, not its centre.
item_h = 43
for line in open(sys.argv[2], encoding="utf-8", errors="replace"):
    if '"taskbarAppItem"' in line:
        w = re.search(r" (\d+)x(\d+) ", line)
        if w:
            item_h = int(w.group(2)) if pos in ("bottom","top") else int(w.group(1))
        break
rows = []
mw = mh = 0
first = True
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if first:
        mw, mh = int(w.group(1)), int(w.group(2)); first = False
        continue
    if '"dockMenuItem:' in line:
        label = line.split('"dockMenuItem:')[1].split('"')[0]
        rows.append((label, int(m.group(1)) + int(w.group(1))//2, int(m.group(2)) + int(w.group(2))//2))
pin = [r for r in rows if r[0] in ("Pin","固定","Unpin","取消固定","取消")]
if not pin or mw == 0:
    print(""); sys.exit()
_,rx,ry = pin[0]
# popup sits above the item's top edge on a bottom taskbar
# (anchor.y = -implicitHeight - Style.popupGap, anchored on the item origin)
gap = 2
half = item_h // 2
if pos == "bottom":
    top = ay - half - mh - gap; left = ax - mw // 2
elif pos == "top":
    top = ay + half + gap; left = ax - mw // 2
elif pos == "left":
    top = ay - mh // 2; left = ax + half + gap
else:
    top = ay - mh // 2; left = ax - half - mw - gap
print(left + rx, top + ry)
PYEOF
)
                          echo "pin row at: $PIN_POS"
                          if [ -n "$PIN_POS" ]; then
                            "$VINPUT" vinput click $PIN_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.8
                            python3 - "$NOSD_CONFIG_DIR" "$PINS_BEFORE" <<'PYEOF'
import json,sys
p=sys.argv[1].rstrip('/')+"/settings.json"
d=json.load(open(p))
n=len(d.get("dock",{}).get("pinnedApps",[]))
print("pinnedApps count:", n, "(before:", sys.argv[2]+")")
PYEOF
                            shot efficient-pinned
                          fi
                          "$VINPUT" vinput click 960 500 2>>"$WORK/logs/vinput.log" || true
                          # 4. battery plugin hover: must paint the same
                          # overlay("hover") wash as its neighbours — no opaque
                          # capsule (useGraphicMode is off on the taskbar).
                          BAT_POS=$(DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/eff-bar-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("DOCK_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
bar_w = bar_h = 0
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if bar_h == 0:
        bar_w, bar_h = int(w.group(1)), int(w.group(2))
        continue
    if "Battery_QML" in line:
        cx, cy = int(m.group(1)) + int(w.group(1))//2, int(m.group(2)) + int(w.group(2))//2
        if pos == "bottom": cy += scr["height"] - bar_h
        elif pos == "right": cx += scr["width"] - bar_w
        print(cx, cy)
        break
PYEOF
)
                          if [ -n "$BAT_POS" ]; then
                            "$VINPUT" vinput move $BAT_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.8
                            shot efficient-battery-hover
                          else
                            echo "battery widget not found in bar tree"
                          fi ;;
    #   ./verify.sh <run> --settings <fashion-seed>.json --scenes fashion-dock
    # Fashion dock application-strip checks: the Taskbar entry's
    # onlyActiveWorkspaces gate (windows on other workspaces leave the strip)
    # and the shared enter/leave animation (Dock.qml dockRows — dying rows
    # collapse while newcomers grow, same recipe as the efficient Taskbar).
    # Fixture: foot+Calculator sit on ws1, Nautilus was moved to ws2 — a ws
    # switch must both change the row set and visibly animate it.
    fashion-dock)         if [ "$DOCK_MODE" != "fashion" ]; then
                            echo "fashion-dock: skipped (dock.mode=$DOCK_MODE, needs --settings dock.mode=fashion)"
                            return 0
                          fi
                          swaymsg "workspace 1" >/dev/null 2>&1 || true
                          sleep 0.8
                          qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 16 > "$WORK/logs/fash-dock-tree.txt" 2>&1 || true
                          swaymsg -t get_tree > "$WORK/logs/fash-sway-tree.json" 2>&1 || true
                          swaymsg -t get_workspaces > "$WORK/logs/fash-sway-ws.json" 2>&1 || true
                          if grep -q 'unknown root' "$WORK/logs/fash-dock-tree.txt"; then
                            echo "fashion-dock: no dock window"; return 0
                          fi
                          # expected app count = windows on the active sway
                          # workspace (+0 pinned; seed keeps dock.pinnedApps
                          # empty). onlyActiveWorkspaces resolves like
                          # Dock.qml._taskbarWidgetEntry: the Taskbar entry in
                          # taskbarWidgets/dock.plugins, else registry default.
                          EXPECTED=$(python3 - "$(echo "$NOSD_CONFIG_DIR" | sed 's:/$::')/settings.json" <<'PYEOF'
import json,re,subprocess,sys
try:
    cfg=json.load(open(sys.argv[1]))
except Exception:
    cfg={}
dock=cfg.get("dock",{})
tw=dock.get("taskbarWidgets") or {}
entry=None
for lst in (tw.get("left"),tw.get("center"),dock.get("plugins")) or []:
    for e in lst or []:
        if e and e.get("id")=="Taskbar":
            entry=e
onlyws = entry.get("onlyActiveWorkspaces") if (entry and "onlyActiveWorkspaces" in entry) else True
# Dock rows = window count, or distinct appIds when dock.groupApps folds
# same-app windows into one button (sway floating_con noise: foot spawns
# several cons per process).
focused=json.loads(subprocess.run(["swaymsg","-t","get_workspaces"],capture_output=True,text=True).stdout)
cur=next((w["num"] for w in focused if w.get("focused")),1)
per={}
def wids(n):
    if n.get("app_id"): return [n["app_id"]]
    out=[]
    for c in n.get("nodes",[])+n.get("floating_nodes",[]): out+=wids(c)
    return out
def wwalk(n):
    if n.get("type")=="workspace":
        a=wids(n)
        per[str(n.get("num"))]={"ids":sorted(set(a)),"wins":len(a)}
        return
    for ch in n.get("nodes",[])+n.get("floating_nodes",[]): wwalk(ch)
wwalk(json.loads(subprocess.run(["swaymsg","-t","get_tree"],capture_output=True,text=True).stdout))
GA=dock.get("groupApps",True)
def btnc(wsnum):
    p=per.get(str(wsnum))
    return (len(p["ids"]) if GA else p["wins"]) if p else 0
allids=[]
for p in per.values(): allids+=p["ids"]
print(json.dumps({"cur":btnc(cur),"all":(len(set(allids)) if GA else sum(p["wins"] for p in per.values())),"onlyws":bool(onlyws),"GA":bool(GA),"perWs":per}))
PYEOF
)
                          # ws1 settle: row count must equal the gate result.
                          python3 - "$WORK/logs/fash-dock-tree.txt" "$EXPECTED" <<'PYEOF' || SCENE_FAIL=1
import json,re,sys
tree=open(sys.argv[1],encoding="utf-8",errors="replace").read().splitlines()
btns=[l for l in tree if '"dockAppButton"' in l and 'hidden' not in l]
e=json.loads(sys.argv[2])
exp=e["cur"] if e["onlyws"] else e["all"]
if len(btns)!=exp:
    print(f"FAIL fashion-dock: {len(btns)} app buttons on ws1, expected {exp}")
    sys.exit(1)
print(f"fashion-dock: ws1 app filter OK ({exp} buttons, onlyws={e['onlyws']})")
PYEOF
                          # Switch to ws2: rows must travel — a collapsing or
                          # growing row shows a long-axis length strictly
                          # between 0 and the settled item length.
                          swaymsg "workspace 2" >/dev/null 2>&1 || true
                          python3 - "$REPO" "$DOCK_POSITION" "$EXPECTED" <<'PYEOF' || SCENE_FAIL=1
import json,re,subprocess,sys,time
VERT=sys.argv[2] in ("left","right")
def rows():
    t=subprocess.run(["qs","-p",sys.argv[1],"ipc","call","debug","tree","dock-HEADLESS-1","16"],capture_output=True,text=True).stdout.splitlines()
    out=[]
    for l in t:
        m=re.search(r'dockAppButton.{0,60}?(\d+)x(\d+) @',l)
        if m and 'hidden' not in l:
            out.append((int(m.group(1)),int(m.group(2))))
    return out
e=json.loads(sys.argv[3])
# identical visible sets across the switch => nothing should move
idset=lambda w:set((e["perWs"].get(str(w)) or {"ids":[]})["ids"]) if e["onlyws"] else None
if (not e["onlyws"]) or idset(1)==idset(2):
    print("fashion-dock: ws sets identical (or filter off), anim check skipped")
    sys.exit(0)
base=rows()
if not base:
    print("fashion-dock: no app buttons at baseline, anim check skipped")
    sys.exit(0)
axi=1 if VERT else 0          # long axis: height on left/right docks, else width
L=max(b[axi] for b in base)
deadline=time.time()+1.4
last=[]
midshot=None
while time.time()<deadline:
    s=rows(); last=s
    # in-flight: a row collapsing/growing between 0 and the settled length,
    # or dying rows still holding extra slots
    if any(2<v[axi]<L-2 for v in s) or len(s)>len(base):
        midshot=s; break
    time.sleep(0.06)
if midshot is None:
    print(f"FAIL fashion-dock: workspace switch snapped — no in-flight row sizes; base={base} final={last}")
    sys.exit(1)
print(f"fashion-dock: app-strip switch animation OK mid={midshot}")
PYEOF
                          # Settle on ws2: the gate result must hold — the ws1
                          # apps' dying rows are gone, Nautilus grew in.
                          sleep 1.2
                          qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 16 > "$WORK/logs/fash-dock-tree2.txt" 2>&1 || true
                          python3 - "$WORK/logs/fash-dock-tree2.txt" "$EXPECTED" <<'PYEOF' || SCENE_FAIL=1
import json,re,subprocess,sys
btns=[l for l in open(sys.argv[1],encoding="utf-8",errors="replace") if '"dockAppButton"' in l and 'hidden' not in l]
e=json.loads(sys.argv[2])
GA=e.get("GA",True)
p2=e["perWs"].get("2") or {"ids":[],"wins":0}
n=(len(p2["ids"]) if GA else p2["wins"]) if e["onlyws"] else e["all"]
if len(btns)!=n:
    print(f"FAIL fashion-dock: {len(btns)} buttons settled on ws2, expected {n}")
    sys.exit(1)
print(f"fashion-dock: ws2 settle OK ({n} buttons)")
PYEOF
                          swaymsg "workspace 1" >/dev/null 2>&1 || true
                          sleep 0.8
                          shot fashion-dock
                          ;;
    # Wheel over the dock battery widget adjusts display brightness; the
    # charging/low state tint rides along in the same shots. Locate the widget
    # in the dock scene tree, inject real wheel scrolls, shot the resulting
    # OSD. Needs a controllable monitor — seed
    # brightness.backlightDeviceMappings pointing at a writable fake dir
    # (e.g. /tmp/fake-backlight/{brightness,max_brightness}); the brightnessctl
    # write fails harmlessly but monitor.brightness + brightnessUpdated still
    # drive the OSD. Scene name is passed through like dock-fullscreen:
    #   ./verify.sh <run> --settings <seed>.json --scenes dock-battery-wheel
    dock-battery-wheel)   qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 12 > "$WORK/logs/battery-dock-tree.txt" 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          BAT_POS=$(DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/battery-dock-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("DOCK_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
dock_w = dock_h = 0
btn = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if dock_h == 0:
        dock_w, dock_h = int(w.group(1)), int(w.group(2))  # DockContent root
    if "Battery_QML" in line and btn is None:
        cx, cy = int(m.group(1)) + int(w.group(1)) // 2, int(m.group(2)) + int(w.group(2)) // 2
        if pos == "bottom":
            cy += scr["height"] - dock_h
        elif pos == "right":
            cx += scr["width"] - dock_w
        btn = (cx, cy)
if btn:
    print(*btn)
PYEOF
)
                          echo "battery widget at: $BAT_POS"
                          if [ -n "$BAT_POS" ] && [ -x "$VINPUT" ]; then
                            # Hover first — the tooltip shot also exercises the
                            # arrow-popup shadow path (Style.shadowPopup).
                            "$VINPUT" vinput move $BAT_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.8
                            shot dock-battery-tip
                            shot dock-battery-tint
                            "$VINPUT" vinput scroll $BAT_POS -30 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot dock-battery-down
                            "$VINPUT" vinput scroll $BAT_POS 30 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot dock-battery-up
                          else
                            echo "battery widget not found or vinput missing: $BAT_POS"
                          fi ;;
    # Right-click the dock's notification-history bell: the NPopupContextMenu
    # must size to its longest label — short CJK labels used to elide because
    # calculateWidth never counted the 2x20px row padding.
    dock-context-menu)    qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 12 > "$WORK/logs/menu-dock-tree.txt" 2>&1 || true
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          BELL_POS=$(DOCK_POSITION="$DOCK_POSITION" python3 - "$WORK/logs/menu-dock-tree.txt" <<'PYEOF'
import json,os,re,subprocess,sys
pos = os.environ.get("DOCK_POSITION","bottom")
out = json.loads(subprocess.run(["swaymsg","-t","get_outputs"],capture_output=True,text=True).stdout)
scr = next(o["rect"] for o in out if o.get("active"))
dock_w = dock_h = 0
btn = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"@(-?\d+),(-?\d+)", line)
    w = re.search(r" (\d+)x(\d+) ", line)
    if not (m and w):
        continue
    if dock_h == 0:
        dock_w, dock_h = int(w.group(1)), int(w.group(2))  # DockContent root
    if "NotificationHistory_QML" in line and btn is None:
        cx, cy = int(m.group(1)) + int(w.group(1)) // 2, int(m.group(2)) + int(w.group(2)) // 2
        if pos == "bottom":
            cy += scr["height"] - dock_h
        elif pos == "right":
            cx += scr["width"] - dock_w
        btn = (cx, cy)
if btn:
    print(*btn)
PYEOF
)
                          echo "notification bell at: $BELL_POS"
                          if [ -n "$BELL_POS" ] && [ -x "$VINPUT" ]; then
                            "$VINPUT" vinput rclick $BELL_POS 2>>"$WORK/logs/vinput.log" || true
                            sleep 1.0
                            shot dock-context-menu
                            "$VINPUT" vinput click 300 300 2>>"$WORK/logs/vinput.log" || true
                            sleep 0.8
                          else
                            echo "notification bell not found or vinput missing: $BELL_POS"
                          fi ;;
    # Right-click the dock Workspace widget → its context menu (single
    # "widget-settings" item) → open the settings dialog. This is the
    # PopupMenuWindow path (dialogItem + blurRegion), distinct from the
    # settings-panel gear dialogs: the scene asserts the dialog's reset
    # button is findable inside popupMenuWindow-HEADLESS-1.
    # Needs a seed with a Workspace entry in dock.plugins (defaults carry
    # none): {"dock":{"plugins":[{"id":"Tray"},{"id":"Workspace"},{"id":"Clock"}]}}
    dock-widget-settings)
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          if [ ! -x "$VINPUT" ]; then echo "dock-widget-settings: nosd-helpers missing"; SCENE_FAIL=1
                          else
                          # Fashion mode puts Workspace under dock-*; in
                          # efficient mode the taskbar is the bar root. Layer
                          # windows report Qt position (0,0) and anchored
                          # popups report positions relative to their parent
                          # surface, so `debug find` coordinates are resolved
                          # against the host window's screen offset — the
                          # ctxmenu popup is parented to the same surface the
                          # widget lives on, so one offset serves both. The
                          # offset is derived from the host window's own size:
                          # an edge strip sits flush against DOCK_POSITION's
                          # edge, a fullscreen window needs no offset at all.
                          WS_ROOT=dock-HEADLESS-1
                          WS_IT=$(qs -p "$REPO" ipc call debug find dock-HEADLESS-1 workspaceWidget 2>&1 || true)
                          case "$WS_IT" in *"no item"*|"") WS_ROOT=bar-HEADLESS-1; WS_IT=$(qs -p "$REPO" ipc call debug find bar-HEADLESS-1 workspaceWidget 2>&1 || true);; esac
                          read -r SQX SQY SQW SQH < <(echo "$WS_IT" | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\) @\([0-9][0-9]*\),\([0-9][0-9]*\).*/\3 \4 \1 \2/p')
                          SURF_OX=0; SURF_OY=0
                          if [ -n "${SQX:-}" ]; then
                            SURF_WH=$(qs -p "$REPO" ipc call debug tree "$WS_ROOT" 1 2>/dev/null | sed -n '1s/.* \([0-9][0-9]*\)x\([0-9][0-9]*\).*/\1 \2/p')
                            read -r SURF_W SURF_H <<< "${SURF_WH:-0 0}"
                            case "${DOCK_POSITION:-bottom}" in
                              top)    ;;
                              left)   ;;
                              right)  [ "$SURF_W" -lt 1920 ] && SURF_OX=$((1920 - SURF_W)) ;;
                              *)      [ "$SURF_H" -lt 1080 ] && SURF_OY=$((1080 - SURF_H)) ;;
                            esac
                          fi
                          [ -n "${SQX:-}" ] && { SQX=$((SQX + SURF_OX)); SQY=$((SQY + SURF_OY)); }
                          echo "workspace widget at: ${SQX:-none},${SQY:-none} ${SQW:-}x${SQH:-} (root $WS_ROOT)"
                          if [ -z "${SQX:-}" ]; then echo "FAIL dock-widget-settings: workspaceWidget not found: $WS_IT"; SCENE_FAIL=1
                          else
                          "$VINPUT" vinput rclick $((SQX + SQW / 2)) $((SQY + SQH / 2)) 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.0
                          shot dock-widget-menu
                          # The menu is its own anchored PopupWindow — registered
                          # as the "ctxmenu" root while open; its rows carry
                          # ctxmenuItem-<action> objectNames for `debug find`.
                          MENU_IT=$(qs -p "$REPO" ipc call debug find ctxmenu ctxmenuItem-widget-settings 2>&1 || true)
                          # G@ is the popup's position relative to its parent
                          # (dock strip); add the same surface offset.
                          read -r MENU_W MENU_H MENU_X MENU_Y < <(echo "$MENU_IT" | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\).* G@\(-\?[0-9][0-9]*\),\(-\?[0-9][0-9]*\).*/\1 \2 \3 \4/p')
                          if [ -z "${MENU_X:-}" ]; then echo "FAIL dock-widget-settings: ctxmenuItem-widget-settings not found: $MENU_IT"; SCENE_FAIL=1
                          else
                          MENU_X=$((MENU_X + SURF_OX)); MENU_Y=$((MENU_Y + SURF_OY))
                          echo "menu item at: $((MENU_X + MENU_W / 2)),$((MENU_Y + MENU_H / 2))"
                          "$VINPUT" vinput click $((MENU_X + MENU_W / 2)) $((MENU_Y + MENU_H / 2)) 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.2
                          shot dock-widget-settings
                          qs -p "$REPO" ipc call debug tree popupMenuWindow-HEADLESS-1 40 > "$WORK/logs/dw-dlg-tree.txt" 2>&1 || true
                          FOUND=$(qs -p "$REPO" ipc call debug find popupMenuWindow-HEADLESS-1 widgetSettingsReset 2>&1 || true)
                          if echo "$FOUND" | grep -q "@"; then
                            echo "dock-widget-settings: dialog open in popupMenuWindow (ok)"
                          else
                            echo "FAIL dock-widget-settings: widgetSettingsReset not found: $FOUND"; SCENE_FAIL=1
                          fi
                          # Close the dialog for any following scene.
                          FOUNDC=$(qs -p "$REPO" ipc call debug find popupMenuWindow-HEADLESS-1 widgetSettingsClose 2>&1 || true)
                          read -r CW CH CX CY < <(echo "$FOUNDC" | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\).* G@\([0-9][0-9]*\),\([0-9][0-9]*\).*/\1 \2 \3 \4/p')
                          [ -n "${CX:-}" ] && "$VINPUT" vinput click $((CX + CW / 2)) $((CY + CH / 2)) 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.8
                          fi
                          fi
                          fi ;;
    # Regression: a settings write from the sectioned editor must never
    # overwrite a slot's entry id — BarWidgetSettingsDialog once re-read the
    # entry through getBarWidgetsForScreen, which in fashion mode returns
    # bar.widgets (left[1] = Clock on the default bar), so closing the
    # Taskbar dialog wrote {id:"Clock",…} into dock.taskbarWidgets.left[1]
    # and the app strip vanished. Seed fashion mode, open the editor gear,
    # close the dialog, assert the Taskbar id survives on disk. The dialog
    # must also render on the popupMenuWindow surface — the one carrying the
    # dialog blur region (Overlay-hosted dialogs have none).
    #   ./verify.sh <run> --settings '{"dock":{"mode":"fashion"}}' --scenes taskbar-settings-write
    taskbar-settings-write)
                          if [ "$DOCK_MODE" != "fashion" ]; then
                            echo "taskbar-settings-write: skipped (dock.mode=$DOCK_MODE, needs --settings dock.mode=fashion)"
                            return 0
                          fi
                          VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                          [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                          if [ ! -x "$VINPUT" ]; then echo "taskbar-settings-write: nosd-helpers missing"; SCENE_FAIL=1
                          else
                          SF="$(echo "$NOSD_CONFIG_DIR" | sed 's:/$::')/settings.json"
                          call settings openTab dock/3 5
                          # Gear of the Taskbar entry in the left zone
                          # (taskbarWidgets.left[1] on the default layout).
                          TSR() { # <objectName> → "cx cy", searched under the cc panel root
                            local r d w h x y
                            for r in cc-HEADLESS-1 popupMenuWindow-HEADLESS-1; do
                              d=$(qs -p "$REPO" ipc call debug find "$r" "$1" 2>/dev/null)
                              case "$d" in *hidden*|*"no item"*|"") ;; *)
                                read w h x y < <(echo "$d" | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\) @\([0-9][0-9]*\),\([0-9][0-9]*\).*/\1 \2 \3 \4/p')
                                [ -n "${x:-}" ] && { echo $((x + w / 2)) $((y + h / 2)); return; };;
                              esac
                            done
                          }
                          GX=""; GY=""
                          for i in 1 2 3 4 5; do
                            read GX GY < <(TSR widgetGear-left-Taskbar)
                            [ -n "${GX:-}" ] && break
                            sleep 1
                          done
                          if [ -z "${GX:-}" ]; then echo "FAIL taskbar-settings-write: widgetGear-left-Taskbar not found"; SCENE_FAIL=1
                          else
                          "$VINPUT" vinput click "$GX" "$GY" 2>>"$WORK/logs/vinput.log" || true
                          sleep 1.4
                          shot taskbar-settings-dlg
                          # Hosting assertion: the dialog renders inside
                          # popupMenuWindow (blur-region surface), not the
                          # cc panel's own Overlay.
                          DFOUND=$(qs -p "$REPO" ipc call debug find popupMenuWindow-HEADLESS-1 widgetSettingsReset 2>&1 || true)
                          case "$DFOUND" in *"@"*) echo "taskbar-settings-write: dialog hosted on popupMenuWindow (ok)";;
                            *) echo "FAIL taskbar-settings-write: dialog not on popupMenuWindow: $DFOUND"; SCENE_FAIL=1;; esac
                          read CX CY < <(TSR widgetSettingsClose)
                          [ -n "${CX:-}" ] && "$VINPUT" vinput click "$CX" "$CY" 2>>"$WORK/logs/vinput.log" || true
                          sleep 0.8
                          # FileView flushes asynchronously — poll the file.
                          for i in 1 2 3 4 5 6; do
                            python3 - "$SF" <<'PYEOF' && break
import json,sys
d=json.load(open(sys.argv[1]))
left=(d.get("dock",{}).get("taskbarWidgets") or {}).get("left",[])
ids=[e.get("id") for e in left if e]
print("taskbarWidgets.left ids:", ids)
sys.exit(0 if len(ids)>=2 and ids[1]=="Taskbar" else 1)
PYEOF
                            sleep 1
                          done
                          python3 - "$SF" <<'PYEOF' || SCENE_FAIL=1
import json,sys
d=json.load(open(sys.argv[1]))
tw=d.get("dock",{}).get("taskbarWidgets") or {}
ids=[e.get("id") for e in tw.get("left",[]) if e]
if len(ids)<2 or ids[1]!="Taskbar":
    print(f"FAIL taskbar-settings-write: dock.taskbarWidgets.left={ids} — Taskbar slot overwritten by a foreign entry")
    sys.exit(1)
print(f"taskbar-settings-write: entry id preserved after settings write (left={ids})")
PYEOF
                          call settings toggle 0.5
                          fi
                          fi ;;
    # taskbar-add-widgets — incubation-crash repro: widgets are added to the
    # taskbar strip (center zone) and the plugin zone (dock.plugins) one at a
    # time by rewriting settings.json; the FileView watcher reloads → every
    # segment Repeater re-models → delegates re-incubate while the previous
    # ones may still be in flight. A SIGSEGV during incubation kills qs —
    # detected by the debug-tree probe going silent. Removing the entry right
    # after exercises the model-mutation-during-incubation window from the
    # other direction.
    taskbar-add-widgets)
                          SF="$(echo "$NOSD_CONFIG_DIR" | sed 's:/$::')/settings.json"
                          probe() {
                            qs -p "$REPO" ipc call debug tree dock-HEADLESS-1 1 >/dev/null 2>&1 \
                              || qs -p "$REPO" ipc call debug tree bar-HEADLESS-1 1 >/dev/null 2>&1
                          }
                          for ZONE in center plugins; do
                          for WID in ActiveWindow Workspace SystemMonitor MediaMini SessionMenu KeepAwake ShowDesktop Trash Taskbar Spacer plugin:usb-drive-manager plugin:niri-overview-launcher; do
                            python3 - "$SF" "$ZONE" "$WID" <<'PYEOF'
import json,sys
p,zone,wid=sys.argv[1],sys.argv[2],sys.argv[3]
d=json.load(open(p))
if zone=="plugins":
    arr=d.setdefault("dock",{}).setdefault("plugins",[])
else:
    tw=d.setdefault("dock",{}).setdefault("taskbarWidgets",{"left":[{"id":"Launcher"},{"id":"Taskbar"}],"center":[]})
    arr=tw.setdefault(zone,[])
arr[:]=[e for e in arr if not (isinstance(e,dict) and e.get("id")==wid)]
arr.append({"id":wid})
json.dump(d,open(p,"w"))
PYEOF
                            sleep 1.0
                            if ! probe; then
                              echo "FAIL taskbar-add-widgets: qs died after adding $WID to $ZONE (mode=$DOCK_MODE)"
                              SCENE_FAIL=1; return 0
                            fi
                            # remove again — exercises deletion mid-incubation
                            python3 - "$SF" "$ZONE" "$WID" <<'PYEOF'
import json,sys
p,zone,wid=sys.argv[1],sys.argv[2],sys.argv[3]
d=json.load(open(p))
arr=(d.get("dock",{}).get("plugins") if zone=="plugins" else (d.get("dock",{}).get("taskbarWidgets") or {}).get(zone)) or []
arr[:]=[e for e in arr if not (isinstance(e,dict) and e.get("id")==wid)]
json.dump(d,open(p,"w"))
PYEOF
                            sleep 0.8
                            if ! probe; then
                              echo "FAIL taskbar-add-widgets: qs died after removing $WID from $ZONE (mode=$DOCK_MODE)"
                              SCENE_FAIL=1; return 0
                            fi
                            echo "taskbar-add-widgets: $WID → $ZONE add/remove ok"
                          done
                          done
                          shot taskbar-add-widgets ;;
    # Needs NOSD_FAKE_PORTAL=<0|1|2> (spawns Scripts/test/fake-portal.py owning
    # org.freedesktop.portal.Desktop on the private bus) plus a settings seed
    # with colorSchemes.schedulingMode=system:
    #   NOSD_FAKE_PORTAL=1 ./verify.sh <run> --settings seed.json --scenes dark-mode-system
    # The fake answers Settings.ReadOne (initial darkMode apply — watch the
    # "System color-scheme changed" INFO line in the run log) and emits real
    # SettingChanged signals through its org.nosd.verify.FakePortal.Emit
    # method; each flip is shot to show the whole shell retokenizing.
    dark-mode-system)     if [ -z "${NOSD_FAKE_PORTAL:-}" ]; then
                            echo "dark-mode-system: needs NOSD_FAKE_PORTAL=1 and a schedulingMode=system seed"
                          else
                            sleep 1; shot dark-mode-initial
                            for V in 2 0 1; do
                              dbus-send --session --print-reply --dest=org.nosd.verify.FakePortal \
                                /org/freedesktop/portal/desktop \
                                org.nosd.verify.FakePortal.Emit uint32:$V 2>&1 \
                                || echo "Emit $V failed"
                              sleep 1.5
                              shot "dark-mode-emit-$V"
                            done
                            grep "color-scheme" "$LOG" || true
                          fi ;;
    # Keep Awake vs the shell's own idle actions (upstream #2418): while
    # idleInhibitor is on, "Executing action: screenOff" must never reach the
    # log; after it is released screenOff must fire (positive control — a
    # real pointer jiggle re-arms the compositor idle transition in case the
    # inhibitor was honoured all along). Needs a seed with idle.enabled and a
    # small screenOffTimeout (see header). NOTE: sway treats inhibitors
    # without a view (layer-shell) as always active, so here the scene
    # asserts the user-visible invariant; on compositors that scope
    # inhibition to visible surfaces it exercises the suppression path.
    idle-inhibit)        read IDLE_TO IDLE_FADE < <(python3 - "$USER_SETTINGS" <<'PYEOF'
import json,os,sys
base=json.load(open(os.environ["REPO"]+"/Assets/settings-default.json"))
if sys.argv[1]:
    def merge(a,b):
        for k,v in b.items():
            if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
            else: a[k]=v
    merge(base, json.load(open(sys.argv[1])))
idle=base.get("idle",{})
print(idle.get("screenOffTimeout",600), idle.get("fadeDuration",5))
PYEOF
)
                         echo "idle-inhibit: screenOffTimeout=${IDLE_TO}s fade=${IDLE_FADE}s"
                         MARK=$(wc -l < "$LOG")
                         qs -p "$REPO" ipc call idleInhibitor enable || true
                         # Screenshot now — after phase B the screenOff action has
                         # powered the outputs off (dpms) and grim gets no formats.
                         sleep 2; shot idle-inhibit
                         sleep $(( IDLE_TO + IDLE_FADE + 4 ))
                         if tail -n +$(( MARK + 1 )) "$LOG" | grep -q "Executing action: screenOff"; then
                           echo "FAIL idle-inhibit: screenOff fired while Keep Awake is on"
                           SCENE_FAIL=1
                         else
                           echo "idle-inhibit: no screenOff while inhibited (ok)"
                         fi
                         qs -p "$REPO" ipc call idleInhibitor disable || true
                         MARK=$(wc -l < "$LOG")
                         VINPUT="$REPO/tools/nosd-helpers/target/release/nosd-helpers"
                         [ -x "$VINPUT" ] || VINPUT="$REPO/tools/nosd-helpers/target/debug/nosd-helpers"
                         "$VINPUT" vinput move 960 540 2>>"$WORK/logs/vinput.log" || true
                         "$VINPUT" vinput move 970 545 2>>"$WORK/logs/vinput.log" || true
                         sleep $(( IDLE_TO + IDLE_FADE + 6 ))
                         if tail -n +$(( MARK + 1 )) "$LOG" | grep -q "Executing action: screenOff"; then
                           echo "idle-inhibit: screenOff fired after uninhibit (control ok)"
                         else
                           echo "FAIL idle-inhibit: screenOff never fired without inhibitor"
                           SCENE_FAIL=1
                         fi
                         # screenOff ran `swaymsg output * dpms off`; power the outputs
                         # back so any scene scheduled after this one isn't poisoned.
                         swaymsg "output * dpms on" >/dev/null 2>&1 || true ;;
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
[ "${SCENE_FAIL:-0}" -ne 0 ] && { echo "=== DONE (scene failures) ==="; exit 1; }
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
