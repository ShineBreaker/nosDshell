# Changelog

发版文案来源：每次发版时，本文件对应版本的条目即 GitHub Release 的正文（流程见 `docs/RELEASE.md`）。
日常开发把变化记在 `[Unreleased]` 下；发版时将其改名为新版号并写上日期。

条目结构（自 v1.1.1 起）：开头一段偏营销的简介，一两句话覆盖本次全部改动 → `---` 分割线 →
正文只写"大概做了什么"，每条引用相关 commit，不复述实现细节。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，tag 命名为 `v<版号>`。

## [Unreleased]

## [1.1.1] - 2026-10-10

一轮观感抛光，顺带补了两项功能：深色模式可以跟随系统切换，电池挂上充电绿/低电红并支持滚轮调亮度；dock 小弹层不再压暗全屏，悬浮阴影的半透明黑块、下拉菜单透出页面文字、右键菜单省略文字这批毛边一并修平。

---

### 新功能

- 深色模式计划新增"跟随系统"，走 freedesktop portal 外观偏好：[`f23fc3de1`](https://github.com/ShineBreaker/nosDshell/commit/f23fc3de1efa349ef0561a7c4ba058ed6ba07b0c)
- 电池挂件按充电（绿）/低电量（红，阈值可调）着色；滚轮调亮度从电源键移到电池：[`c12e4fb6f`](https://github.com/ShineBreaker/nosDshell/commit/c12e4fb6fa47bc406b3c5d741e2d582f0fbedc45) [`c8df3851b`](https://github.com/ShineBreaker/nosDshell/commit/c8df3851bc7d80648c74841fcbdf0d03b4fe27d0)

### 观感修复

- dock 快弹面板不再触发全屏压暗：[`ca7e3ce94`](https://github.com/ShineBreaker/nosDshell/commit/ca7e3ce9482f1af3fe70da82ff403d13c5add88e)
- 悬浮控件阴影的半透明高原区 alpha 减半：[`10f7255a6`](https://github.com/ShineBreaker/nosDshell/commit/10f7255a63e59345fd49ab9cd6055890b1b80eb1)
- 壁纸压暗层固定纯黑，不再随主题染色：[`e592c5429`](https://github.com/ShineBreaker/nosDshell/commit/e592c54293c187ef3bfb066e592b33834098527f)
- 设置页下拉弹层改不透明底，菜单 accent 高亮块加 `radiusRow` 圆角：[`32979f75f`](https://github.com/ShineBreaker/nosDshell/commit/32979f75f970947e168c6d4e69cfa7cbc6a1f53b) [`f3aa14b1d`](https://github.com/ShineBreaker/nosDshell/commit/f3aa14b1de19d7b20080223875d592ff6c809245)
- 右键菜单宽度计入行内边距，短标签不再省略：[`3e1da7312`](https://github.com/ShineBreaker/nosDshell/commit/3e1da73125aa0dc3a299152f2b1bdc00512e6291)
- 勿扰通知的分组续行缩进恢复：[`590209e96`](https://github.com/ShineBreaker/nosDshell/commit/590209e96a4d7f55617764b02bbe1dd3350cec46)

### 设置修复

- 蓝牙/账户等模块页只渲染自己拥有的设置组：[`90228f713`](https://github.com/ShineBreaker/nosDshell/commit/90228f713cdc6772d27e1f3c0f5baee5107fa166)
- 配色方案卡栅格高度塌陷修复：[`ec1e4ec5e`](https://github.com/ShineBreaker/nosDshell/commit/ec1e4ec5e862535bcf56a19f666688a922560aad)

### 工程

- CI 增加 qmllint / 脚本 / 文档同步检查，tag 自动发版：[`90e456816`](https://github.com/ShineBreaker/nosDshell/commit/90e4568162732ca3acdc2d99bb22a7ff9db18c9d)
- README 双语化，Pages 挂载 Noctalia v4 wiki 存档镜像：[`6afbd7252`](https://github.com/ShineBreaker/nosDshell/commit/6afbd72522ca587cb57d3cbb7b73279323e61f01)
- 验证场景新增 settings-combo、dock-context-menu 等：[`05c7578c9`](https://github.com/ShineBreaker/nosDshell/commit/05c7578c994898abf071da0a6459a8088b8b22c3) [`22cb82894`](https://github.com/ShineBreaker/nosDshell/commit/22cb8289418dccfda0bbab3c7abb5a7279e9efcb)

## [1.1.0] - 2026-10-10

主题令牌体系补齐 + 全局白色图标自适应，另有一轮启动器/控制中心修复、性能与重构。

### 主题与图标

- 新增 `Color.onWallpaper` 令牌族（壁纸面恒白前景/叠加层/投影，DESIGN §1.5），壁纸面统一改用它，`onShell`/`overlay()` 在壁纸面禁用。
- 瞬时面（OSD/通知/吐司）整体主题化：`maskTransient` 令牌族 + light/dark 形态与 `ui.transientOpacity` 调节旋钮。
- 表面角色改走配色方案路由（MD3/Noctalia 染色），`accentOverride` 解析到 `m*` 角色层；剩余硬编码颜色全部替换为令牌；亮色模式 `onShell` 弱化层对比度提高。
- 烘焙成白色的 DDE 素材（设置导航、控制中心宫格与铃铛、mini 启动器右栏全套）按面重着色为 `onShell`——亮色面深色、暗色面白色；壁纸面按规范保持白色。
- freedesktop `*-symbolic` 图标按约定染为面墨：通知气泡/历史、mini/全屏/覆盖启动器应用图标、音频面板、图标预览全链路（`ThemeIcons.isSymbolicPath` + `NSymbolicImage.detectSymbolic` + `NImageRounded.symbolicColor`）；彩色图标与照片内容不受影响。

### 启动器

- mini 启动器两级分类列表（重分类点击回 "全部"）、时钟日期不省略、描边收敛为 1 px 发丝。
- 壁纸/空白处点击关闭、点击项直接激活而非旧选中、关闭时可选清空搜索框、打开设置/关机菜单前先关启动器。
- 全屏启动器亮色模式可读性修复；合成器提供模糊时保留 0.55 压暗层（壁纸面保持暗色，§1.5）。
- `LauncherCore` 状态管线并入内嵌 `LauncherModel`；网格右键菜单懒实例化。

### 控制中心与通知

- 页指示点主题化；快捷控制页几何统一并支持滑入分页；滑条恢复跟手；修复 switch 页 1 重复行与分页 chevron/wheel 的 TypeError。
- 边缘 scrim 改为局部阴影带并可按部分调节；通知历史列表虚拟化。
- `NotificationServer` 不再随每次设置保存重建（`org.freedesktop.Notifications` 自竞态）；溢出驱逐改为先删行后 `dismiss()`，修复快速通知间隔一条不弹的问题。

### Dock / 任务栏 / 其他修复

- 时尚托盘胶囊与电池按面令牌渲染；blur/mask region 跟踪重构（`NSurfaceRegion`）；全屏覆盖时释放 strip 输入区。
- "dock" 挂件设置写路由修复（此前静默丢弃）；工作区按屏过滤与 appId 匹配提取为共享件。
- OSD 显示期间再次触发就地刷新数值，不再重播弹出动画（对齐上游）。
- 位置服务无坐标告警每周期一次；蓝牙 discoverable/scanning 乒乓停止；SNI 模型冗余重写合并。
- 锁屏倒计时与快捷键说明在亮色模式保持白色。

### 性能与重构

- keep-alive 面板隐藏期预热；列表边缘按真实表面淡出到无（玻璃面统一）。
- 设置页折叠出 `NDisplayModeComboBox`、`NSubTabsPane`、`IconColorSettings`、`WidgetSettingsHelper` 等共享件；高级溢出页按对象重排；会话电源动作统一 `SessionActions`。
- 合成器 blur region 隐藏时分离；`debug` IPC 增加场景坐标与属性 setter 取证能力。

### 工具与打包

- `quickshell-nosd` 改为我们的 fork `ShineBreaker/quickshell-nosd`（上游 0.3.2 + 两个 pipewire UAF 修复 commit），原 `packaging/patches/` 本地补丁随之移除。
- `Scripts/test/bench.sh` 隔离性能基线；`verify.sh` 新增 cc-slider/launcher-dismiss/category/dock-widget-menu/notification-resave/notification-icon 等场景；`vinput` extent 参数解析修复。
- `DESIGN.md` 增补现代化演绎层说明（结构忠于 DDE 15，渲染层按现代惯例精修）。

## [1.0.2] - 2026-10-08

动效按 DDE 15 规范全面打磨并补充设计规范，另修复启动器崩溃与设置页滚动的两个结构性问题。

### 动效规范与实现

- `DESIGN.md` 新增三层动效规范（瞬变清单、曲线词汇表、不对称退场），`Commons/Style.qml` 补齐 DDE 节拍令牌；全部数值可溯源到 GXDE-OS 源码行号。
- 违禁曲线清零：`OutBack`/`OutInBounce`/`BezierSpline`/无效 overshoot 全部换成规范词汇。
- tooltip、菜单、箭头弹层显隐改为瞬变；22 处指针态颜色/透明度渐变瞬变化（对齐 DDE 即时重绘）。
- OSD：进入 160 ms `OutCubic` 淡入 + 上移 12 px，退出 120 ms `InCubic` 下移 8 px；数值条直跳不补间。
- 通知气泡：进入 180 ms 沿锚定边水平滑入 12 px，退出 300 ms `OutCubic`；错峰延迟的外漂修正。
- Toast 入/出拆分 180/300 ms；面板与遮罩退场统一 `InCubic`。
- 滚轮惯性 800 ms `OutQuint` 与程序化滚动 300 ms `OutQuad` 分开驱动。
- dock 提醒摆动按 `appswingeffectbuilder.h` 帧表重做（±8° 阻尼 + 18 px 抬升，约 2.2 s 一轮）。
- 控制中心 home↔模块页切恢复水平滑动（几何 Behavior 误挂换肤守卫修复）。
- 启动器：底框与内容统一进可动画面，mini 8 px 位移真正生效，黑幕/遮罩随面板透明度渐变；壁纸默认过渡对齐 DDE 约 1 s。

### 修复

- 启动器快速切换模式时偶发 `QQmlIncubator` 崩溃：委托孵化窗口内的服务回调用 `Qt.callLater` 移出孵化窗口，搜索结果模型每键入两次全量重置改为单次赋值。
- 设置页从启动器/IPC 打开时直跳目标模块（此前 1400 ms 从头滚到尾，懒加载期间看似卡住）；滚动动画只保留给 rail 点击与键盘翻页。
- dock 图标静止时倾斜 8°：摆动相位公式在 `swingPhase=0` 处读出 8°，旋转改为仅在摆动动画运行时生效。
- 长时间运行后偶发 `QQmlIncubator` 崩溃：toplevel/SNI 信号突发期间 `dockApps` 全量重赋值重入 Repeater 委托孵化；重建合并到事件循环单回合执行，且应用序/类型/置顶态/toplevel 集合不变时跳过赋值。
- 窗口全屏时该输出的任务栏/dock 自动隐藏（不留感应条、悬停不唤出），退出即恢复；niri 端经 ext-foreign-toplevel 关联窗口判定全屏，`DESIGN.md` §3.1 已记录语义。

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

[Unreleased]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/ShineBreaker/nosDshell/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.0...v1.0.1
[1.0]: https://github.com/ShineBreaker/nosDshell/releases/tag/v1.0
