<div align="center">

<img src="Assets/nosdshell.svg" width="110" alt="nosDshell logo" />

# nosDshell

### The classic deepin 15 glass desktop for Wayland, powered by the full Noctalia v4 engine

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

Wayland compositors like Niri, Hyprland, and Sway handle windows fast, but turning them into a complete desktop usually means wiring together separate tools for your bar, launcher, notifications, lock screen, wallpaper, Polkit prompts, and dark-mode switching.

**nosDshell** replaces that patchwork with one cohesive shell. Built on [Quickshell](https://quickshell.outfoxxed.me) and forked from [Noctalia](https://github.com/noctalia-dev/noctalia-shell) v4, it keeps the entire Noctalia v4 feature set and redraws every surface in the **deepin 15 (DDE 15)** visual language: dark and light frosted glass, crisp hairline borders, a signature `#2CA7F8` accent color, and consistent behavior across every panel.

---

## Why nosDshell

- **Pixel-accurate DDE 15 design.** Sizes, opacities, corner radii, and animation curves come directly from the [GXDE-OS](https://github.com/GXDE-OS) source code (the community-maintained DDE 15) and are cited by file and line number in [`DESIGN.md`](DESIGN.md). Deliberate modern refinements, such as hairline borders, softer drop shadows, and theme-aware notification tiles, are marked 〔演进〕 (evolved) in the spec.
- **One shell instead of a dozen daemons.** Taskbar, optional top status bar, fullscreen and mini app launchers, slide-out control center, grouped notification center, volume and brightness OSD, wallpaper manager, lock screen, fullscreen shutdown screen, and a native Polkit authentication agent all run in one process.
- **Two taskbar modes plus an optional status bar.** Switch at any time between Fashion mode, a centered floating dock, and Efficient mode, a full-width edge bar with customizable left, center, and right widget zones. Both work on all four screen edges. In Fashion mode, you can also enable an independent macOS-style top status bar.
- **Desktop-wide light and dark themes.** Frosted glass surfaces and `*-symbolic` monochrome icons adapt to light and dark modes, or pull a palette from your current wallpaper to theme GTK, terminals, and editors. A built-in `darkman` and `xdg-desktop-portal` daemon keeps GTK4, Qt, Electron apps, and `~/.local/share/{dark,light}-mode.d/` hook scripts in sync.
- **Six Wayland compositors and built-in plugins.** Supports Niri, Hyprland, Sway, Scroll, Labwc, and MangoWC with multi-monitor layouts, per-display overrides, desktop widgets, and automatic settings migrations. Ships with a taskbar USB drive manager (mount, check capacity, and safely power off drives) and a Niri overview listener that opens the launcher as soon as you start typing in overview mode.
- **No telemetry or brand clutter.** Upstream telemetry, update checks, and sponsor banners are removed, along with lock-screen, session-menu, and panel layout options that have no DDE counterpart. See [`DESIGN.md`](DESIGN.md) §6.1 for the complete removal registry.

---

## Screenshots

| Light theme | Dark theme |
|:---:|:---:|
| ![light desktop](Assets/Screenshots/nosdshell-desktop-light.jpg) | ![dark desktop](Assets/Screenshots/nosdshell-desktop-dark.jpg) |
| ![light mini launcher](Assets/Screenshots/nosdshell-launcher-mini-light.jpg) | ![dark mini launcher](Assets/Screenshots/nosdshell-launcher-mini-dark.jpg) |
| ![light settings](Assets/Screenshots/nosdshell-settings-light.jpg) | ![dark control center](Assets/Screenshots/nosdshell-control-center-dark.jpg) |

<details>
<summary><b>More desktop surfaces</b></summary>

| | |
|:---:|:---:|
| **Fullscreen launcher** (stays dark over the wallpaper) | **Efficient-mode taskbar** |
| ![fullscreen launcher](Assets/Screenshots/nosdshell-launcher-fullscreen.jpg) | ![efficient taskbar](Assets/Screenshots/nosdshell-efficient.jpg) |
| **Taskbar popup panel** | **Control center (light)** |
| ![dock panel](Assets/Screenshots/nosdshell-dock-panel.jpg) | ![light control center](Assets/Screenshots/nosdshell-control-center-light.jpg) |
| **Notification bubble** | **OSD tile** |
| ![notification](Assets/Screenshots/nosdshell-notification.jpg) | ![osd](Assets/Screenshots/nosdshell-osd.jpg) |
| **Shutdown screen** | **Lock screen** |
| ![shutdown screen](Assets/Screenshots/nosdshell-session-menu.jpg) | ![lock screen](Assets/Screenshots/nosdshell-lockscreen.jpg) |

</details>

---

## Desktop tour

- **Taskbar and popup panels.** Switch between the centered Fashion dock and the full-width Efficient bar on any screen edge. Running indicators, window grouping, pinned apps, and drag reordering follow DDE 15 rules. Clicking volume, Wi-Fi, Bluetooth, battery, clock, or USB icons opens an arrowed frosted-glass bubble pointing at the icon that triggered it.
- **Application launcher.** Fullscreen mode displays an app grid over a pre-blurred wallpaper with an 11-category sidebar while keeping the taskbar interactive. Mini mode opens beside the taskbar with two-level category browsing and quick folder links. Both modes search apps, open windows, settings, clipboard history, emoji, math expressions, and shell commands.
- **Control center and settings.** Slides in from the right edge at 408 px wide. The default view shows notifications grouped by date and application above a collapsible paged strip for weather, media controls, system gauges, audio and brightness sliders, and up to 10 labeled quick switches. Clicking the gear icon or any module tile opens the unified settings view with its 56 px left icon navigation rail.
- **Lock screen and shutdown screen.** The lock screen pairs a pre-blurred wallpaper with a bottom info band (large clock, date, media controls, power button) and a centered avatar, password or fingerprint prompt, error tooltip, and Caps Lock indicator. The shutdown screen centers a row of 140x140 action buttons (power off, reboot, suspend, hibernate, lock, log out, reboot to UEFI) navigable with arrow keys or number shortcuts.
- **OSD, notifications, and Polkit authentication.** Volume, brightness, and lock-key changes appear in a bottom-center 140x140 square that updates values in place without replaying its entrance animation. Notifications queue in 300 px wide bubbles. Privileged actions open a native DDE Polkit password dialog that resolves transient systemd units to the actual command requesting elevation.

---

## Getting started

### Requirements

- **Wayland compositor**: Niri, Hyprland, Sway, Scroll, Labwc, or MangoWC
- **[Quickshell](https://quickshell.outfoxxed.me)**: 0.3.x
- **Icon theme**: Papirus or deepin recommended
- **Optional CLI tools** (a missing tool only disables its feature): `brightnessctl`, `ddcutil`, `wlsunset`, `wl-clipboard`, `cliphist`, `cava`, `power-profiles-daemon`, `udisksctl`. See [`CREDITS.md`](CREDITS.md) for what each tool provides.

### Installation

| Distribution | Method |
|---|---|
| Guix | `nosdshell.scm` at the repository root |
| Nix / NixOS | `flake.nix` (includes package, Home Manager module, and NixOS module) |
| Other | Clone this repository and run `qs -p <path-to-repo>` |

Run `nosdshell --version` to print the shell and Quickshell versions. Shell completions for `bash`, `zsh`, and `fish` install to standard paths and load automatically in new terminal sessions.

---

## Documentation

- **[Wiki](https://shinebreaker.github.io/nosDshell/)**: complete archive of the upstream Noctalia v4 documentation (installation, configuration, theming, plugin development, and IPC reference).
- **[`DESIGN.md`](DESIGN.md)**: the DDE 15 visual and interaction specification. Every surface follows it.
- **[`AGENTS.md`](AGENTS.md)**: architecture and maintenance rules, linking to [`CODING_STANDARDS.md`](CODING_STANDARDS.md), [`DEBUGGING.md`](DEBUGGING.md), and [`TOOLS.md`](TOOLS.md) by task type.
- **[`CHANGELOG.md`](CHANGELOG.md)** and **[`docs/RELEASE.md`](docs/RELEASE.md)**: release notes and release workflow.

---

## Development

Common tasks are defined in the `justfile`. Run `just` to list all recipes:

| Task | Command |
|---|---|
| Static checks (settings keys, translations, motion tokens, qmllint) | `Scripts/dev/lint.sh [--changed]` |
| Run in an isolated headless session and capture screenshots | `Scripts/test/verify.sh <name> [--settings seed.json] [--scenes a,b]` |
| Verify in a nested Niri window | `Scripts/test/niri/` |
| Startup and panel latency benchmark | `Scripts/test/bench.sh` |
| Format QML files | `Scripts/dev/qmlfmt.sh <path>` |

---

## License

Licensed under GPL-3.0. See [LICENSE](LICENSE).
Code derived from upstream Noctalia remains under the MIT License. See [LICENSE-MIT](LICENSE-MIT).

## Credits

- **[Noctalia](https://github.com/noctalia-dev/noctalia-shell)**: the functional foundation of this project (v4 branch). Its archived v4 documentation is hosted on our Wiki.
- **[GXDE-OS](https://github.com/GXDE-OS)**: the community-maintained DDE 15 and the source of our design measurements. The default wallpaper `deepin15-desktop.jpg` comes from its wallpaper repository (CC-BY-3.0 © UnionTech).
- **deepin / DDE 15**: the original creators of this visual language.

See [`CREDITS.md`](CREDITS.md) for the full list of credits and runtime dependencies.
