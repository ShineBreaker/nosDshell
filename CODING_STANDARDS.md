# CODING_STANDARDS — nosDshell 代码约定

QML 约定多数继承自 Noctalia、配置文件里看不出来，所以在这里写成文字。**视觉与交互仍以 [`DESIGN.md`](./DESIGN.md) 为唯一依据**；要写工具见 [`TOOLS.md`](./TOOLS.md)，要取证见 [`DEBUGGING.md`](./DEBUGGING.md)。

## 令牌优先

- 颜色从 `Color.*` 取，尺寸、圆角、时长从 `Style.*` 取；DDE 专用的表面和叠加色用 `Color.maskDark`、`Color.overlay(level)` 这类语义令牌。组件内部只做布局。
- 新数值若 `Commons/Style.qml` / `Commons/Color.qml` 里没有令牌，先去 `references/` 找出处、把它加进令牌文件，最后才在组件里使用。`DESIGN.md` 的禁用清单把「在组件里写死颜色、尺寸或时长」列为禁止项——本节是它的正面形式。
- `references/` 的引用格式是 `仓库/路径:行号`（权威见 `DESIGN.md` §1）。

## 设置项四处同步

新增或修改一个设置，四处同时改（权威清单见 `DESIGN.md` §6）：

1. `Assets/settings-default.json`
2. `Commons/Settings.qml`
3. 新的 `Commons/Migrations/MigrationNN.qml`，登记到 `Commons/Migrations/MigrationRegistry.qml`，并递增 `settingsVersion`（当前值读 `Commons/Settings.qml` 的 `settingsVersion` 属性）
4. 跑 `python3 Scripts/test/build-settings-search-index.py` 重建设置搜索索引

迁移时旧字段原样保留。`lefthook.yml` 声明了 pre-commit 里的格式化与索引重建，但本机 hook 未生效（`lefthook` 不在 PATH，`core.hooksPath` 下没有 pre-commit），所以第 4 步和下面的格式化都要自己跑。

## 界面文字

全部用 `I18n.tr("key")`。新增的 key 至少写进 `Assets/Translations/en.json` 和 `zh-CN.json`。

## 日志

用 `Logger.d/i/w/e("模块名", ...)`——QML 代码里没有 `console.log`。`Logger.d` 受 `debug.enabled` 门控，验证环境没开调试时它不输出（见 [`DEBUGGING.md`](./DEBUGGING.md)）。

## 面板与任务栏挂件

面板通过 `PanelService` 注册和打开，任务栏挂件通过 `BarWidgetRegistry` 注册；新增的面板或挂件沿用同一套注册机制。

### 挂件设置页样板

挂件设置页（`Modules/Panels/Settings/{Bar,DesktopWidgets,ControlCenter}/WidgetSettings/`）读写设置一律内嵌 `Widgets/WidgetSettingsHelper.qml`，不再手写回退与保存样板：

- 读：`settingsHelper.value("key", fallback?)`——链为 编辑值 → 已存值 → metadata 默认 → fallback。不要再写 `widgetData.X !== undefined ? ... : widgetMetadata.X` 三元，也不要写 `||` / `??` 回退。
- 写：`settingsHelper.set("key", v)`——整体替换 edits 对象，`value()` 绑定保持刷新。
- 存：`var settings = settingsHelper.save()`——复制基座后只覆盖编辑过的字段，没动过的字段不落盘。

只有 iconColor 一项设置的挂件直接映 `WidgetSettings/IconColorSettings.qml`（`widgetSettingsMap` 里 DarkMode / NightLight / PerformanceMode / PowerProfile / WallpaperSelector 五处共用），不新建页面。

两类有意保留的例外，改的时候别顺手"修"成 `value()`：直读控件的空值特判三元（无已存值时必须显示空、靠 placeholder 兜底，见 Bar/CustomButtonSettings 的 textIntervalMs）与 SpinBox 组装路线（嵌套字段在 saveSettings 组装）——换成 `value()` 会改变空值显示行为。

### 公共件先查再造

写新样板之前先查这份清单——以下是已收敛的公共实现，逐个手抄就是造克隆（API 细节看各组件头部注释）：

| 公共件 | 取代的样板 |
| --- | --- |
| `Widgets/NSubTabsPane` | 设置页 SubTab 导航骨架、`currentIndex === N` 序号判断 |
| `Widgets/NDisplayModeComboBox` | onhover / alwaysShow / alwaysHide 组合框整块 |
| `Modules/Bar/Extras/BarWidgetSettingsMenu` | 挂件右键菜单骨架（widget-settings 固定尾项 + 开合前置） |
| `Commons/Settings.getWidgetSettings()` | 按屏/区段/序号解析挂件实例设置 |
| `Commons/AppIdMatcher.qml` | appId 归一化、pinned 判定、desktop-entry 解析 |
| `Commons/SessionActions.qml` | 电源动作分发（lock/shutdown/reboot/...） |
| `Commons/WorkspaceQuery.js` | "哪些工作区属于这块屏"的筛选 |
| `Commons/NSurfaceRegion.qml` | surface 的 blur/mask region 注册（Quickshell 平台陷阱知识） |

## 服务语义守恒

- `Services/`、`Commons/` 是 Noctalia 的业务内核：重写样式时不要改动它们的属性签名、信号时机和副作用。上游语义被替换必须写出依据（平台差异，如 niri/PipeWire），否则视为回归。
- `Assets/settings-default.json` 的每个键都要有消费方；注册表里每个挂件要有可用的配置入口。发现"数据活着、界面死了"先恢复接入，而不是当死代码删掉（参考 `bar.widgets` 的教训：服务链路活着，只是 UI 被砍）。
- 删功能要连带清数据键并写迁移（`Commons/Migrations/`）；留着孤儿键就是留一颗哑弹。

## `modelData` 按稳定字段比对

JS 对象数组进 `Repeater` / `ListView` 的 model 会被 QVariant 包装，`modelData` 拿到的是副本，与原数组元素 `===` 恒 false——选中态和按引用查下标会静默失效（不报错，只是不亮）。一律按稳定字段比（`modelData.id === x.id`）；需要把对象存下来时，先归一化回原数组元素。已踩坑：`SettingsModuleView` 的 rail 点击与高亮。

## 格式化与注释

- 改完的文件跑 `Scripts/dev/qmlfmt.sh <路径>`（缩进、行宽和版本相关的参数都写死在脚本里；直呼 `qmlformat` 会绕过脚本的版本分支）。
- 现有注释保留；新代码只在不显而易见的地方加一行注释。