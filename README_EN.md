<div align="center">

<img src="Assets/nosdshell.svg" width="110" alt="nosDshell logo" />

# nosDshell

### A Wayland desktop shell that runs every Noctalia v4 feature behind the deepin 15 interface

[中文](README.md) · [Wiki](https://shinebreaker.github.io/nosDshell/) · [Design spec](DESIGN.md) · [Changelog](CHANGELOG.md)

[![GitHub Release](https://img.shields.io/github/v/release/ShineBreaker/nosDshell?style=for-the-badge&label=release&color=0081ff)](https://github.com/ShineBreaker/nosDshell/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-red?style=for-the-badge)](LICENSE)
[![Wayland](https://img.shields.io/badge/wayland-native-blueviolet?style=for-the-badge)](https://wayland.freedesktop.org)
[![Quickshell](https://img.shields.io/badge/built%20on-quickshell-green?style=for-the-badge)](https://quickshell.outfoxxed.me)
[![Docs](https://img.shields.io/badge/wiki-noctalia%20v4%20mirror-orange?style=for-the-badge)](https://shinebreaker.github.io/nosDshell/)

<img src="Assets/Screenshots/nosdshell-desktop-light.jpg" alt="nosDshell desktop (light theme)" />

</div>

---

## About

[Noctalia](https://github.com/noctalia-dev/noctalia-shell) v4 is a Wayland desktop shell built on Quickshell. nosDshell is a fork that keeps all of its features and redraws every surface the way deepin 15 (DDE 15) drew it: the taskbar, launcher, control center, notifications, OSD, shutdown screen, and lock screen.

- **Every value has a source.** Sizes, opacities, radii, and animation durations come from the [GXDE-OS](https://github.com/GXDE-OS) source (the community-maintained DDE 15). [`DESIGN.md`](DESIGN.md) lists each one with the file and line it came from. Deliberate departures from the original, such as more visible borders and softer shadows, are marked 〔演进〕 (evolved) in the spec.
- **The full Noctalia v4 feature set.** Six compositors (Niri, Hyprland, Sway, Scroll, Labwc, MangoWC), multi-monitor support, wallpaper management, desktop widgets, plugins, and settings migrations. Upstream components and options that no longer apply are removed — brand services such as telemetry, update checks, and the supporters list, plus lock-screen, session-menu, and panel options that have no DDE counterpart; [`DESIGN.md`](DESIGN.md) §6.1 has the full list.
- **Light and dark themes.** Glass surfaces follow the theme. Monochrome and `*-symbolic` icons switch color with it: dark on light surfaces, light on dark ones. The fullscreen launcher, lock screen, and shutdown screen sit on the wallpaper and stay dark in both themes, so white text stays readable.

---

## Screenshots

| Light | Dark |
|:---:|:---:|
| ![light desktop](Assets/Screenshots/nosdshell-desktop-light.jpg) | ![dark desktop](Assets/Screenshots/nosdshell-desktop-dark.jpg) |
| ![light mini launcher](Assets/Screenshots/nosdshell-launcher-mini-light.jpg) | ![dark mini launcher](Assets/Screenshots/nosdshell-launcher-mini-dark.jpg) |
| ![light settings](Assets/Screenshots/nosdshell-settings-light.jpg) | ![dark control center](Assets/Screenshots/nosdshell-control-center-dark.jpg) |

<details>
<summary><b>More surfaces</b></summary>

| | |
|:---:|:---:|
| **Fullscreen launcher** (stays dark on the wallpaper) | **Efficient-mode taskbar** |
| ![fullscreen launcher](Assets/Screenshots/nosdshell-launcher-fullscreen.jpg) | ![efficient taskbar](Assets/Screenshots/nosdshell-efficient.jpg) |
| **Dock popup panel** | **Control center (light)** |
| ![dock panel](Assets/Screenshots/nosdshell-dock-panel.jpg) | ![light control center](Assets/Screenshots/nosdshell-control-center-light.jpg) |
| **Notification** | **OSD** |
| ![notification](Assets/Screenshots/nosdshell-notification.jpg) | ![osd](Assets/Screenshots/nosdshell-osd.jpg) |
| **Shutdown screen** | **Lock screen** |
| ![shutdown screen](Assets/Screenshots/nosdshell-session-menu.jpg) | ![lock screen](Assets/Screenshots/nosdshell-lockscreen.jpg) |

</details>

---

## Surfaces

- **Taskbar.** Two forms you can switch between at any time: efficient mode is a full-width bar along the screen edge, fashion mode is a floating centered dock. Both work on all four edges. Running indicators, window grouping, pinning, and drag reordering follow DDE's rules. Popup panels are arrowed bubbles that point at the taskbar icon that opened them.
- **Launcher.** Fullscreen mode shows an app grid over the blurred wallpaper while the taskbar stays usable. Mini mode opens next to the taskbar, browses two levels of categories (click a category again to return to all apps), and searches apps, commands, and calculations.
- **Control center.** Slides in from the right edge, 408 px wide, with a grid of settings modules, paged quick toggles, and notification history. Clicking a module opens its settings page, which has a 56 px navigation rail on the left.
- **Shutdown screen.** A centered row of 140×140 buttons (power off, reboot, suspend, hibernate, lock, log out, and more; the set and order are configurable). Arrow keys or number keys select a button.
- **OSD.** A square at the bottom center for volume, brightness, and volume above 100%. Repeated changes update the value in place without replaying the animation.
- **Notifications and toasts.** 300 px wide bubbles, one at a time by default, with the rest queued. `*-symbolic` app icons are tinted to match the bubble.
- **Lock screen.** A band along the bottom with the clock, date, media controls, and power button, and a centered avatar, password field, error hint, and Caps Lock hint.

---

## Requirements

- A Wayland compositor: Niri, Hyprland, Sway, Scroll, Labwc, or MangoWC
- [Quickshell](https://quickshell.outfoxxed.me) 0.3.x
- Icon theme: Papirus or deepin recommended
- Optional command-line tools (a missing tool only disables its feature): brightnessctl, ddcutil, wlsunset, wl-clipboard, cliphist, cava, power-profiles-daemon. See [`CREDITS.md`](CREDITS.md) for what each one does.

| Distro | How |
|---|---|
| Guix | `nosdshell.scm` at the repo root |
| Nix / NixOS | `flake.nix`, which includes home-manager and NixOS modules |
| Other | Clone this repo and run `qs -p <path-to-repo>` |

---

## Documentation

- **[Wiki](https://shinebreaker.github.io/nosDshell/)**: a complete archive of the upstream Noctalia v4 docs (installation, configuration, theming, plugin development, IPC reference).
- [`DESIGN.md`](DESIGN.md): the DDE 15 visual and interaction spec. The interface follows it.
- [`AGENTS.md`](AGENTS.md): engineering constraints and working method. It links to [`CODING_STANDARDS.md`](CODING_STANDARDS.md), [`DEBUGGING.md`](DEBUGGING.md), and [`TOOLS.md`](TOOLS.md) by task type.
- [`CHANGELOG.md`](CHANGELOG.md) and [`docs/RELEASE.md`](docs/RELEASE.md): change history and the release process.

---

## Development

Common commands are wrapped in the `justfile`; run `just` to list them.

| Goal | Command |
|---|---|
| Lint | `Scripts/dev/lint.sh [--changed]` |
| Run isolated and take screenshots | `Scripts/test/verify.sh <name> [--settings seed.json] [--scenes a,b]` |
| Verify on real niri | `Scripts/test/niri/` (nested niri; opens a window on your desktop) |
| Performance baseline | `Scripts/test/bench.sh` |
| Format QML | `Scripts/dev/qmlfmt.sh <path>` |

---

## License

GPL-3.0, see [LICENSE](LICENSE).
Parts derived from upstream Noctalia remain under the MIT License, see [LICENSE-MIT](LICENSE-MIT).

## Credits

- [Noctalia](https://github.com/noctalia-dev/noctalia-shell): the functional base of this project (v4 branch). Its archived v4 docs are hosted in our Wiki.
- [GXDE-OS](https://github.com/GXDE-OS): the community-maintained DDE 15 and the source of the design values. The default wallpaper `deepin15-desktop.jpg` comes from its wallpaper repo (CC-BY-3.0 © UnionTech).
- deepin / DDE 15: the original authors of this visual language.

See [`CREDITS.md`](CREDITS.md) for the full list of credits and dependencies.
