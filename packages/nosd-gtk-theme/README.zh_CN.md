<div align="center">

![header](./docs/img/header.png)

# nosd-gtk-theme
### DDE 15 视觉的 GTK 2/3/4 主题，与 nosDshell 共用同一套形状令牌

[English](README.md) · [更新日志](CHANGELOG.md) · [设计规范](https://github.com/nosDshell/nosd/blob/main/packages/nosdshell/DESIGN.md)


[![License](https://img.shields.io/badge/license-GPL--3.0-red?style=for-the-badge)](LICENSE)

[![GTK](https://img.shields.io/badge/GTK-2%20%7C%203%20%7C%204-blue?style=for-the-badge)](https://www.gtk.org)

[![Kvantum](https://img.shields.io/badge/Qt-Kvantum-purple?style=for-the-badge)](https://github.com/tsujan/Kvantum)

</div>

---

## 简介

 *nosd-gtk-theme* 是 [nosDshell](https://github.com/nosDshell/nosd) 生态的外观包。它把 deepin 15（DDE 15）的视觉语言带到 GTK：一套 GTK 2/3/4 主题（`deepin` 浅色、`deepin-dark` 深色）。Kvantum Qt 控件主题是兄弟组件 [`nosd-kvantum-theme`](../nosd-kvantum-theme)。

主题源自 [GXDE-OS/deepin-gtk-theme](https://github.com/GXDE-OS/deepin-gtk-theme)。在此基础上做了三件事：把全部颜色字面量收敛为 GTK 的 `@define-color`、按 nosDshell 的 [`DESIGN.md`](https://github.com/nosDshell/nosd/blob/main/packages/nosdshell/DESIGN.md) 校准圆角与描边、补齐 deb/rpm/Arch 三套打包。

包本身不含取色逻辑。明暗切换与壁纸取色由 nosDshell 完成：它把当前调色板渲染进覆盖层与模板产物，主题负责把颜色用在正确的位置。

---

## 包含内容

| 路径            | 内容                                                                      | 消费方                             |
| ---             | ---                                                                       | ---                                |
| `deepin/`       | GTK 2/3/4 浅色主题，附 Cinnamon、GNOME Shell、Metacity、Unity、Xfwm4 皮肤 | GTK 应用、Cinnamon、GNOME Shell    |
| `deepin-dark/`  | 同上，深色变体                                                            | 同上                               |

---

## 安装
### 发行版软件包

Debian/Ubuntu：

```bash
sudo apt install ./nosd-gtk-theme_0.2.0-2_all.deb
```

Fedora/RHEL：

```bash
sudo rpm -i nosd-gtk-theme-0.2.0-1.noarch.rpm
```

Arch：

```bash
makepkg -si   # 在 arch/ 目录中执行
```

三个包都提供 `deepin-gtk-theme` 与 `nosd-app-themes`，安装后可直接替换原包。已验证落位一致：`/usr/share/themes/{deepin,deepin-dark}`。

### 从源码安装

```bash
git clone https://github.com/nosDshell/nosd
cd nosd/packages/nosd-gtk-theme
sudo make install        # 装到 /usr
```

装到用户目录（无需 root）：

```bash
make install-user        # 装到 ~/.local
```

 *`install-user` 不是 `install` 的省事替代，而是 Cinnamon 与 GNOME Shell 取色生效的唯一途径。* 覆盖文件必须写在用户主题目录内，生成器才有权限；系统级安装时这两个桌面环境退化为静态 accent，其余 GTK 应用不受影响。

### 启用

GTK 应用读取 `gtk-theme-name`。在 `~/.config/gtk-3.0/settings.ini` 与 `~/.config/gtk-4.0/settings.ini` 中写入：

```ini
[Settings]
gtk-theme-name=deepin
```

深色把值改成 `deepin-dark`，或保留 `gtk-application-prefer-dark-theme=1` 让应用自行选择变体。

Qt 应用用兄弟组件 [`nosd-kvantum-theme`](../nosd-kvantum-theme)：安装后在 `~/.config/qt5ct/qt5ct.conf` 与 `~/.config/qt6ct/qt6ct.conf` 设 `style=kvantum`，并在 `~/.config/Kvantum/kvantum.kvconfig` 写 `theme=nosd`。

```ini
[General]
theme=nosd
```

Qt 5 需要发行版额外提供 Kvantum 的 Qt5 插件（见兄弟组件说明）。

### 依赖

| 组件                 | 必需性 | 说明                    |
| ---                  | ---    | ---                     |
| GTK 3 / GTK 4        | 必需   | 主题主体                |
| `gtk-engine-murrine` | 可选   | GTK 2 主题的绘制引擎    |
| `kvantum`            | 可选   | 启用 Kvantum 主题时必需 |

---

## 取色跟随

主题的配色分两条路径注入，都不需要改本仓库的文件。

 *GTK 覆盖层。* nosDshell 渲染 `~/.config/gtk-3.0/nosd.css` 与 `~/.config/gtk-4.0/nosd.css`，其中以 `@define-color` 重定义语义色。GTK 的层叠规则是后定义的 `@define-color` 覆盖先前的，因此主题自带的默认值会被整体替换。

主题侧承诺的契约是：所有颜色都通过 `@define-color` 引用，字面值只出现在文件头的默认值块中。覆盖层只要重定义这些同名变量，深浅两套主题的全部控件颜色都会跟随，无需逐条改选择器。

 *Kvantum 模板。* nosDshell 把调色板填入 `nosd.svg.tpl` 与 `nosd.kvconfig.tpl` 的占位符，输出到 `~/.config/Kvantum/nosd/`。占位符覆盖 13 类 M3 角色，包括 `primary`、`primary_container`、`surface`、`on_surface`、`error` 等；`kvconfig` 的 `[GeneralColors]` 全套角色同样走占位符，因此菜单栏、工具栏与页签栏的底色也会随主题切换。

 *Cinnamon 与 GNOME Shell。* 这两个桌面环境的 CSS 引擎（St）不认识 `@define-color`，用变量会让整条声明被丢弃。因此它们的皮肤文件末尾以 `@import url("nosd-accent.css");` 引入一个覆盖文件，由 nosDshell 写入当前 accent；没有 nosDshell 时该文件只有注释，主题保持静态配色。

---

## 形状令牌与校验

半径、描边、控件几何的权威来源是 nosDshell 的 `DESIGN.md` §1.4 与 §1.2。本仓库的 [`tokens.toml`](tokens.toml) 把权威值抄成机器可读形式，[`scripts/check-tokens.py`](scripts/check-tokens.py) 检查三处实现之间的漂移：

```bash
make check
# 等价于 python3 scripts/check-tokens.py .
```

检查项：

- GTK CSS 中的 `border-radius` 是否落在令牌集合 `{4, 5, 6, 8, 10}`，长写属性与 `-gtk-outline-radius` 派生值一并覆盖；
- GTK CSS 是否出现 `@define-color` 之外的颜色字面量；
- Kvantum 的 `kvconfig` 是否给出 `[GeneralColors]` 全套角色；
- Cinnamon / GNOME Shell 皮肤中是否混入了 `@` 颜色引用（St 不支持）。

当前基线为零告警。修改令牌的顺序是：先改 `DESIGN.md`，再改 `tokens.toml`，最后逐处对齐实现——反过来做会让检查器失去意义。

---

## 已知限制

-  *GTK 2 是静态配色。* `gtkrc` 语法没有颜色变量，深色与取色都不生效。GTK 2 主题仅作兼容保留。
-  *Qt 5 取决于发行版打包。* 若发行版未提供 Kvantum 的 Qt5 插件，Qt5 应用无法使用本主题。
-  *Cinnamon / GNOME Shell 的系统级安装是静态的。* 需要取色请用 `make install-user`。
-  *CSD 窗口圆角依赖合成器。* 无合成器环境下 GTK 会退化为方角实色框，这是 GTK 侧行为，与主题无关。

---

## 开发

```bash
make install-user        # 装到 ~/.local，便于反复试
make check               # 令牌一致性检查
./build-deb -d           # 构建 deb（-c 清理）
```

仓库内的 `screenshots/` 保存验收截图，`docs/` 保存设计决策与施工图：

| 文档                                                                         | 内容                                  |
| ---                                                                          | ---                                   |
| [`docs/kvantum-convergence-map.md`](docs/kvantum-convergence-map.md)         | Kvantum 到 deepin GTK 的逐项收敛映射  |
| [`docs/shell-accent-scheme.md`](docs/shell-accent-scheme.md)                 | Cinnamon / GNOME Shell 取色方案与实测 |
| [`docs/shell-accent-decision.md`](docs/shell-accent-decision.md)             | 上述方案的取舍记录                    |
| [`docs/radius-notes.md`](docs/radius-notes.md)                               | 圆角令牌的上游考据                    |
| [`docs/packaging-release-checklist.md`](docs/packaging-release-checklist.md) | 打包与发版核对清单                    |

---

## 许可证

本项目以 [GPL-3.0-or-later](LICENSE) 分发。

## 致谢

-  *[GXDE-OS](https://github.com/GXDE-OS)* ：本主题的基座，DDE 15 的社区维护版本。
-  *[deepin / DDE 15](https://www.deepin.org)* ：这套视觉语言的原作者。
-  *[Kvantum](https://github.com/tsujan/Kvantum)* 与  *KvAdapta* ：Qt 控件主题的引擎与形制来源。
