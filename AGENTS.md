# AGENTS.md — nosDshell

nosDshell 基于 Noctalia v4 修改（Quickshell/QML Wayland shell），目标是**以 DDE 15（deepin 15）的风格呈现 Noctalia 的全部功能**。

## 必读

- **`DESIGN.md` 是视觉和交互的唯一依据。** 下面这些工作开始之前，先读 `DESIGN.md` 里对应的章节：改任何可见界面、加组件、调颜色/尺寸/动效、决定 Noctalia 的某个功能放到 DDE 的哪个模块里（对照表在 §2）。
- 规范和实现对不上时，改实现。确实需要改规范，就单独提交一次，只改 `DESIGN.md`，并在提交说明里写明理由和参考依据。
- 一个视觉数值，规范里没有、`Commons/Style.qml` / `Commons/Color.qml` 里也没有令牌，就先去 `references/` 找出处，然后在令牌文件里加上，最后才在组件里使用。

## 参考源码 `references/`

- 这是 GXDE-OS（DDE 15 的社区维护版）的浅克隆，已被 git 忽略，**只读**。
- 用法：查数值、查结构、查行为，引用格式为 `仓库/路径:行号`。组件和仓库的对应关系见 `references/README.md`。
- 参考仓库是 GPL-3.0，本仓库同为 GPL-3.0（上游 Noctalia 部分保留 MIT 声明，见 `LICENSE-MIT`）。**DDE 专属素材（时钟表盘、关机按钮、启动器/控制中心图标等）直接复制原件**，放到 `Assets/DDE/<仓库>/<原相对路径>`，每个仓库目录配一份 `NOTICE`，提交说明里写来源路径（规则见 `DESIGN.md` §1.9）。应用图标和状态图标仍在运行时从系统图标主题读取（推荐 Papirus 或 deepin）。

## 运行环境与校验

本机是 Guix，没有 Nix。shell 运行在**上游 `quickshell`** 上（Guix 频道里的 `quickshell` 包）。`nosdshell.scm` 实际打包的是 `quickshell-nosd`——上游 0.3.0 加两个 fork 未上游的 pipewire UAF 补丁（`packaging/patches/`）。音频频谱由 cava 子进程提供（`Services/Media/SpectrumService.qml`），不要重新引入对 `noctalia-qs` fork 的依赖——它已归档停更。

| 目的 | 命令 |
|---|---|
| 静态检查（只报错误） | `Scripts/dev/lint.sh --changed`（全仓库检查不加参数） |
| 运行并截图（隔离环境） | `Scripts/test/verify.sh <名字> [--settings seed.json] [--scenes a,b]` → `$NOSD_VERIFY_DIR/shots/<名字>/`（默认目录为 `/tmp/nosd-verify`；场景列表见脚本头部注释） |
| 格式化 | `Scripts/dev/qmlfmt.sh <路径>` |
| 设置搜索索引 | `python3 Scripts/test/build-settings-search-index.py` |
| Rust 工具 | `cargo build --release --manifest-path tools/<名字>/Cargo.toml`；`cargo test` 同理 |

- `verify.sh` 在 `dbus-run-session` 里起一个无头 sway，并把 HOME 和所有 XDG 目录都隔离到 `/tmp` 下。**不要**在用户正在使用的 niri 会话里直接运行 `qs`，否则会接管他的通知服务、改动他的配置。
- 结束进程时，只按自己启动时记下的 PID 去 kill。用户会话里也有同名进程（pipewire、wireplumber 等）在运行。
- 检查分级：
  - 每次改完：`lint.sh --changed` 不出现新的错误。
  - 界面改动：再用 `verify.sh` 截一组图，用眼睛和 `DESIGN.md` 逐条对照，同时确认日志里没有新增的 `TypeError`、`ReferenceError`、`.qml:行号` 报错。
  - 已知的离线噪声（没有 NetworkManager、天气数据为 null）不算回归。
- 改到两种任务栏模式、四个停靠方向、亮色/暗色、模糊开关时，要用 `--settings` 把这些组合分别截图验证。

## 调试

开关（四等价）：设置 → 关于 → 调试 开关；关于页 logo 连点 8 次；`qs ipc call debug toggle`；`NOSD_DEBUG=1`（启动前强制开，用于启动期取证）。持久化字段在 `debug.enabled`，`Settings.isDebug` 是 env ∥ 设置的有效值。

- `debug.modules`：`Logger.d` 的模块白名单（逗号分隔，空=全部），如 `"Dock,Tray"`。
- `debug.logLevel`：`"warn"` 时 `Logger.i` 静默，只剩 w/e——禁用调试时的最小化日志。
- 场景取证（`Services/Debug/DebugService.qml`，经 IPC 使用）：
  - `qs ipc call debug list` — 已注册的场景根（`dock-<屏>`、`bar-<屏>`、`cc-<屏>`、`main-<屏>`；bar 只在 efficient 模式加载，cc 是控制中心面板，main 是整个 shell surface）。
  - `qs ipc call debug tree <根> [深度]` — 按绘制序 dump `children[]`，即 Qt hover 投递快照的同一份列表；layer 的 effectSource/effect 这类幽灵子项直接可见，地址可对 gdb。
  - `qs ipc call debug hit <根> <x> <y>` — 沿 `childAt` 命中测试到最深节点并列出每层所有盖住该点的子项；回答"这个坐标的 press 会落到谁手上"。
  - `qs ipc call debug opened [深度]` — dump `PanelService.openedPanel`，多屏注册错名时用它拿"当前真正打开的面板"。
  - `qs ipc call debug watch <名字>` — 给整棵子树挂 `Component.destruction` 探针，谁在投递途中销毁，`DbgWatch` 日志会报名字。
  - `qs ipc call debug status|dump|unwatch`。
