# Package set for the test harness on the nix backend (Scripts/test/lib/pkgenv.sh).
#
# One superset environment serves every script: verify.sh, bench.sh,
# debug-smoke.sh, repro-hover-crash.sh and lint.sh. guix resolves each
# script's own `$PKGS` list; on nix those lists are ignored and this file is
# the single source. When a script's guix list gains a package, add its
# nixpkgs counterpart here (the comment after each entry names the guix one).
#
# nixpkgs comes from the repository's flake.lock (pkgenv.sh passes its store
# path), so the harness runs the same quickshell/Qt build as `nix develop`.
{ nixpkgs }:
let
  pkgs = import nixpkgs { };
  qt = pkgs.kdePackages;
  python = pkgs.python3.withPackages (ps: [
    ps.dbus-python # python-dbus
    ps.pygobject3 # python-pygobject
    ps.pillow # python-pillow
  ]);
  fonts = [
    pkgs.noto-fonts # font-google-noto
    pkgs.noto-fonts-cjk-sans # font-google-noto-sans-cjk
  ];
  # The nixpkgs dbus-run-session has no compiled-in session.conf path that
  # exists outside NixOS; pin it so the scripts can keep calling it bare.
  dbusRunSession = pkgs.writeShellScriptBin "dbus-run-session" ''
    exec ${pkgs.dbus}/bin/dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf "$@"
  '';
in
pkgs.buildEnv {
  name = "nosdshell-test-env";
  paths = [
    (pkgs.lib.hiPrio dbusRunSession)
    pkgs.quickshell # quickshell
    pkgs.sway # sway
    pkgs.grim # grim
    pkgs.dbus # dbus
    pkgs.imagemagick # imagemagick
    pkgs.libnotify # libnotify
    pkgs.pipewire # pipewire
    pkgs.wireplumber # wireplumber
    pkgs.foot # foot
    pkgs.wlrctl # wlrctl
    pkgs.niri # niri (repro-hover-crash.sh)
    pkgs.gdb # gdb
    pkgs.binutils # binutils
    pkgs.desktop-file-utils # update-desktop-database
    pkgs.papirus-icon-theme # papirus-icon-theme
    pkgs.adwaita-icon-theme # adwaita-icon-theme
    pkgs.hicolor-icon-theme
    pkgs.mesa # GL/EGL for the client (llvmpipe when no GPU)
    pkgs.glib # GI typelibs for python-pygobject
    pkgs.gobject-introspection
    qt.qtdeclarative # qmllint, qmlformat (qtdeclarative)
    qt.qtwayland # qtwayland
    qt.qtmultimedia # qtmultimedia
    qt.qt5compat # qt5compat
    qt.qtimageformats # qtimageformats
    qt.qtsvg
    python # python + python-dbus/pygobject/pillow
  ]
  ++ fonts;
  pathsToLink = [
    "/bin"
    "/lib"
    "/share"
  ];
  extraOutputsToInstall = [ "out" ];
  postBuild = ''
    cp ${pkgs.makeFontsConf { fontDirectories = fonts; }} $out/fonts.conf
    echo ${pkgs.quickshell} > $out/quickshell-path
  '';
}
