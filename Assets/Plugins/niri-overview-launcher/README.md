# Niri Overview Launcher

Built-in nosDshell plugin that opens the application launcher and starts searching as soon as you type a character inside Niri's overview mode.

## Behavior

- Tracks `CompositorService.overviewActive` to detect when Niri enters or leaves overview mode.
- Places a transparent, click-through overlay on every screen while the overview is open so pointer clicks still reach Niri's window previews.
- Forwards arrow keys (`Left`, `Right`, `Up`, `Down`) to Niri column and workspace navigation, and `Escape` or `Return` to exit the overview.
- Opens the nosDshell launcher with the typed character (`LauncherState.openWithSearch`) when you press any printable key.
- Closes Niri's overview automatically once you launch an application or dismiss the launcher.

## Requirements

- Niri window manager with `$NIRI_SOCKET` available in the session environment.

## Credits

Adapted from `niri-overview-launcher` in [`noctalia-plugins`](https://github.com/noctalia-dev/noctalia-plugins), inspired by [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).
