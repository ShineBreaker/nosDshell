{
  version ? "dirty",
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
    (python3.withPackages (pp: lib.optional calendarSupport pp.pygobject3))
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
  python3,
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
    ln -s ${quickshell}/bin/qs $out/bin/nosdshell
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
    homepage = "https://github.com/ShineBreaker/nosDshell";
    license = lib.licenses.gpl3Plus;
    mainProgram = "nosdshell";
  };
}
