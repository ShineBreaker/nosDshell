# nosDshell

> 以 deepin 15（DDE 15）的视觉语言呈现的 Wayland 桌面 shell。

nosDshell 基于 Noctalia v4（Quickshell/QML）改造：保留 Noctalia 的全部功能，但每个界面都按 DDE 15 的方式呈现——统一的任务栏、全屏启动器、右缘控制中心、带箭头的弹出层、以及 DDE 风格的会话菜单、OSD、通知和锁屏。

设计不是"凭印象致敬"：所有尺寸、透明度、动效时长都取自 GXDE-OS（DDE 15 的社区维护版）源码，规范写在 [`DESIGN.md`](./DESIGN.md)，工程约束写在 [`AGENTS.md`](./AGENTS.md)。

---

## 预览

![桌面（时尚模式任务栏）](/Assets/Screenshots/nosdshell-desktop.png)

<details>
<summary>更多截图</summary>

![高效模式任务栏](/Assets/Screenshots/nosdshell-efficient.png)
![全屏启动器](/Assets/Screenshots/nosdshell-launcher.png)
![迷你启动器](/Assets/Screenshots/nosdshell-launcher-mini.png)
![控制中心](/Assets/Screenshots/nosdshell-control-center.png)
![会话菜单](/Assets/Screenshots/nosdshell-session-menu.png)
![OSD](/Assets/Screenshots/nosdshell-osd.png)
![锁屏](/Assets/Screenshots/nosdshell-lockscreen.png)
![通知](/Assets/Screenshots/nosdshell-notification.png)

</details>

---

## 界面构成

- **统一任务栏**：高效模式（通栏）与时尚模式（悬浮 dock）两种形态，支持四个停靠方向；弹出层为带箭头的矩形气泡，锚定在触发它的任务栏图标上。
- **启动器**：DDE 风格全屏启动器（模糊壁纸背景，保留任务栏可交互）与迷你启动器；支持应用 / 命令 / 计算搜索与分类浏览。
- **控制中心**：408 px 右缘框架，全屏高，毛玻璃蒙版；含 15 模块宫格、快捷开关分页与通知历史。设置页默认嵌入控制中心内（56 px 导航轨 + 模块内容区）。
- **会话菜单**：居中一排 140×140 按钮（关机 / 重启 / 挂起 / 休眠 / 锁屏 / 退出登录），默认选中锁屏，带数字键提示。
- **OSD**：底部居中的 140×140 浅色气泡，覆盖音量、亮度与过载状态。
- **通知与 Toast**：300 px 气泡，逐条显示并排队，DDE 风格动作按钮。
- **锁屏**：底部信息带（时钟、日期、媒体与电源控制）+ 居中认证区（头像、密码框、错误气泡、Caps Lock 提示）。

继承自 Noctalia 的能力：Niri / Hyprland / Sway / Scroll / Labwc / MangoWC 多合成器支持、多显示器、壁纸管理、桌面挂件、插件体系、设置迁移等。

---

## 运行要求

- Wayland 合成器（见上）
- [Quickshell](https://quickshell.outfoxxed.me)（上游；频谱由 cava 子进程提供）
- 图标主题推荐 Papirus 或 deepin

Guix 用户可直接参考仓库根部的 `nosdshell.scm`。

---

## 开发

| 目的 | 命令 |
|---|---|
| 静态检查 | `Scripts/dev/lint.sh [--changed]` |
| 隔离环境运行并截图 | `Scripts/dev/verify.sh <名字> [--settings seed.json] [--scenes a,b]` |
| 格式化 QML | `Scripts/dev/qmlfmt.sh <路径>` |

界面改动一律以 [`DESIGN.md`](./DESIGN.md) 为准；提交与代码约定见 [`AGENTS.md`](./AGENTS.md)。

---

## 许可

GPL-3.0 License — 见 [LICENSE](./LICENSE)。
源自上游 Noctalia 的部分仍按 MIT License 分发 — 见 [LICENSE-MIT](./LICENSE-MIT)。

## 致谢

- [Noctalia](https://github.com/noctalia-dev/noctalia-shell)：本项目的功能基础（v4 分支）。
- [GXDE-OS](https://github.com/GXDE-OS)：DDE 15 的社区维护版，全部设计数值的来源；默认壁纸 `deepin15-desktop.jpg` 取自其壁纸仓（CC-BY-3.0 © UnionTech）。
- deepin / DDE 15：这套视觉语言的原创者。
