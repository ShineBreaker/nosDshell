pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  Component.onCompleted: {
    if (Settings.data.templates.enableUserTheming)
    writeUserTemplatesToml();
  }

  // Rust helpers (tools/nosd-helpers): PATH install, else the in-tree
  // release binary. Empty until the detector below finishes; the *Cmd
  // builders below return null until then, and callers must tolerate it.
  // There is no script fallback: the python helpers were removed once the
  // Rust ports reached parity.
  property string helpersBin: ""

  function helperCmd(sub, args) {
    if (root.helpersBin !== "")
      return [root.helpersBin, sub].concat(args);
    return null;
  }
  function gtkRefreshCmd(mode) {
    return root.helperCmd("gtk-refresh", [mode]);
  }
  function kdeApplyCmd(scheme) {
    return root.helperCmd("kde-apply-scheme", [scheme]);
  }
  function vscodeCmd(extensionsDir) {
    return root.helperCmd("vscode-themes", [extensionsDir]);
  }
  function khalEventsCmd(startDate, duration) {
    return root.helperCmd("khal-events", [startDate, duration]);
  }
  function edsCheckCmd() {
    return root.helperCmd("eds-check", []);
  }
  function edsCalendarsCmd() {
    return root.helperCmd("eds-calendars", []);
  }
  function edsEventsCmd(startTime, endTime) {
    return root.helperCmd("eds-events", [startTime, endTime]);
  }
  // nosd-theme binary (tools/nosd-theme): PATH install, else the in-tree
  // release binary. Empty until the detector below finishes.
  property string themeBin: ""
  // Command prefix for template-processor invocations: the Rust binary.
  // Same CLI the python implementation had.
  function themeProcessorCmd() {
    return root.themeBin;
  }
  // Shell one-liners for template post_hook entries (evaluated at apply time).
  function gtkRefreshHook(mode) {
    return `${root.helpersBin} gtk-refresh ${mode}`;
  }
  function kdeApplyHook(scheme) {
    return `${root.helpersBin} kde-apply-scheme ${scheme}`;
  }
  // Shell one-liner for template-apply post_hook entries (evaluated at
  // apply time): `nosd-helpers apply`.
  function applyHook(app, mode) {
    const tail = (mode !== undefined && mode !== "") ? ` ${mode}` : "";
    return `${root.helpersBin} apply ${app}${tail}`;
  }

  Process {
    id: helpersDetectProcess
    command: ["sh", "-c", "command -v nosd-helpers || { p=\"" + Quickshell.shellDir + "/tools/nosd-helpers/target/release/nosd-helpers\"; [ -x \"$p\" ] && printf '%s' \"$p\"; }"]
    running: true
    stdout: StdioCollector {}
    onExited: {
      root.helpersBin = stdout.text.trim();
      if (root.helpersBin !== "")
      Logger.i("Theming", "nosd-helpers available:", root.helpersBin);
      else
      Logger.w("Theming", "nosd-helpers not found; theming helpers are unavailable");
      codeResolverProcess.running = root.helpersBin !== "";
      codiumResolverProcess.running = root.helpersBin !== "";
    }
  }

  Process {
    id: themeDetectProcess
    command: ["sh", "-c", "command -v nosd-theme || { p=\"" + Quickshell.shellDir + "/tools/nosd-theme/target/release/nosd-theme\"; [ -x \"$p\" ] && printf '%s' \"$p\"; }"]
    running: true
    stdout: StdioCollector {}
    onExited: {
      root.themeBin = stdout.text.trim();
      if (root.themeBin !== "")
      Logger.i("Theming", "nosd-theme available:", root.themeBin);
      else
      Logger.w("Theming", "nosd-theme not found; template processing is unavailable");
    }
  }

  // Dynamically resolved VSCode extension theme paths (all matching nosd extensions)
  property var resolvedCodePaths: []
  property var resolvedCodiumPaths: []

  // Terminal configurations (for wallpaper-based templates)
  // Each terminal must define a postHook that sets up config includes and triggers reload
  readonly property var terminals: [
    {
      "id": "foot",
      "name": "Foot",
      "templatePath": "terminal/foot",
      "predefinedTemplatePath": "terminal/foot-predefined",
      "outputPath": "~/.config/foot/themes/nosdshell",
      "postHook": `${applyHook("foot")}`
    },
    {
      "id": "ghostty",
      "name": "Ghostty",
      "templatePath": "terminal/ghostty",
      "predefinedTemplatePath": "terminal/ghostty-predefined",
      "outputPath": "~/.config/ghostty/themes/nosdshell",
      "postHook": `${applyHook("ghostty")}`
    },
    {
      "id": "kitty",
      "name": "Kitty",
      "templatePath": "terminal/kitty.conf",
      "predefinedTemplatePath": "terminal/kitty-predefined.conf",
      "outputPath": "~/.config/kitty/themes/nosdshell.conf",
      "postHook": `${applyHook("kitty")}`
    },
    {
      "id": "alacritty",
      "name": "Alacritty",
      "templatePath": "terminal/alacritty.toml",
      "predefinedTemplatePath": "terminal/alacritty-predefined.toml",
      "outputPath": "~/.config/alacritty/themes/nosdshell.toml",
      "postHook": `${applyHook("alacritty")}`
    },
    {
      "id": "wezterm",
      "name": "Wezterm",
      "templatePath": "terminal/wezterm.toml",
      "predefinedTemplatePath": "terminal/wezterm-predefined.toml",
      "outputPath": "~/.config/wezterm/colors/nosDshell.toml",
      "postHook": `${applyHook("wezterm")}`
    },
    {
      "id": "starship",
      "name": "Starship",
      "templatePath": "terminal/starship.toml",
      "predefinedTemplatePath": "terminal/starship-predefined.toml",
      "outputPath": "~/.cache/nosdshell/starship-palette.toml",
      "postHook": `${applyHook("starship")}`
    }
  ]

  // Application configurations - consolidated from Theming + AppThemeService
  readonly property var applications: [
    {
      "id": "gtk",
      "name": "GTK",
      "category": "system",
      "input": "gtk4.css",
      "outputs": [
        {
          "path": "~/.config/gtk-3.0/nosd.css",
          "input": "gtk3.css"
        },
        {
          "path": "~/.config/gtk-4.0/nosd.css",
          "input": "gtk4.css"
        }
      ],
      "postProcess": mode => root.gtkRefreshHook(mode)
    },
    {
      "id": "qt",
      "name": "Qt",
      "category": "system",
      "input": "qtct.conf",
      "outputs": [
        {
          "path": "~/.config/qt5ct/colors/nosdshell.conf"
        },
        {
          "path": "~/.config/qt6ct/colors/nosdshell.conf"
        }
      ]
    },
    {
      "id": "kcolorscheme",
      "name": "KColorScheme",
      "category": "system",
      "input": "kcolorscheme.colors",
      "outputs": [
        {
          "path": "~/.local/share/color-schemes/nosd.colors"
        }
      ],
      "postProcess": () => root.kdeApplyHook("nosd")
    },
    {
      "id": "fuzzel",
      "name": "Fuzzel",
      "category": "launcher",
      "input": "fuzzel.conf",
      "outputs": [
        {
          "path": "~/.config/fuzzel/themes/nosdshell"
        }
      ],
      "postProcess": () => `${applyHook("fuzzel")}`
    },
    {
      "id": "vicinae",
      "name": "Vicinae",
      "category": "launcher",
      "input": "vicinae.toml",
      "outputs": [
        {
          "path": "~/.local/share/vicinae/themes/nosdshell.toml"
        }
      ],
      "postProcess": () => `cp --update=none ${Quickshell.shellDir}/Assets/noctalia.svg ~/.local/share/vicinae/themes/noctalia.svg && ${applyHook("vicinae")}`
    },
    {
      "id": "walker",
      "name": "Walker",
      "category": "launcher",
      "input": "walker.css",
      "outputs": [
        {
          "path": "~/.config/walker/themes/nosdshell/style.css"
        }
      ],
      "postProcess": () => `${applyHook("walker")}`,
      "strict": true // Use strict mode for palette generation (preserves custom surface/outline values)
    },
    {
      "id": "pywalfox",
      "name": "Pywalfox",
      "category": "browser",
      "input": "pywalfox.json",
      "outputs": [
        {
          "path": "~/.cache/wal/colors.json"
        }
      ],
      "postProcess": mode => `${applyHook("pywalfox", mode)}`
    } // CONSOLIDATED DISCORD CLIENTS
    ,
    {
      "id": "discord",
      "name": "Discord",
      "category": "misc",
      "input": ["discord-midnight.css", "discord-material.css"],
      "clients": [
        {
          "name": "vesktop",
          "path": "~/.config/vesktop"
        },
        {
          "name": "webcord",
          "path": "~/.config/webcord"
        },
        {
          "name": "armcord",
          "path": "~/.config/armcord"
        },
        {
          "name": "equibop",
          "path": "~/.config/equibop"
        },
        {
          "name": "equicord",
          "path": "~/.config/Equicord"
        },
        {
          "name": "lightcord",
          "path": "~/.config/lightcord"
        },
        {
          "name": "dorion",
          "path": "~/.config/dorion"
        },
        {
          "name": "vencord",
          "path": "~/.config/Vencord"
        },
        {
          "name": "vencord-flatpak",
          "path": "~/.var/app/com.discordapp.Discord/config/Vencord"
        },
        {
          "name": "betterdiscord",
          "path": "~/.config/BetterDiscord"
        }
      ]
    },
    {
      "id": "code",
      "name": "VSCode",
      "category": "editor",
      "input": "code.json",
      "clients": [
        {
          "name": "code",
          "path": "~/.vscode/extensions/nosd.nosdtheme-0.0.5/themes/NosdTheme-color-theme.json"
        },
        {
          "name": "codium",
          "path": "~/.vscode-oss/extensions/nosd.nosdtheme-0.0.5-universal/themes/NosdTheme-color-theme.json"
        }
      ]
    },
    {
      "id": "zed",
      "name": "Zed",
      "category": "editor",
      "input": "zed.json",
      "outputs": [
        {
          "path": "~/.config/zed/themes/nosdshell.json"
        }
      ],
      "dualMode": true // Template contains both dark and light theme patterns
    },
    {
      "id": "helix",
      "name": "Helix",
      "category": "editor",
      "input": "helix.toml",
      "outputs": [
        {
          "path": "~/.config/helix/themes/nosdshell.toml"
        }
      ]
    },
    {
      "id": "spicetify",
      "name": "Spicetify",
      "category": "audio",
      "input": "spicetify.ini",
      "outputs": [
        {
          "path": "~/.config/spicetify/Themes/Comfy/color.ini"
        }
      ],
      "postProcess": () => `spicetify -q apply --no-restart`
    },
    {
      "id": "telegram",
      "name": "Telegram",
      "category": "misc",
      "input": "telegram.tdesktop-theme",
      "outputs": [
        {
          "path": "~/.config/telegram-desktop/themes/nosdshell.tdesktop-theme"
        }
      ]
    },
    {
      "id": "zenBrowser",
      "name": "Zen Browser",
      "category": "browser",
      "input": "zen-browser/zen-userChrome.css",
      "outputs": [
        {
          "path": "~/.cache/nosdshell/zen-browser/zen-userChrome.css"
        },
        {
          "path": "~/.cache/nosdshell/zen-browser/zen-userContent.css",
          "input": "zen-browser/zen-userContent.css"
        }
      ],
      "postProcess": ()
                     => "sh -c 'CSS_CHROME=\"$HOME/.cache/nosdshell/zen-browser/zen-userChrome.css\"; CSS_CONTENT=\"$HOME/.cache/nosdshell/zen-browser/zen-userContent.css\"; LINE_CHROME=\"@import \\\"$CSS_CHROME\\\";\"; LINE_CONTENT=\"@import \\\"$CSS_CONTENT\\\";\"; find \"$HOME/.config/zen\" \"$HOME/.zen\" -mindepth 2 -maxdepth 2 -type d -name chrome -print0 2>/dev/null | while IFS= read -r -d \"\" dir; do USER_CHROME=\"$dir/userChrome.css\"; USER_CONTENT=\"$dir/userContent.css\"; mkdir -p \"$dir\"; touch \"$USER_CHROME\" \"$USER_CONTENT\"; sed -i \"/zen-browser\\/zen-userChrome\\.css/d\" \"$USER_CHROME\"; sed -i \"/zen-browser\\/zen-userContent\\.css/d\" \"$USER_CONTENT\"; if ! grep -Fq \"$LINE_CHROME\" \"$USER_CHROME\"; then printf \"%s\\n\" \"$LINE_CHROME\" >> \"$USER_CHROME\"; fi; if ! grep -Fq \"$LINE_CONTENT\" \"$USER_CONTENT\"; then printf \"%s\\n\" \"$LINE_CONTENT\" >> \"$USER_CONTENT\"; fi; done'"
    },
    {
      "id": "cava",
      "name": "Cava",
      "category": "audio",
      "input": "cava.ini",
      "outputs": [
        {
          "path": "~/.config/cava/themes/nosdshell"
        }
      ],
      "postProcess": () => `${applyHook("cava")}`
    },
    {
      "id": "yazi",
      "name": "Yazi",
      "category": "misc",
      "input": "yazi.toml",
      "outputs": [
        {
          "path": "~/.config/yazi/flavors/nosdshell.yazi/flavor.toml"
        }
      ],
      "postProcess": () => `${applyHook("yazi")}`
    },
    {
      "id": "emacs",
      "name": "Emacs",
      "category": "editor",
      "input": "emacs.el",
      "postProcess": () => `emacsclient -e "(load-theme 'nosdshell t)"`
    },
    {
      "id": "labwc",
      "name": "Labwc",
      "category": "compositor",
      "input": "labwc.conf",
      "outputs": [
        {
          "path": "~/.config/labwc/themerc-override"
        }
      ],
      "postProcess": () => `${applyHook("labwc")}`
    },
    {
      "id": "niri",
      "name": "Niri",
      "category": "compositor",
      "input": "niri.kdl",
      "outputs": [
        {
          "path": "~/.config/niri/nosdshell.kdl"
        }
      ],
      "postProcess": () => `${applyHook("niri")}`
    },
    {
      "id": "sway",
      "name": "Sway",
      "category": "compositor",
      "input": "sway",
      "outputs": [
        {
          "path": "~/.config/sway/nosdshell"
        }
      ],
      "postProcess": () => `${applyHook("sway")}`
    },
    {
      "id": "scroll",
      "name": "Scroll",
      "category": "compositor",
      "input": "scroll",
      "outputs": [
        {
          "path": "~/.config/scroll/nosdshell"
        }
      ],
      "postProcess": () => `${applyHook("scroll")}`
    },
    {
      "id": "hyprland",
      "name": "Hyprland",
      "category": "compositor",
      "input": "hyprland.conf",
      "outputs": [
        {
          "path": "~/.config/hypr/nosdshell/nosdshell-colors.conf",
          "postProcess": false
        },
        {
          "path": "~/.config/hypr/nosdshell/nosdshell-colors.lua",
          "input": "hyprland.lua"
        },
      ],
      "postProcess": () => `${applyHook("hyprland")}`
    },
    {
      "id": "hyprtoolkit",
      "name": "Hyprtoolkit",
      "category": "system",
      "input": "hyprtoolkit.conf",
      "outputs": [
        {
          "path": "~/.config/hypr/hyprtoolkit.conf"
        }
      ]
    },
    {
      "id": "mango",
      "name": "Mango",
      "category": "compositor",
      "input": "mango.conf",
      "outputs": [
        {
          "path": "~/.config/mango/nosdshell.conf"
        }
      ],
      "postProcess": () => `${applyHook("mango")}`
    },
    {
      "id": "btop",
      "name": "btop",
      "category": "misc",
      "input": "btop.theme",
      "outputs": [
        {
          "path": "~/.config/btop/themes/nosdshell.theme"
        }
      ],
      "postProcess": () => `${applyHook("btop")}`
    },
    {
      "id": "zathura",
      "name": "Zathura",
      "category": "misc",
      "input": "zathurarc",
      "outputs": [
        {
          "path": "~/.config/zathura/nosdshellrc"
        }
      ],
      "postProcess": () => `${applyHook("zathura")}`
    },
    {
      "id": "steam",
      "name": "Steam",
      "category": "misc",
      "input": "steam.css",
      "outputs": [
        {
          "path": "~/.steam/steam/steamui/skins/Material-Theme/css/main/colors/matugen.css"
        }
      ]
    }
  ]

  // Extract Discord clients for ProgramCheckerService compatibility
  readonly property var discordClients: {
    var clients = [];
    var discordApp = applications.find(app => app.id === "discord");
    if (discordApp && discordApp.clients) {
      discordApp.clients.forEach(client => {
                                   clients.push({
                                                  "name": client.name,
                                                  "configPath": client.path,
                                                  "themePath": `${client.path}/themes/nosdshell.theme.css`
                                                });
                                 });
    }
    return clients;
  }

  // Get resolved theme paths for a code client (returns array of all matching paths)
  function resolvedCodeClientPaths(clientName) {
    if (clientName === "code")
      return resolvedCodePaths;
    if (clientName === "codium")
      return resolvedCodiumPaths;
    return [];
  }

  // Extract Code clients for ProgramCheckerService compatibility
  readonly property var codeClients: {
    var clients = [];
    var codeApp = applications.find(app => app.id === "code");
    if (codeApp && codeApp.clients) {
      codeApp.clients.forEach(client => {
                                // Extract base config directory from theme path
                                var themePath = client.path;
                                var baseConfigDir = "";
                                if (client.name === "code") {
                                  // For VSCode: ~/.vscode/extensions/... -> ~/.vscode
                                  baseConfigDir = "~/.vscode";
                                } else if (client.name === "codium") {
                                  // For VSCodium: ~/.vscode-oss/extensions/... -> ~/.vscode-oss
                                  baseConfigDir = "~/.vscode-oss";
                                }
                                clients.push({
                                               "name": client.name,
                                               "configPath": baseConfigDir,
                                               "themePath": "" // resolved dynamically via resolvedCodeClientPaths()
                                             });
                              });
    }
    return clients;
  }

  // Resolve VSCode extension paths dynamically (after helpers detection,
  // so resolution is skipped when the Rust binary is unavailable)
  Process {
    id: codeResolverProcess
    command: root.vscodeCmd("~/.vscode/extensions")
    running: false
    property var paths: []
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line)
        codeResolverProcess.paths.push(line);
      }
    }
    onExited: {
      root.resolvedCodePaths = paths;
    }
  }

  Process {
    id: codiumResolverProcess
    command: root.vscodeCmd("~/.vscode-oss/extensions")
    running: false
    property var paths: []
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line)
        codiumResolverProcess.paths.push(line);
      }
    }
    onExited: {
      root.resolvedCodiumPaths = paths;
    }
  }
  // Build user templates TOML content
  function buildUserTemplatesToml() {
    var lines = [];
    lines.push("[config]");
    lines.push("");
    lines.push("[templates]");
    lines.push("");
    lines.push("# User-defined templates");
    lines.push("# Add your custom templates below");
    lines.push("# Example:");
    lines.push("# [templates.myapp]");
    lines.push("# input_path = \"~/.config/nosdshell/templates/myapp.css\"");
    lines.push("# output_path = \"~/.config/myapp/theme.css\"");
    lines.push("# post_hook = \"myapp --reload-theme\"");
    lines.push("");
    lines.push("# Remove this section and add your own templates");
    lines.push("#[templates.placeholder]");
    lines.push("#input_path = \"" + Quickshell.shellDir + "/Assets/Templates/nosdshell.json\"");
    lines.push("#output_path = \"" + Settings.cacheDir + "placeholder.json\"");
    lines.push("");

    return lines.join("\n") + "\n";
  }

  // Write user templates TOML file (moved from Theming)
  function writeUserTemplatesToml() {
    var userConfigPath = Settings.configDir + "user-templates.toml";

    // Check if file already exists
    fileCheckProcess.command = ["test", "-s", userConfigPath];
    fileCheckProcess.running = true;
  }

  function doWriteUserTemplatesToml() {
    var userConfigPath = Settings.configDir + "user-templates.toml";
    var configContent = buildUserTemplatesToml();
    var userConfigPathEsc = userConfigPath.replace(/'/g, "'\\''");
    var configDirEsc = Settings.configDir.replace(/'/g, "'\\''");

    // Combine mkdir and write in a single script to avoid race condition
    var script = `mkdir -p '${configDirEsc}' && cat > '${userConfigPathEsc}' << 'EOF'\n`;
    script += configContent;
    script += "EOF\n";
    fileWriteProcess.command = ["sh", "-c", script];
    fileWriteProcess.running = true;
  }

  // Extract Emacs clients for ProgramCheckerService compatibility
  readonly property var emacsClients: [
    {
      "name": "doom",
      "path": "~/.config/doom"
    },
    {
      "name": "modern",
      "path": "~/.config/emacs"
    },
    {
      "name": "traditional",
      "path": "~/.emacs.d"
    }
  ]

  // Process for checking if user templates file exists and is non-empty
  Process {
    id: fileCheckProcess
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        // File exists and is non-empty, skip creation
        Logger.d("TemplateRegistry", "User templates config already exists, skipping creation");
      } else {
        // File doesn't exist or is empty, create it
        doWriteUserTemplatesToml();
      }
    }
  }

  // Process for writing user templates file with error reporting
  Process {
    id: fileWriteProcess
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        Logger.d("TemplateRegistry", "User templates config written to:", Settings.configDir + "user-templates.toml");
      } else {
        Logger.e("TemplateRegistry", "Failed to write user templates config (exit code:", exitCode + ")");
      }
    }
  }
}
