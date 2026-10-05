# AGENTS.md — nosDshell

nosDshell 基于 Noctalia v4 修改（Quickshell/QML Wayland shell），目标是**以 DDE 15（deepin 15）的风格呈现 Noctalia 的全部功能**。

## 必读

- **`DESIGN.md` 是视觉和交互的唯一依据。** 下面这些工作开始之前，先读 `DESIGN.md` 里对应的章节：改任何可见界面、加组件、调颜色/尺寸/动效、决定 Noctalia 的某个功能放到 DDE 的哪个模块里（对照表在 §2）。
- 规范和实现对不上时，改实现。确实需要改规范，就单独提交一次，只改 `DESIGN.md`，并在提交说明里写明理由和参考依据。
- 一个视觉数值，规范里没有、`Commons/Style.qml` / `Commons/Color.qml` 里也没有令牌，就先去 `references/` 找出处，然后在令牌文件里加上，最后才在组件里使用。

## 参考源码 `references/`

- 这是 GXDE-OS（DDE 15 的社区维护版）的浅克隆，已被 git 忽略，**只读**。
- 用法：查数值、查结构、查行为，引用格式为 `仓库/路径:行号`。组件和仓库的对应关系见 `references/README.md`。
- 参考仓库是 GPL-3.0，本仓库同为 GPL-3.0（上游 Noctalia 部分保留 MIT 声明，见 `LICENSE-MIT`）。法律上不再禁止直接引用参考代码和素材，但设计上仍以**重新实现**为默认：装饰元素用 QML 画，应用图标和状态图标在运行时从系统图标主题读取（推荐 Papirus 或 deepin）。确需直接复制 GPL-3.0 素材时，保留其版权声明并在提交说明里注明出处。

## 运行环境与校验

本机是 Guix，没有 Nix。shell 运行在**上游 `quickshell`** 上（Guix 频道里的 `quickshell` 包）。音频频谱由 cava 子进程提供（`Services/Media/SpectrumService.qml`），不要重新引入对 `noctalia-qs` fork 的依赖——它已归档停更。

| 目的 | 命令 |
|---|---|
| 静态检查（只报错误） | `Scripts/dev/lint.sh --changed`（全仓库检查不加参数） |
| 运行并截图（隔离环境） | `Scripts/dev/verify.sh <名字> [--settings seed.json] [--scenes a,b]` → `$NOSD_VERIFY_DIR/shots/<名字>/`（默认目录为 `/tmp/nosd-verify`） |
| 格式化 | `Scripts/dev/qmlfmt.sh <路径>` |
| 设置搜索索引 | `python3 Scripts/dev/build-settings-search-index.py` |
| Rust 工具 | `cargo build --release --manifest-path tools/<名字>/Cargo.toml`；`cargo test` 同理 |

- `verify.sh` 在 `dbus-run-session` 里起一个无头 sway，并把 HOME 和所有 XDG 目录都隔离到 `/tmp` 下。**不要**在用户正在使用的 niri 会话里直接运行 `qs`，否则会接管他的通知服务、改动他的配置。
- 结束进程时，只按自己启动时记下的 PID 去 kill。用户会话里也有同名进程（pipewire、wireplumber 等）在运行。
- 检查分级：
  - 每次改完：`lint.sh --changed` 不出现新的错误。
  - 界面改动：再用 `verify.sh` 截一组图，用眼睛和 `DESIGN.md` 逐条对照，同时确认日志里没有新增的 `TypeError`、`ReferenceError`、`.qml:行号` 报错。
  - 已知的离线噪声（没有 NetworkManager、天气数据为 null）不算回归。
- 改到两种任务栏模式、四个停靠方向、亮色/暗色、模糊开关时，要用 `--settings` 把这些组合分别截图验证。

## 代码约定（Noctalia 已有、配置文件里看不出来的）

- **令牌优先。** 颜色从 `Color.*` 取，尺寸、圆角、时长从 `Style.*` 取；DDE 专用的表面和叠加色用 `Color.maskDark`、`Color.overlay(level)` 这类语义令牌。组件内部只做布局。
- **设置项四处同步。** 新增或修改一个设置，要同时改：`Assets/settings-default.json`、`Commons/Settings.qml`、新的 `Commons/Migrations/MigrationNN.qml`（登记到 `MigrationRegistry.qml`，并递增 `settingsVersion`）、设置搜索索引。迁移时，旧字段原样保留。
- **界面文字全部用 `I18n.tr("key")`。** 新增的 key 至少写进 `Assets/Translations/en.json` 和 `zh-CN.json`。
- **日志用 `Logger.d/i/w/e("模块名", ...)`。** 不要用 `console.log`。
- **面板注册。** 面板通过 `PanelService` 注册和打开，任务栏挂件通过 `BarWidgetRegistry` 注册。新增的东西复用这套机制，不要另起一套。
- 改完的文件用 `qmlformat` 格式化（缩进 2、行宽 360）。
- 现有注释保留不动；新代码只在不显而易见的地方加一行注释。

## 新工具

- 需要 QML 做不好的事（重计算、图像处理、系统级辅助）时，写成 **Rust** 命令行工具，放在 `tools/<名字>/`。
- 工具要求：参数只用 argv，结果写文件或 stdout，用退出码表示成败。shell 侧找不到工具时要能退回到其他方案，并输出一次 `Logger.w`。
- 依赖选择：优先用发布超过 7 天的 crate 版本，并锁定版本。`Cargo.lock` 要提交。

## 提交

- **每完成一块可独立验证的工作就提交一次。** 校验通过之后再提交，不要把多个阶段攒在一起。
- 提交说明沿用仓库原有的 Conventional Commits 风格，例如 `feat(dock): ...`、`style(tokens): ...`、`docs(design): ...`。正文写清楚：为什么改，以及依据的参考位置（`gxde-dock/...:行号`）。
- 不 push，不改写历史。
