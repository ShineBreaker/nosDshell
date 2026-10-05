{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nosdshell;
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };

  generateJson =
    name: value:
    if lib.isString value then
      pkgs.writeText "nosd-${name}.json" value
    else if builtins.isPath value || lib.isStorePath value then
      value
    else
      jsonFormat.generate "nosd-${name}.json" value;
in
{
  imports =
    map (o: lib.mkRenamedOptionModule [ "programs" "noctalia-shell" o ] [ "programs" "nosdshell" o ]) [
      "enable"
      "package"
      "settings"
      "colors"
      "user-templates"
      "plugins"
      "pluginSettings"
    ]
    ++ [
      (lib.mkRenamedOptionModule [ "programs" "noctalia-shell" "systemd" "enable" ] [
        "programs"
        "nosdshell"
        "systemd"
        "enable"
      ])
    ];

  options.programs.nosdshell = {
    enable = lib.mkEnableOption "nosDshell configuration";

    systemd.enable = lib.mkEnableOption "nosDshell systemd integration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The nosdshell package to use";
    };

    settings = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          bar = {
            position = "bottom";
            floating = true;
            backgroundOpacity = 0.95;
          };
          general = {
            animationSpeed = 1.5;
            radiusRatio = 1.2;
          };
          colorSchemes = {
            darkMode = true;
            useWallpaperColors = true;
          };
        }
      '';
      description = ''
        nosDshell configuration settings as an attribute set, string
        or filepath, to be written to ~/.config/nosdshell/settings.json.
      '';
    };

    colors = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
         {
           mError = "#dddddd";
           mOnError = "#111111";
           mOnPrimary = "#111111";
           mOnSecondary = "#111111";
           mOnSurface = "#828282";
           mOnSurfaceVariant = "#5d5d5d";
           mOnTertiary = "#111111";
           mOutline = "#3c3c3c";
           mPrimary = "#aaaaaa";
           mSecondary = "#a7a7a7";
           mShadow = "#000000";
           mSurface = "#111111";
           mSurfaceVariant = "#191919";
           mTertiary = "#cccccc";
        }
      '';
      description = ''
        nosDshell color configuration as an attribute set, string
        or filepath, to be written to ~/.config/nosdshell/colors.json.
      '';
    };

    user-templates = lib.mkOption {
      default = { };
      type =
        with lib.types;
        oneOf [
          tomlFormat.type
          str
          path
        ];
      example = lib.literalExpression ''
        {
          templates = {
            neovim = {
              input_path = "~/.config/nosdshell/templates/template.lua";
              output_path = "~/.config/nvim/generated.lua";
              post_hook = "pkill -SIGUSR1 nvim";
            };
          };
        }
      '';
      description = ''
        Template definitions for nosDshell, to be written to ~/.config/nosdshell/user-templates.toml.

        This option accepts:
        - a Nix attrset (converted to TOML automatically)
        - a string containing raw TOML
        - a path to an existing TOML file
      '';
    };

    plugins = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          sources = [
            {
              enabled = true;
              name = "Example Plugins";
              url = "https://github.com/example/example-plugins";
            }
          ];
          states = {
            catwalk = {
              enabled = true;
              sourceUrl = "https://github.com/example/example-plugins";
            };
          };
          version = 2;
        }
      '';
      description = ''
        nosDshell plugin configuration as an attribute set, string
        or filepath, to be written to ~/.config/nosdshell/plugins.json.
      '';
    };

    pluginSettings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          jsonFormat.type
          str
          path
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          catwalk = {
            minimumThreshold = 25;
            hideBackground = true;
          };
        }
      '';
      description = ''
        Each plugin’s settings as an attribute set, string
        or filepath, to be written to
        ~/.config/nosdshell/plugins/plugin-name/settings.json.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.mkIf cfg.systemd.enable [
      ''
        Running nosdshell as a systemd service has been deprecated!
      ''
    ];

    systemd.user.services.nosdshell = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "nosDshell - Wayland desktop shell";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers =
          lib.optional (cfg.settings != { }) "${config.xdg.configFile."nosdshell/settings.json".source}"
          ++ lib.optional (cfg.colors != { }) "${config.xdg.configFile."nosdshell/colors.json".source}"
          ++ lib.optional (cfg.plugins != { }) "${config.xdg.configFile."nosdshell/plugins.json".source}"
          ++ lib.optional (
            cfg.user-templates != { }
          ) "${config.xdg.configFile."nosdshell/user-templates.toml".source}"
          ++ lib.mapAttrsToList (
            name: _: "${config.xdg.configFile."nosdshell/plugins/${name}/settings.json".source}"
          ) cfg.pluginSettings;
      };

      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    home.packages = lib.optional (cfg.package != null) cfg.package;

    xdg.configFile = {
      "nosdshell/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = generateJson "settings" cfg.settings;
      };
      "nosdshell/colors.json" = lib.mkIf (cfg.colors != { }) {
        source = generateJson "colors" cfg.colors;
      };
      "nosdshell/plugins.json" = lib.mkIf (cfg.plugins != { }) {
        source = generateJson "plugins" cfg.plugins;
      };
      "nosdshell/user-templates.toml" = lib.mkIf (cfg.user-templates != { }) {
        source =
          if lib.isString cfg.user-templates then
            pkgs.writeText "nosd-user-templates.toml" cfg.user-templates
          else if builtins.isPath cfg.user-templates || lib.isStorePath cfg.user-templates then
            cfg.user-templates
          else
            tomlFormat.generate "nosd-user-templates.toml" cfg.user-templates;
      };
    }
    // lib.mapAttrs' (
      name: value:
      lib.nameValuePair "nosdshell/plugins/${name}/settings.json" {
        source = generateJson "${name}-settings" value;
      }
    ) cfg.pluginSettings;

    assertions = [
      {
        assertion = !cfg.systemd.enable || cfg.package != null;
        message = "nosdshell: The package option must not be null when systemd service is enabled.";
      }
    ];
  };
}
