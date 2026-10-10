<div align="center">

<img src="Assets/nosdshell.svg" width="110" alt="nosDshell logo" />

# nosDshell

### deepin 15 looks · Noctalia muscle · Wayland native

**The classic DDE desktop — fully reborn on modern Wayland. Not a tribute; a pixel-level recreation.**

[中文](README.md) · [Wiki](https://shinebreaker.github.io/nosDshell/) · [Design Spec](DESIGN.md) · [Changelog](CHANGELOG.md)

[![GitHub Release](https://img.shields.io/github/v/release/ShineBreaker/nosDshell?style=for-the-badge&label=release&color=0081ff)](https://github.com/ShineBreaker/nosDshell/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-red?style=for-the-badge)](LICENSE)
[![Wayland](https://img.shields.io/badge/wayland-native-blueviolet?style=for-the-badge)](https://wayland.freedesktop.org)
[![Quickshell](https://img.shields.io/badge/built%20on-quickshell-green?style=for-the-badge)](https://quickshell.outfoxxed.me)
[![Docs](https://img.shields.io/badge/wiki-noctalia%20v4%20mirror-orange?style=for-the-badge)](https://shinebreaker.github.io/nosDshell/)

<img src="Assets/Screenshots/nosdshell-desktop-light.jpg" alt="nosDshell desktop (light theme)" />

</div>

---

## Why nosDshell?

Noctalia is one of the most complete Quickshell desktop shells around; deepin 15 (DDE 15) is a high-water mark of Linux desktop design. nosDshell does one thing: **it presents all of Noctalia v4's capabilities in the DDE 15 visual and interaction language.**

- **Pixel-level recreation, not a vibes-based homage** — every size, opacity, radius, and animation duration is lifted from [GXDE-OS](https://github.com/GXDE-OS) (the community-maintained DDE 15) source and written down in [`DESIGN.md`](DESIGN.md).
- **The full Noctalia v4 engine** — the business layer is inherited as-is: six compositors (Niri / Hyprland / Sway / Scroll / Labwc / MangoWC), multi-monitor, the wallpaper pipeline, desktop widgets, the plugin system, and settings migrations. The only upstream features removed are noctalia-identity services (telemetry, update checks, sponsors).
- **Light & dark themes with adaptive icons** — glass surfaces follow the theme, and monochrome/`*-symbolic` icons automatically re-ink: dark ink on light glass, light ink on dark. Wallpaper surfaces (fullscreen launcher, lock screen, session menu) stay deliberately dark in both modes, so white artwork never washes out.
- **Two taskbar forms** — efficient (full-width) and fashion (floating dock), switchable on the fly, docked on any edge; DDE-style arrowed popups anchor to the triggering taskbar icon.
- **Two launchers** — the DDE fullscreen grid (blurred wallpaper, taskbar stays interactive) plus the mini launcher (two-level categories, app / command / calculator search).
- **Right-edge Control Center** — 408 px frosted frame, a 15-module grid, paged quick toggles, notification history; Settings lives inside it behind a 56 px nav rail.

---

## Theme-adaptive · Real screenshots

| Light | Dark |
|:---:|:---:|
| ![light desktop](Assets/Screenshots/nosdshell-desktop-light.jpg) | ![dark desktop](Assets/Screenshots/nosdshell-desktop-dark.jpg) |
| ![light mini launcher](Assets/Screenshots/nosdshell-launcher-mini-light.jpg) | ![dark mini launcher](Assets/Screenshots/nosdshell-launcher-mini-dark.jpg) |
| ![light settings](Assets/Screenshots/nosdshell-settings-light.jpg) | ![dark control center](Assets/Screenshots/nosdshell-control-center-dark.jpg) |

<details>
<summary><b>More surfaces</b></summary>

| | |
|:---:|:---:|
| **Fullscreen launcher** (wallpaper surface stays dark) | **Efficient-mode taskbar** |
| ![fullscreen launcher](Assets/Screenshots/nosdshell-launcher-fullscreen.jpg) | ![efficient taskbar](Assets/Screenshots/nosdshell-efficient.jpg) |
| **Dock info panel** | **Control center (light)** |
| ![dock panel](Assets/Screenshots/nosdshell-dock-panel.jpg) | ![light control center](Assets/Screenshots/nosdshell-control-center-light.jpg) |
| **Notification** | **OSD** |
| ![notification](Assets/Screenshots/nosdshell-notification.jpg) | ![osd](Assets/Screenshots/nosdshell-osd.jpg) |
| **Session menu** | **Lock screen** |
| ![session menu](Assets/Screenshots/nosdshell-session-menu.jpg) | ![lock screen](Assets/Screenshots/nosdshell-lockscreen.jpg) |

</details>

---

## What's inside

- **Taskbar**: efficient (full-width) / fashion (floating dock) forms, four dock edges; running-app indicators, grouping, pinning, and drag ordering follow DDE semantics.
- **Launcher**: fullscreen mode keeps the taskbar interactive; mini mode has two-level categories (re-click a category to return to "All"), search, command, and calculator modes.
- **Control Center**: 15-module grid + paged quick toggles + notification history; clicking a module jumps straight to its settings page.
- **Session menu**: a centered row of 140×140 buttons (power off / reboot / suspend / hibernate / lock / log out) with number-key selection.
- **OSD**: bottom-center bubbles for volume / brightness / overdrive; repeated triggers refresh values in place instead of replaying the entry animation.
- **Notifications & Toasts**: 300 px bubbles, queued one at a time; `*-symbolic` app icons are tinted to the surface ink.
- **Lock screen**: bottom info band (clock, date, media & power controls) + centered auth area (avatar, password field, error bubble, Caps Lock hint).

---

## Requirements

- A Wayland compositor: Niri / Hyprland / Sway / Scroll / Labwc / MangoWC
- [Quickshell](https://quickshell.outfoxxed.me) (upstream 0.3.x; audio spectrum comes from a cava subprocess)
- Icon theme: Papirus or deepin recommended

| Distro | How |
|---|---|
| Guix | `nosdshell.scm` at the repo root |
| Nix / NixOS | `flake.nix` (includes home-manager / NixOS modules) |
| Other | Put this repo in your Quickshell config dir and run `qs -p <repo>` |

---

## Documentation

- **[Wiki](https://shinebreaker.github.io/nosDshell/)** — includes a complete archived mirror of the upstream Noctalia v4 docs (install, configure, theming, plugin development, IPC reference)
- [`DESIGN.md`](DESIGN.md) — the DDE 15 visual & interaction spec (single source of truth)
- [`AGENTS.md`](AGENTS.md) / [`CODING_STANDARDS.md`](CODING_STANDARDS.md) / [`DEBUGGING.md`](DEBUGGING.md) — engineering constraints
- [`CHANGELOG.md`](CHANGELOG.md) · [`docs/RELEASE.md`](docs/RELEASE.md) — changes & release process

---

## Development

| Goal | Command |
|---|---|
| Lint | `Scripts/dev/lint.sh [--changed]` |
| Run isolated & screenshot | `Scripts/test/verify.sh <name> [--settings seed.json] [--scenes a,b]` |
| Real niri-path verification | `Scripts/test/niri/` (nested niri — opens a window on your desktop) |
| Performance baseline | `Scripts/test/bench.sh` |
| Format QML | `Scripts/dev/qmlfmt.sh <path>` |

---

## License

GPL-3.0 License — see [LICENSE](LICENSE).
Parts derived from upstream Noctalia remain under the MIT License — see [LICENSE-MIT](LICENSE-MIT).

## Credits

- [Noctalia](https://github.com/noctalia-dev/noctalia-shell) — the functional foundation of this project (v4 branch); its archived v4 documentation is mirrored in our Wiki.
- [GXDE-OS](https://github.com/GXDE-OS) — the community-maintained DDE 15, source of every design value; the default `deepin15-desktop.jpg` wallpaper comes from its wallpaper repo (CC-BY-3.0 © UnionTech).
- deepin / DDE 15 — the original authors of this visual language.
