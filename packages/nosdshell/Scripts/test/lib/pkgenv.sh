# Package backend for the test harness. Source this file, then run commands
# with `nosd_pkg_run "<guix package list>" cmd args...`.
#
# NOSD_PKG_BACKEND selects where the tools come from:
#   guix  `guix shell <list> -- cmd`: the default on the Guix dev machine.
#   nix   the superset environment in Scripts/test/lib/testenv.nix, built
#         from the nixpkgs pinned in flake.lock: for Nix hosts and the
#         cloud containers agents run in (see DEBUGGING.md「运行环境」).
#   auto  (default) guix when `guix` is on PATH, else nix, else fail.
#
# With no GPU render node (/dev/dri/renderD*), both backends switch the
# compositor to wlroots' pixman renderer and the client to Mesa llvmpipe;
# the shell then renders shaders (MultiEffect shadows, blur) in software.
#
# The isolated session has no platform theme, so Qt would look icons up in
# hicolor alone and every app icon, fallback included, would fail to load.
# QS_ICON_THEME (read by quickshell at start) selects Papirus, which both
# package lists ship; set it yourself to try another theme.

NOSD_PKGENV_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

nosd_pkg_backend() {
  case "${NOSD_PKG_BACKEND:-auto}" in
    guix | nix) echo "$NOSD_PKG_BACKEND" ;;
    auto)
      if command -v guix > /dev/null; then echo guix
      elif command -v nix > /dev/null; then echo nix
      else echo none
      fi ;;
    *) echo "invalid NOSD_PKG_BACKEND=${NOSD_PKG_BACKEND}" >&2; echo none ;;
  esac
}

# Prints the store path of the nix test environment, building it on first use.
nosd_nix_env() {
  local nixpkgs
  nixpkgs=$(nix eval --raw --inputs-from "$NOSD_PKGENV_REPO" nixpkgs#path) || return 1
  nix build --no-link --print-out-paths --impure \
    --expr "import $NOSD_PKGENV_REPO/Scripts/test/lib/testenv.nix { nixpkgs = $nixpkgs; }" | tail -1
}

nosd_software_render_env() {
  if ! ls /dev/dri/renderD* > /dev/null 2>&1; then
    export WLR_RENDERER=pixman LIBGL_ALWAYS_SOFTWARE=1
  fi
}

# nosd_pkg_run "<guix packages>" cmd args...
nosd_pkg_run() {
  local pkgs="$1"
  shift
  nosd_software_render_env
  export QS_ICON_THEME="${QS_ICON_THEME:-Papirus}"
  case "$(nosd_pkg_backend)" in
    guix)
      # shellcheck disable=SC2086 # the package list is word-split on purpose
      guix shell $pkgs -- "$@"
      ;;
    nix)
      local env
      env=$(nosd_nix_env) || { echo "nix test environment failed to build" >&2; return 1; }
      # Outside NixOS there is no /run/opengl-driver: point glvnd at the
      # environment's Mesa (hardware drivers included, llvmpipe fallback).
      local egl=()
      [ -d /run/opengl-driver ] || egl=(
        "__EGL_VENDOR_LIBRARY_FILENAMES=$env/share/glvnd/egl_vendor.d/50_mesa.json"
        "LIBGL_DRIVERS_PATH=$env/lib/dri"
        "GBM_BACKENDS_PATH=$env/lib/gbm"
      )
      env "PATH=$env/bin:$PATH" \
        "QML_IMPORT_PATH=$env/lib/qt-6/qml" \
        "QT_PLUGIN_PATH=$env/lib/qt-6/plugins" \
        "XDG_DATA_DIRS=$env/share" \
        "FONTCONFIG_FILE=$env/fonts.conf" \
        "GI_TYPELIB_PATH=$env/lib/girepository-1.0" \
        "NOSD_QSQML=$(cat "$env/quickshell-path")/lib/qt-6/qml" \
        "NOSD_QTQML=$env/lib/qt-6/qml" \
        "${egl[@]}" \
        "$@"
      ;;
    *)
      echo "no package backend: install guix or nix (see DEBUGGING.md「运行环境」)" >&2
      return 2
      ;;
  esac
}
