# Changelog

发版文案来源：每次发版时，本文件对应版本的条目即 GitHub Release 的正文（流程见 `docs/RELEASE.md`）。
日常开发把变化记在 `[Unreleased]` 下；发版时将其改名为新版号并写上日期。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，tag 命名为 `v<版号>`。

## [Unreleased]

## [1.0.1] - 2026-10-08

设置页 DDE 化收尾与一轮 Noctalia 业务逻辑保真审计整改：所有设置项统一行样式，几处在改造中丢失或断线的上游能力全部接回。

### 设置界面

- 统一行样式：裸行全部换成 `NDccRow`（设备单选、通知规则、自定义空闲命令、钩子、空闲状态、启动器图标、颜色选择行），同组行合并为一张卡、1 px 缝、首尾圆角自动推断。
- 标题列加宽度下限，"一周的第一天"等长标签不再折行；`NComboBox` 默认字段宽收窄。
- 快捷键录制器修复：已绑按键恢复显示，胶囊等分宽度、空槽改居中图标、清除按钮改为悬停显现。
- 消除 `NTabView.stacked` 下的重复组头；堆叠组间距统一。
- 高级设置拆分为任务栏 / 状态栏 / 显示器 / 面板与圆角四个堆叠组（复用每屏覆盖页，配置键零丢失）。
- 配色模板列表改为自适应多列网格；Toast、取色器、时间日期令牌等弹层统一到 transient/overlay 令牌。
- `settings openTab` 支持子页直达（`tab/sub` 路由兜底），`verify.sh` 新增 `settings-<tab>/<sub>` 与 `settings-scroll-*` 截图场景。

### 业务逻辑保真

- 恢复在线配色方案下载（`SchemeDownloader` + `ShellState` 方案缓存）。
- 恢复状态栏挂件编辑器：全局编辑器接入任务栏页，每屏覆盖页恢复位置/密度/显示模式/挂件编辑。
- 恢复通知历史键盘导航（Tab/方向键/Enter/Delete，动作项高亮）。
- IPC 修正：`openTab bar` 路由到任务栏页，`non_exclusive` 写回 `bar.displayMode`，启动器搜索透传不再被吞。
- vicinae 模板指向现存的 `nosdshell.svg`；迁移器不再产生孤儿设置键。
- Rust 工具（`nosd-theme`/`nosd-helpers`/`nosd-blur`）探测链回退 `target/debug`——开发机上非 release 构建不再让着色/输入注入静默失效。
- 确认有意移除项（更新检查、Changelog、遥测/赞助服务）并在 `DESIGN.md` §6.1 记录理由；关于页注明"更新由系统包管理器统一分发"。

## [1.0] - 2026-10-07

首个正式版本，也是仓库的第一个 tag（此前本地、远端均无任何 tag）。
nosDshell 基于 Noctalia v4（Quickshell/QML），保留其全部功能，以 DDE 15 的视觉语言重做每个界面；全部尺寸、透明度与动效时长取自 GXDE-OS 源码，规范见 `DESIGN.md`。

### 界面

- 统一任务栏：高效模式（通栏）与时尚模式（悬浮 dock），四个停靠方向；弹出层为锚定图标的带箭头矩形气泡。
- 启动器：DDE 风格全屏启动器（模糊壁纸背景，任务栏保持可交互）与迷你启动器；应用 / 命令 / 计算搜索与分类浏览。
- 控制中心：408 px 右缘框架，全屏毛玻璃；15 模块宫格、快捷开关分页与通知历史；设置页默认内嵌。
- 会话菜单：居中一排 140×140 按钮（关机 / 重启 / 挂起 / 休眠 / 锁屏 / 退出登录），默认选中锁屏，带数字键提示。
- OSD：底部居中 140×140 浅色气泡，覆盖音量、亮度与过载状态。
- 通知与 Toast：300 px 气泡逐条排队，DDE 风格动作按钮。
- 锁屏：底部信息带（时钟、日期、媒体与电源控制）+ 居中认证区。

### 继承自 Noctalia 的能力

- Niri / Hyprland / Sway / Scroll / Labwc / MangoWC 多合成器支持，多显示器、壁纸管理、桌面挂件、插件体系、设置迁移。

### 工具与打包

- Rust 工具：`nosd-blur`（壁纸预模糊）、`nosd-helpers`（单二进制多子命令）、`nosd-theme`（Material 主题处理）。
- Guix 打包（`nosdshell.scm`）与 Nix flake（含 home-manager / NixOS 模块）。
- 运行在上游 Quickshell 0.3.1，另带两个 pipewire UAF 补丁（`packaging/patches/`）。

[Unreleased]: https://github.com/ShineBreaker/nosDshell/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.0...v1.0.1
[1.0]: https://github.com/ShineBreaker/nosDshell/releases/tag/v1.0
