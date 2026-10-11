<div align="center">

<img src="Assets/nosdshell.svg" width="110" alt="nosDshell logo" />

# nosDshell

### 以 deepin 15 的界面运行 Noctalia v4 全部功能的 Wayland 桌面 shell

[English](README_EN.md) · [Wiki 文档](https://shinebreaker.github.io/nosDshell/) · [设计规范](DESIGN.md) · [更新日志](CHANGELOG.md)

[![GitHub Release](https://img.shields.io/github/v/release/ShineBreaker/nosDshell?style=for-the-badge&label=release&color=0081ff)](https://github.com/ShineBreaker/nosDshell/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-red?style=for-the-badge)](LICENSE)
[![Wayland](https://img.shields.io/badge/wayland-native-blueviolet?style=for-the-badge)](https://wayland.freedesktop.org)
[![Quickshell](https://img.shields.io/badge/built%20on-quickshell-green?style=for-the-badge)](https://quickshell.outfoxxed.me)
[![Docs](https://img.shields.io/badge/wiki-noctalia%20v4%20mirror-orange?style=for-the-badge)](https://shinebreaker.github.io/nosDshell/)

<img src="Assets/Screenshots/nosdshell-desktop-light.jpg" alt="nosDshell 桌面（亮色主题）" />

</div>

---

## 简介

[Noctalia](https://github.com/noctalia-dev/noctalia-shell) v4 是基于 Quickshell 的 Wayland 桌面 shell。nosDshell 从它分叉而来，保留它的全部功能，把每一个界面按 deepin 15（DDE 15）重做：任务栏、启动器、控制中心、通知、OSD、关机界面和锁屏。

- **数值有出处。** 尺寸、透明度、圆角和动效时长取自 [GXDE-OS](https://github.com/GXDE-OS)（DDE 15 的社区维护版）源码，逐项记录在 [`DESIGN.md`](DESIGN.md) 里并注明源码位置。有意偏离原版的地方，例如更清楚的描边和更柔和的阴影，在规范里标为〔演进〕。
- **功能完整继承 Noctalia v4。** 支持 Niri、Hyprland、Sway、Scroll、Labwc、MangoWC 六种合成器，以及多显示器、壁纸管理、桌面挂件、插件和设置迁移。不适用的上游组件与选项被移除——遥测、版本更新检查、赞助者展示等品牌服务，以及 Noctalia 布局下没有对应物的锁屏、会话菜单与面板选项，完整清单见 [`DESIGN.md`](DESIGN.md) §6.1。
- **亮色与暗色主题。** 玻璃表面随主题切换。单色图标和 `*-symbolic` 图标会自动反色，亮色表面上显示深色，暗色表面上显示浅色。全屏启动器、锁屏和关机界面以壁纸为背景，在两种主题下都保持深色，白色文字始终清晰。

---

## 截图

| 亮色 | 暗色 |
|:---:|:---:|
| ![亮色桌面](Assets/Screenshots/nosdshell-desktop-light.jpg) | ![暗色桌面](Assets/Screenshots/nosdshell-desktop-dark.jpg) |
| ![亮色迷你启动器](Assets/Screenshots/nosdshell-launcher-mini-light.jpg) | ![暗色迷你启动器](Assets/Screenshots/nosdshell-launcher-mini-dark.jpg) |
| ![亮色设置页](Assets/Screenshots/nosdshell-settings-light.jpg) | ![暗色控制中心](Assets/Screenshots/nosdshell-control-center-dark.jpg) |

<details>
<summary><b>更多界面</b></summary>

| | |
|:---:|:---:|
| **全屏启动器**（壁纸背景保持深色） | **高效模式任务栏** |
| ![全屏启动器](Assets/Screenshots/nosdshell-launcher-fullscreen.jpg) | ![高效任务栏](Assets/Screenshots/nosdshell-efficient.jpg) |
| **dock 弹出面板** | **控制中心（亮色）** |
| ![dock 面板](Assets/Screenshots/nosdshell-dock-panel.jpg) | ![亮色控制中心](Assets/Screenshots/nosdshell-control-center-light.jpg) |
| **通知** | **OSD** |
| ![通知](Assets/Screenshots/nosdshell-notification.jpg) | ![OSD](Assets/Screenshots/nosdshell-osd.jpg) |
| **关机界面** | **锁屏** |
| ![关机界面](Assets/Screenshots/nosdshell-session-menu.jpg) | ![锁屏](Assets/Screenshots/nosdshell-lockscreen.jpg) |

</details>

---

## 界面

- **任务栏。** 两种形态：高效模式是贴边通栏，时尚模式是居中的悬浮 dock，可以随时切换，支持四个停靠方向。运行指示条、窗口分组、驻留和拖拽排序按 DDE 的规则实现。弹出面板是指向任务栏图标的带箭头气泡。
- **启动器。** 全屏模式是模糊壁纸上的应用网格，打开时任务栏仍可操作。迷你模式贴着任务栏弹出，支持两级分类浏览（再点一次分类回到全部应用），可以搜索应用、命令和计算。
- **控制中心。** 从屏幕右侧滑出，宽 408 px，包含设置模块网格、分页的快捷开关和通知历史。点击模块直接进入对应设置页，设置页左侧是 56 px 宽的导航条。
- **关机界面。** 屏幕中央一排 140×140 的按钮（关机、重启、待机、休眠、锁定、注销等，可在设置里筛选和排序），可以用方向键或数字键选择。
- **OSD。** 屏幕底部居中的方块，显示音量、亮度和超量音量。显示期间连续调节时就地更新数值，不重播动画。
- **通知与 Toast。** 300 px 宽的气泡，默认一次显示一条，其余排队。`*-symbolic` 应用图标按气泡底色着色。
- **锁屏。** 底部一条信息带显示时钟、日期、媒体控制和电源按钮，中央是头像、密码框、错误提示和 Caps Lock 提示。

---

## 运行要求

- Wayland 合成器：Niri、Hyprland、Sway、Scroll、Labwc 或 MangoWC
- [Quickshell](https://quickshell.outfoxxed.me) 0.3.x
- 图标主题：推荐 Papirus 或 deepin
- 可选的命令行工具（缺少时只影响对应功能）：brightnessctl、ddcutil、wlsunset、wl-clipboard、cliphist、cava、power-profiles-daemon，用途见 [`CREDITS.md`](CREDITS.md)

| 发行版 | 安装方式 |
|---|---|
| Guix | 仓库根目录的 `nosdshell.scm` |
| Nix / NixOS | `flake.nix`，含 home-manager 和 NixOS 模块 |
| 其他 | 克隆本仓库，运行 `qs -p <仓库路径>` |

安装后运行 `nosdshell --version` 即可查看 shell 与 quickshell 的版本。
bash/zsh/fish 的终端补全随包安装到标准目录，新开 shell 自动生效。

---

## 文档

- **[Wiki](https://shinebreaker.github.io/nosDshell/)**：包含上游 Noctalia v4 文档的完整存档（安装、配置、主题、插件开发、IPC 参考）。
- [`DESIGN.md`](DESIGN.md)：DDE 15 视觉与交互规范，界面以它为准。
- [`AGENTS.md`](AGENTS.md)：工程约束与工作方式，按任务类型链接到 [`CODING_STANDARDS.md`](CODING_STANDARDS.md)、[`DEBUGGING.md`](DEBUGGING.md) 和 [`TOOLS.md`](TOOLS.md)。
- [`CHANGELOG.md`](CHANGELOG.md) 和 [`docs/RELEASE.md`](docs/RELEASE.md)：变更记录与发版流程。

---

## 开发

常用命令都包在 `justfile` 里，运行 `just` 可以列出全部。

| 目的 | 命令 |
|---|---|
| 静态检查 | `Scripts/dev/lint.sh [--changed]` |
| 在隔离环境运行并截图 | `Scripts/test/verify.sh <名字> [--settings seed.json] [--scenes a,b]` |
| 在真实 niri 上验证 | `Scripts/test/niri/`（嵌套 niri，会在桌面上打开一个窗口） |
| 性能基线 | `Scripts/test/bench.sh` |
| 格式化 QML | `Scripts/dev/qmlfmt.sh <路径>` |

---

## 许可

GPL-3.0，见 [LICENSE](LICENSE)。
源自上游 Noctalia 的部分仍按 MIT 许可分发，见 [LICENSE-MIT](LICENSE-MIT)。

## 致谢

- [Noctalia](https://github.com/noctalia-dev/noctalia-shell)：本项目的功能基础（v4 分支），其 v4 文档存档托管在本项目的 Wiki。
- [GXDE-OS](https://github.com/GXDE-OS)：DDE 15 的社区维护版，设计数值的来源。默认壁纸 `deepin15-desktop.jpg` 取自其壁纸仓库（CC-BY-3.0 © UnionTech）。
- deepin / DDE 15：这套视觉语言的原作者。

完整致谢与依赖列表见 [`CREDITS.md`](CREDITS.md)。
