# Credits

nosDshell builds on the following projects and assets.

## Design reference and artwork

- [GXDE-OS](https://github.com/GXDE-OS): the community-maintained continuation of the DDE 15 desktop. Layout measurements, interaction rules, and visual tokens are derived from its source code.
- [deepin / UnionTech](https://www.deepin.org/): creators of the original DDE 15 design language. `Assets/Wallpaper/deepin15-desktop.jpg` is the deepin 15 default wallpaper, licensed under CC-BY-3.0 (see the `.license` file next to it).

## Core framework

- [Quickshell](https://github.com/outfoxxed/quickshell): the Qt/QML Wayland shell toolkit that runs nosDshell.
- [Noctalia](https://github.com/noctalia-dev/noctalia-shell): the upstream Wayland shell (MIT) from which nosDshell is forked, providing the service layer, settings pipeline, widget system, and plugin architecture.

## Runtime dependencies

Every external CLI tool is optional. When a tool is not installed, only the feature that uses it is disabled.

### System integration

- [brightnessctl](https://github.com/Hummer12007/brightnessctl): internal display backlight control
- [ddcutil](https://www.ddcutil.com/): external monitor brightness control over DDC/CI
- [wlsunset](https://sr.ht/~kennylevinsen/wlsunset/): night light color temperature filter
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard): Wayland clipboard read and write utilities
- [power-profiles-daemon](https://gitlab.freedesktop.org/upower/power-profiles-daemon): system power profile switching
- [udisks](https://github.com/storaged-project/udisks): removable drive mounting and power-off (`udisksctl`) for the built-in USB drive manager plugin

### Media and audio

- [Cava](https://github.com/karlstav/cava): real-time audio spectrum analysis for media cards and visualizer widgets

### Utilities

- [cliphist](https://github.com/sentriz/cliphist): Wayland clipboard history storage
- [fastfetch](https://github.com/fastfetch-cli/fastfetch): hardware and OS summary on the About page

## Icons

- [Tabler Icons](https://tabler.io/icons): interface glyph set

## Audio assets

- [Universfield on Pixabay](https://pixabay.com/users/universfield-28281460/): notification sound
- [DrNI on Freesound](https://freesound.org/people/DrNI/sounds/34562/): timer alarm sound
- [Lucas McCallister on Freesound](http://www.freesound.org/samplesViewSingle.php?id=67091): volume feedback sound

## Thanks

- The Wayland community.
- The Niri, Hyprland, Sway, Scroll, Labwc, and MangoWC teams whose compositors nosDshell supports.
- Everyone who contributed to Noctalia and GXDE-OS.

## License

nosDshell is licensed under GPL-3.0. See [LICENSE](LICENSE).
Parts derived from upstream Noctalia remain under the MIT License. See [LICENSE-MIT](LICENSE-MIT).

Each dependency listed above is governed by its own license.
