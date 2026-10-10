# AGENTS.md — nosDshell

nosDshell 基于 Noctalia v4 修改（Quickshell/QML Wayland shell），目标是**以 DDE 15（deepin 15）的风格呈现 Noctalia 的全部功能**——Noctalia 的业务内核（Services、设置数据、挂件体系、插件机制）原样继承，改造只发生在表现层和交互编排。

## 业务保真（先于一切样式工作）

- 分叉点是 `a08ff3619`（上游 `legacy-v4` 末梢），上游完整历史就在本仓库里。比较基线：`git diff a08ff3619..HEAD`——**拿不准"上游本来怎么做"时先查它，而不是猜或重写**。
- **不许另起炉灶**：功能先复用 `Services/`、`Commons/`、注册表里的现有实现。改 UI 时不得顺手改 Service 的属性签名、信号语义、副作用；Service 的行为改动必须能在 commit 里说清"为什么上游语义在这里不适用"（如 niri/PipeWire 补丁这类平台差异）。
- **数据活着 UI 死了 = bug**。`settings-default.json` 的键、注册表的挂件、Service 的接口一旦没有 UI/消费方，要么恢复接入，要么连同数据一起清理（带迁移）；最常见的退化形态就是"上游功能被砍成只剩数据"。
- **砍掉上游能力需要显式理由**：noctalia 身份类（遥测、版本更新检查、GitHub/赞助者服务、吉祥物）是已记录的例外；其他任何上游能力的删除都要在提交正文写依据，并在 `DESIGN.md` 相应章节注明落点（或"不落地"）。
- 排查顺序：业务问题先查本仓库 git 历史和上游实现，表现问题再查 `references/` 的 DDE 源码。

## 必读

- **视觉和交互以 `DESIGN.md` 为唯一依据。** 改任何可见界面、加组件、调颜色/尺寸/动效、决定 Noctalia 的某个功能落到 DDE 的哪个模块（对照表在 §2）之前，先读 `DESIGN.md` 对应章节（`DESIGN.md:5`）。
- 数值链路：`DESIGN.md` → `Commons/Style.qml` / `Commons/Color.qml` 令牌 → 组件。新数值两处都没有，就去 `references/` 找出处，先把令牌加上，最后才在组件里用。

## 参考源码 `references/`

GXDE-OS（DDE 15 社区维护版）的浅克隆；查数值、查结构、查行为，组件↔仓库对照见 `references/README.md`。

DDE 专属素材（时钟表盘、关机按钮、启动器/控制中心图标等）直接复制原件到 `Assets/DDE/<仓库>/<原相对路径>`，每个仓库目录配一份 `NOTICE`，提交说明写来源路径（`DESIGN.md` §1.9）。应用图标和状态图标仍在运行时从系统图标主题读取（推荐 Papirus 或 deepin）。

## 运行环境与校验

本机是 Guix，没有 Nix——仓库里的 `nix/shell.nix` 是上游留下的，`lefthook.yml` 声明的 pre-commit 因此也没生效（本机 `lefthook` 不在 PATH），**格式化与设置索引要自己跑**。shell 运行在**上游 `quickshell`** 上；`nosdshell.scm` 实际打包的是 `quickshell-nosd`——我们的 fork `ShineBreaker/quickshell-nosd`（上游 0.3.2 + 两个 pipewire UAF 修复 commit），需要 pipewire 补丁就用这个已打包的包。音频频谱由 cava 子进程提供（`Services/Media/SpectrumService.qml`）。

- **所有运行验证走 `Scripts/test/verify.sh <名字>`**，它自带隔离环境。用户正在使用的 niri 会话里不直接起 `qs`，否则会接管他的通知服务、改动他的配置。截图落在脚本头部注释写的 shots 目录。
- 需要**真 niri 代码路径**（layer-shell、exclusive zone、焦点/输入投递这类合成器敏感行为，sway 上复现不了）时用 `Scripts/test/niri/`——在真会话里起嵌套 niri 窗口 + 全套隔离 env，会在桌面上开一个窗口，用户在场别跑。用法见目录内 README。
- 结束进程时，只按自己启动时记下的 PID 去 kill。用户会话里也有同名进程（pipewire、wireplumber 等）在运行。
- 分级：
  - 每次改完：`Scripts/dev/lint.sh --changed` 不出现新的错误（全仓库检查不加参数，用法见脚本头部）。
  - 界面改动：再用 `verify.sh` 截一组图，用眼睛和 `DESIGN.md` 逐条对照，同时确认日志里没有新增的 `TypeError`、`ReferenceError`、`.qml:行号` 报错。
  - 性能相关改动（启动、面板开合延迟）：用 `Scripts/test/bench.sh` 建基线再对比——先丢弃一轮预热环境（guix shell 拉包、磁盘缓存冷会让首轮 startup 系统性偏高），再跑三轮取中位；两项指标口径见脚本头部注释。
  - 已知的离线噪声（没有 NetworkManager、天气数据为 null、隔离环境里打开蓝牙子页时 `quickshell.dbus.properties` 写 Discoverable 的 WARN）不算回归。
  - 改到两种任务栏模式、四个停靠方向、亮色/暗色、模糊开关时，要用 `--settings` 把这些组合分别截图验证。

## 分支细则

按这次改动的性质取一份；每份文件单读即可执行，不用回头翻本文件。

- **写 QML、加设置、改界面文案或注释** → [`CODING_STANDARDS.md`](./CODING_STANDARDS.md)：令牌优先、设置项四处同步、挂件设置页 `value()`/`set()` 与公共件先查再造、`I18n.tr` 文案、`Logger.d/i/w/e` 日志、`PanelService` / `BarWidgetRegistry` 注册、`modelData` 按稳定字段比对、格式化与注释。
- **调试：界面行为不符合预期，要取证或复现** → [`DEBUGGING.md`](./DEBUGGING.md)：调试开关四个等价入口、`debug.modules` 与 `debug.logLevel`、场景取证 IPC（`list` / `tree` / `hit` / `opened` / `watch`）、真指针注入、Qt 类别日志与 core 验尸、现成脚本。
- **要写新工具，或改 `tools/*/` 的依赖** → [`TOOLS.md`](./TOOLS.md)：Rust 工具要求、crate 版本选择与 `Cargo.lock`、`packaging/rust-crates.scm` vendor 同步、`guix build` 验证。

## 文档站点（GitHub Pages）

`docs/` 目录同时是 GitHub Pages 站点（main /docs，地址 `https://shinebreaker.github.io/nosDshell/`）。`docs/legacy/` 里是上游 Noctalia v4 wiki 的存档镜像，由 `Scripts/docs/vendor-legacy-docs.py <noctalia-docs 克隆路径>` 从 `noctalia-dev/noctalia-docs` 的 Starlight MDX 全量重新生成——**不要手改 `docs/legacy/` 里的文件**，要改就改脚本重新跑。站点配置在 `docs/_config.yml`（just-the-docs 主题）。

## 提交

- **每完成一块可独立验证的工作就提交一次。** 校验通过之后再提交，不要把多个阶段攒在一起。
- 提交说明沿用仓库原有的 Conventional Commits 风格，例如 `feat(dock): ...`、`style(tokens): ...`、`docs(design): ...`。正文写清楚：为什么改，以及依据的参考位置（`仓库/路径:行号`）。
- 不 push，不改写历史。