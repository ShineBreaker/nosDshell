<div align="center">

![header](./docs/img/header.png)

# nosd-gtk-theme

### GTK 2/3/4 themes in the DDE 15 visual language, sharing one shape-token source with nosDshell

[简体中文](README.zh_CN.md) · [Changelog](CHANGELOG.md) · [Design spec](https://github.com/nosDshell/nosd/blob/main/packages/nosdshell/DESIGN.md)

[![License](https://img.shields.io/badge/license-GPL--3.0-red?style=for-the-badge)](LICENSE)
[![GTK](https://img.shields.io/badge/GTK-2%20%7C%203%20%7C%204-blue?style=for-the-badge)](https://www.gtk.org)
[![Kvantum](https://img.shields.io/badge/Qt-Kvantum-purple?style=for-the-badge)](https://github.com/tsujan/Kvantum)

</div>

---

## Overview

**nosd-gtk-theme** is the appearance package for the [nosDshell](https://github.com/nosDshell/nosd) desktop. It brings the deepin 15 (DDE 15) visual language to GTK: a set of GTK 2/3/4 themes (`deepin` light, `deepin-dark` dark). The Kvantum Qt theme is a sibling component, [`nosd-kvantum-theme`](../nosd-kvantum-theme).

The theme is derived from [GXDE-OS/deepin-gtk-theme](https://github.com/GXDE-OS/deepin-gtk-theme). On top of that base it does three things: converts every hard-coded colour into GTK's `@define-color`, calibrates radii and hairlines against nosDshell's [`DESIGN.md`](https://github.com/nosDshell/nosd/blob/main/packages/nosdshell/DESIGN.md), and adds deb/rpm/Arch packaging.

The package carries no colour-extraction logic of its own. Light/dark switching and wallpaper-derived palettes belong to nosDshell, which renders the current palette into an override layer and into template output; the theme's job is to put those colours in the right places.

---

## What's inside

| Path | Contents | Consumed by |
| --- | --- | --- |
| `deepin/` | GTK 2/3/4 light theme, plus Cinnamon, GNOME Shell, Metacity, Unity and Xfwm4 skins | GTK apps, Cinnamon, GNOME Shell |
| `deepin-dark/` | Same, dark variant | Same |

---

## Installation

### Distribution packages

Debian/Ubuntu:

```bash
sudo apt install ./nosd-gtk-theme_0.2.0-2_all.deb
```

Fedora/RHEL:

```bash
sudo rpm -i nosd-gtk-theme-0.2.0-1.noarch.rpm
```

Arch:

```bash
makepkg -si   # run inside arch/
```

All three packages provide `deepin-gtk-theme` and `nosd-app-themes`, so they replace the original packages cleanly. Their file layout has been verified to match: `/usr/share/themes/{deepin,deepin-dark}`.

### From source

```bash
git clone https://github.com/nosDshell/nosd
cd nosd/packages/nosd-gtk-theme
sudo make install        # installs to /usr
```

To install into your home directory instead (no root):

```bash
make install-user        # installs to ~/.local
```

**`install-user` is not a convenience shortcut for `install`; it is the only way accent propagation works on Cinnamon and GNOME Shell.** The override file has to be written inside the user theme directory, where the generator has permission to write. With a system-wide install those two desktops fall back to the static accent; every other GTK app is unaffected.

### Enabling the theme

GTK apps read `gtk-theme-name`. Add it to both `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`:

```ini
[Settings]
gtk-theme-name=deepin
```

For dark, use `deepin-dark`, or keep `gtk-application-prefer-dark-theme=1` and let apps pick the variant themselves.

Qt apps use the sibling [`nosd-kvantum-theme`](../nosd-kvantum-theme) component: install it, set `style=kvantum` in `~/.config/qt5ct/qt5ct.conf` and `~/.config/qt6ct/qt6ct.conf`, then `theme=nosd` in `~/.config/Kvantum/kvantum.kvconfig`.

### Dependencies

| Component | Required | Notes |
| --- | --- | --- |
| GTK 3 / GTK 4 | Yes | The bulk of the theme |
| `gtk-engine-murrine` | Optional | Drawing engine for the GTK 2 theme |
| `kvantum` | Optional | Via the sibling nosd-kvantum-theme component |

---

## How accent colours propagate

Colours reach the theme through two paths, and neither requires editing files in this repository.

**GTK override layer.** nosDshell renders `~/.config/gtk-3.0/nosd.css` and `~/.config/gtk-4.0/nosd.css`, redefining the semantic colours with `@define-color`. GTK's cascade rule is that a later `@define-color` wins, so the theme's own defaults are replaced wholesale.

The contract the theme upholds: every colour goes through `@define-color`, and literal values appear only in the defaults block at the top of each file. As long as the override layer redefines those same variable names, every widget colour in both variants follows — no per-selector edits needed.

**Kvantum templates.** Handled by [`nosd-kvantum-theme`](../nosd-kvantum-theme): nosDshell substitutes the palette into the placeholders in `nosd.svg.tpl` and `nosd.kvconfig.tpl`, writing the result to `~/.config/Kvantum/nosd/`.

**Cinnamon and GNOME Shell.** Their CSS engine (St) does not understand `@define-color` — a variable there causes the whole declaration to be dropped. So their skin files end with `@import url("nosd-accent.css");`, pulling in an override file that nosDshell writes with the current accent. Without nosDshell that file contains only comments and the theme keeps its static accent.

---

## Shape tokens and validation

The authoritative source for radii, hairlines and widget geometry is nosDshell's `DESIGN.md` §1.4 and §1.2. [`tokens.toml`](tokens.toml) restates those values in machine-readable form, and [`scripts/check-tokens.py`](scripts/check-tokens.py) checks for drift between the three implementations:

```bash
make check
# equivalent to python3 scripts/check-tokens.py .
```

What it verifies:

- that `border-radius` in the GTK CSS stays within the token set `{4, 5, 6, 8, 10}`, covering longhand properties and the derived `-gtk-outline-radius` as well;
- that no colour literal appears anywhere in the GTK CSS outside `@define-color`;
- that `kvconfig` supplies the full `[GeneralColors]` role set;
- that the Cinnamon / GNOME Shell skins contain no `@` colour references (St cannot parse them).

The current baseline is zero findings. When changing a token, the order matters: edit `DESIGN.md` first, then `tokens.toml`, then align the implementations — doing it the other way around makes the checker meaningless.

---

## Known limitations

- **GTK 2 is statically coloured.** `gtkrc` has no colour variables, so neither dark mode nor accent propagation reaches it. The GTK 2 theme is kept for compatibility only.
- **Qt 5 depends on distribution packaging.** If the distribution does not ship Kvantum's Qt5 plugin, Qt5 apps cannot use this theme.
- **System-wide Cinnamon / GNOME Shell installs are static.** Use `make install-user` when you want accent propagation there.
- **CSD window corners need a compositor.** Without one, GTK degrades to square, solid-coloured frames. That is GTK behaviour, not a theme defect.

---

## Development

```bash
make install-user        # install to ~/.local for quick iteration
make check               # token consistency check
./build-deb -d           # build the deb (-c cleans up)
```

Acceptance screenshots live in `screenshots/`; design decisions and working notes live in `docs/`:

| Document | Contents |
| --- | --- |
| [`docs/kvantum-convergence-map.md`](docs/kvantum-convergence-map.md) | Item-by-item mapping from Kvantum to deepin GTK |
| [`docs/shell-accent-scheme.md`](docs/shell-accent-scheme.md) | Cinnamon / GNOME Shell accent scheme and measurements |
| [`docs/shell-accent-decision.md`](docs/shell-accent-decision.md) | Trade-offs behind that scheme |
| [`docs/radius-notes.md`](docs/radius-notes.md) | Upstream research behind the radius tokens |
| [`docs/packaging-release-checklist.md`](docs/packaging-release-checklist.md) | Packaging and release checklist |

---

## License

Distributed under the [GPL-3.0-or-later](LICENSE).

## Credits

- **[GXDE-OS](https://github.com/GXDE-OS)** — the base this theme is built on, and the community-maintained DDE 15.
- **[deepin / DDE 15](https://www.deepin.org)** — the original authors of this visual language.
- **[Kvantum](https://github.com/tsujan/Kvantum)** and **KvAdapta** — the Qt widget theme engine and the form it was drawn from.
