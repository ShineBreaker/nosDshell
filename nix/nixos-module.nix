{
  config,
  lib,
  ...
}:
let
  cfg = config.services.nosdshell;
in
{
  imports = map (o: lib.mkRenamedOptionModule [ "services" "noctalia-shell" o ] [ "services" "nosdshell" o ]) [
    "enable"
    "package"
    "target"
  ];

  options.services.nosdshell = {
    enable = lib.mkEnableOption "nosDshell systemd service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The nosdshell package to use";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "The systemd target for the nosdshell service.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = [
      ''
        Running nosdshell as a systemd service has been deprecated!
      ''
    ];
    systemd.user.services.nosdshell = {
      description = "nosDshell - Wayland desktop shell";
      after = [ cfg.target ];
      partOf = [ cfg.target ];
      wantedBy = [ cfg.target ];
      restartTriggers = [ cfg.package ];

      environment = {
        PATH = lib.mkForce null;
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