- 真指针注入（只用于 verify 的隔离 sway，**不要**在真机会话用）：`tools/nosd-helpers/target/release/nosd-helpers vinput click|jclick <x> <y> [dx dy]`——走 `zwlr_virtual_pointer_v1`，进程存活期间虚拟指针有效。`verify.sh` 的 `settings-tree` 场景是现成示例（rail 命中探针 + 注入点击 + 外点关面板）。
- Qt 侧类别日志必须**启动前**用 env 打开（QML 无法运行时改）：`QT_LOGGING_RULES="qt.quick.hover.trace=true"`（逐 item hover 投递）、`qt.qml.binding.removal=true` 等；core 验尸：`QS_DISABLE_CRASH_HANDLER=1` + `ulimit -c unlimited`，Guix 下调试符号用 `add-symbol-file` 绕过 `.gnu_debuglink` CRC。
- `Logger.d` 受 `debug.enabled` 门控——临时探针在关调试的验证环境里要用 `Logger.i` 才会打出来。
- 现成脚本：`Scripts/test/debug-smoke.sh`（debug 面全链路冒烟）、`Scripts/test/repro-hover-crash.sh`（嵌套 niri 指针扫描 + 周期重启 + core 验尸）。

## 代码约定（Noctalia 已有、配置文件里看不出来的）

- **令牌优先。** 颜色从 `Color.*` 取，尺寸、圆角、时长从 `Style.*` 取；DDE 专用的表面和叠加色用 `Color.maskDark`、`Color.overlay(level)` 这类语义令牌。组件内部只做布局。
- **设置项四处同步。** 新增或修改一个设置，要同时改：`Assets/settings-default.json`、`Commons/Settings.qml`、新的 `Commons/Migrations/MigrationNN.qml`（登记到 `MigrationRegistry.qml`，并递增 `settingsVersion`）、设置搜索索引。迁移时，旧字段原样保留。
- **界面文字全部用 `I18n.tr("key")`。** 新增的 key 至少写进 `Assets/Translations/en.json` 和 `zh-CN.json`。
- **日志用 `Logger.d/i/w/e("模块名", ...)`。** 不要用 `console.log`。
- **面板注册。** 面板通过 `PanelService` 注册和打开，任务栏挂件通过 `BarWidgetRegistry` 注册。新增的东西复用这套机制，不要另起一套。
- **`modelData` 不要 `===` 比对。** JS 对象数组进 `Repeater`/`ListView` model 会被 QVariant 包装，`modelData` 拿到的是副本，与原数组元素 `===` 恒 false——选中态、按引用查下标会静默失效。一律按稳定字段比（`modelData.id === x.id`），需要存对象时先归一化回原数组元素。已踩坑：`SettingsModuleView` 的 rail 点击与高亮。
- 改完的文件用 `qmlformat` 格式化（缩进 2、行宽 360）。
- 现有注释保留不动；新代码只在不显而易见的地方加一行注释。

## 新工具

- 需要 QML 做不好的事（重计算、图像处理、系统级辅助）时，写成 **Rust** 命令行工具，放在 `tools/<名字>/`。
- 工具要求：参数只用 argv，结果写文件或 stdout，用退出码表示成败。shell 侧找不到工具时要能退回到其他方案，并输出一次 `Logger.w`。
- 依赖选择：优先用发布超过 7 天的 crate 版本，并锁定版本。`Cargo.lock` 要提交。
- **改 `tools/*/` 的依赖必须同步 vendor 清单。** `packaging/rust-crates.scm` 是 Guix 离线构建的全部 crate 源，缺一条就报 `no matching package named ...`。流程：`guix import crate --lockfile=tools/<名>/Cargo.lock <名>`，拆进文件并对前面各段去重；`nosd-<名>-cargo-inputs` 必须覆盖 lockfile 每一项。手工补单条也行：crate 哈希可对本地缓存跑 `guix hash $CARGO_HOME/registry/cache/*/<名>-<版本>.crate` 得到（本机 `CARGO_HOME=~/.local/share/cargo`）。
- 单独构建某个工具包验证：`guix build -L . -e '(@ (nosdshell) nosd-<名>)'`。

## 提交

- **每完成一块可独立验证的工作就提交一次。** 校验通过之后再提交，不要把多个阶段攒在一起。
- 提交说明沿用仓库原有的 Conventional Commits 风格，例如 `feat(dock): ...`、`style(tokens): ...`、`docs(design): ...`。正文写清楚：为什么改，以及依据的参考位置（`gxde-dock/...:行号`）。
- 不 push，不改写历史。
