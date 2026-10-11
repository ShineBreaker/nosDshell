# Credits

nosDshell builds on the following projects and assets.

## Design reference and artwork

- [GXDE-OS](https://github.com/GXDE-OS): the community continuation of the DDE 15 desktop. Our layout, interaction, and visual values are reimplemented from its source code.
- [deepin / UnionTech](https://www.deepin.org/): the original DDE design language. `Assets/Wallpaper/deepin15-desktop.jpg` is the deepin 15 default wallpaper, licensed CC-BY-3.0 (see the `.license` file next to it).

## Core framework

- [Quickshell](https://github.com/outfoxxed/quickshell): the Qt/QML Wayland shell framework nosDshell runs on.
- [Noctalia](https://github.com/noctalia-dev/noctalia-shell): the upstream shell (MIT) this project is forked from. Its features and service architecture are kept here.

## Runtime dependencies

Each tool is optional. If it is missing, only the feature it backs stops working.

### System integration

- [brightnessctl](https://github.com/Hummer12007/brightnessctl): screen brightness control
- [wlsunset](https://sr.ht/~kennylevinsen/wlsunset/): night light
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard): Wayland clipboard access
- [ddcutil](https://www.ddcutil.com/): external monitor brightness control
- [power-profiles-daemon](https://gitlab.freedesktop.org/upower/power-profiles-daemon): power profile switching

### Media and audio

- [Cava](https://github.com/karlstav/cava): audio spectrum data for the visualizer widgets

### Utilities

- [cliphist](https://github.com/sentriz/cliphist): clipboard history

## Icons

- [Tabler Icons](https://tabler.io/icons): the interface glyph set

## Audio assets

- [Universfield on Pixabay](https://pixabay.com/users/universfield-28281460/): notification sound
- [DrNI on Freesound](https://freesound.org/people/DrNI/sounds/34562/): timer alarm sound
- [Lucas McCallister on Freesound](http://www.freesound.org/samplesViewSingle.php?id=67091): volume change sound

## Thanks

- The Wayland community.
- The Niri, Hyprland, Sway, Scroll, Labwc, and MangoWC teams, whose compositors nosDshell supports.
- Everyone who contributed to Noctalia.

## License

nosDshell is licensed under GPL-3.0, see [LICENSE](LICENSE).
Parts derived from upstream Noctalia remain under the MIT License, see [LICENSE-MIT](LICENSE-MIT).

Each dependency listed above is covered by its own license; see the individual projects for details.
