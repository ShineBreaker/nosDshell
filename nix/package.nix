{
  version ? "1.7.6.1",
  extraPackages ? [ ],
  runtimeDeps ? [
    brightnessctl
    cava
    cliphist
    ddcutil
    util-linux
    wlsunset
    wl-clipboard
    wlr-randr
    imagemagick
    wget
  ],

  lib,
  stdenvNoCC,
  # build
  qt6,
  quickshell,
  # runtime deps
  brightnessctl,
  cava,
  cliphist,
  ddcutil,
  util-linux,
  wlsunset,
  wl-clipboard,
  wlr-randr,
  imagemagick,
  wget,
  wayland-scanner,
  # calendar support
  calendarSupport ? false,
  evolution-data-server,
  libical,
  glib,
  libsoup_3,
  json-glib,
  gobject-introspection,
}:
let
  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      !(builtins.any (prefix: lib.path.hasPrefix (../. + prefix) (/. + path)) [
        /.github
        /.gitignore
        /Assets/Screenshots
        /Scripts/dev
        /nix
        /LICENSE
        /README.md
        /flake.nix
        /flake.lock
        /shell.nix
        /lefthook.yml
        /CLAUDE.md
        /CREDITS.md
      ]);
  };

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    evolution-data-server
    libical
    glib.out
    libsoup_3
    json-glib
    gobject-introspection
  ];
in
stdenvNoCC.mkDerivation {
  pname = "nosdshell";
  inherit version src;

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtmultimedia
  ];

  installPhase = ''
    mkdir -p $out/share/nosdshell $out/bin
    cp -r . $out/share/nosdshell
    cat > $out/bin/nosdshell <<'EOF'
#!${stdenvNoCC.shell}
# --version/-V reports the shell and quickshell versions without
# starting the shell (lowercase -v is quickshell's verbose flag and
# must fall through); everything else goes to quickshell.
if [ "$1" = "--version" ] || [ "$1" = "-V" ]; then
  echo "nosdshell v${version} (with quickshell v${quickshell.version})"
  exit 0
fi
# Long-running shell (~60 threads): cap glibc malloc arenas and pin the
# mmap/trim thresholds so transient large allocations (screen-size
# wallpaper QImages) go straight back to the kernel instead of stranding
# freed pages in per-thread arenas (observed 1.2 GB RSS + 0.9 GB swap
# after two days without these).  Overridable via the environment; glibc
# reads them at startup, hence before exec.
: "''${MALLOC_ARENA_MAX:=4}"
: "''${MALLOC_MMAP_THRESHOLD_:=131072}"
: "''${MALLOC_TRIM_THRESHOLD_:=131072}"
export MALLOC_ARENA_MAX MALLOC_MMAP_THRESHOLD_ MALLOC_TRIM_THRESHOLD_
exec ${quickshell}/bin/qs "$@"
EOF
    chmod +x $out/bin/nosdshell
    mkdir -p $out/share/bash-completion/completions $out/share/zsh/site-functions $out/share/fish/vendor_completions.d
    cp completions/nosdshell.bash $out/share/bash-completion/completions/nosdshell
    cp completions/_nosdshell $out/share/zsh/site-functions/_nosdshell
    cp completions/nosdshell.fish $out/share/fish/vendor_completions.d/nosdshell.fish
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath (runtimeDeps ++ extraPackages)}
      --prefix XDG_DATA_DIRS : ${wayland-scanner}/share
      --set-default QS_CONFIG_PATH "$out/share/nosdshell"
      ${lib.optionalString calendarSupport "--prefix GI_TYPELIB_PATH : ${giTypelibPath}"}
    )
  '';

  meta = {
    description = "Wayland desktop shell in the DDE 15 visual language, built with Quickshell.";
    homepage = "https://github.com/nosDshell/nosDshell";
    license = lib.licenses.gpl3Plus;
    mainProgram = "nosdshell";
  };
}
