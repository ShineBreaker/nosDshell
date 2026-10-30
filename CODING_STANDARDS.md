# CODING_STANDARDS：代码约定

写 QML、新增或修改设置、改界面文案时遵守本文件。这些约定多数继承自 Noctalia，在配置文件里看不出来。视觉与交互以 [`DESIGN.md`](./DESIGN.md) 为准。

本文件的每一节都是 `AGENTS.md`「工作方式」在代码里的落点：令牌、设置管线、公共件和注册表就是各类问题的收口点。改动先落在这些层上，组件里只写布局和组合。

## 令牌

- 颜色读 `Colors.*`，尺寸、圆角、时长读 `Style.*`。DDE 的表面和叠加色用语义令牌，例如 `Colors.maskShell`、`Colors.popupShell`、`Colors.overlay(level)`（定义见 `DESIGN.md` §1.2、§1.3）。组件内部只做布局。
- 某个界面元素不随全局设置变化（深色模式下仍是浅色、间距不随 `Style` 缩放），说明它没有接入令牌体系。修法是找到它本该读取的令牌或公共件参数（例如菜单的 `variant`、弹层的 `Colors.popupShell`），把接入点接回去。组件里另写一份配色或尺寸，本身就是没接入的证据。一个组件没接入时，同类组件往往也没接入，按影响面一起查。
- 新数值先加令牌再使用，来路见 `AGENTS.md`「依据」。引用 `references/` 的格式是 `仓库/路径:行号`。

- 会跳动的数值读数（百分比、时间、计数、温度）用 `NText` 的 `numeric: true`，不要在组件里写 `features: { "tnum": 1 }`。只有不是 `NText` 的输入控件（`TextInput`）才直接写 `font.features`。

## 动效

动效的取值和场景表在 `DESIGN.md` §1.7，本节只讲写法。`Scripts/dev/check-motion.py` 在 `lint.sh` 里检查下面前四条。

- 动画一律写成 `NAnim`（数值）或 `NColorAnim`（颜色），用 `curve: "<名字>"` 选 `Style.curves` 里的曲线，循环、计时和拖拽跟手写 `curve: "linear"`。不写 `easing.type`，不直接用 `NumberAnimation`、`ColorAnimation`、`PropertyAnimation`、`SpringAnimation`。只有 `Commons/Colors.qml` 例外：`Commons` 不能导入 `Widgets`，它直接写 `Easing.BezierSpline` 加 `Style.curveSwift`。
- `duration:` 只写令牌。先在 §1.7 的语义令牌里找对应场景（`motionPopupIn`、`motionExpand`、`motionPage`……），场景表里没有就先在 DESIGN 表里加一行、在 `Style.qml` 加令牌，再使用。延时（`PauseAnimation`、计时器）同样写成令牌，它们不随 `animationSpeed` 缩放，也不经过 `_motion()`。
- 颜色 `Behavior` 用 `NColorAnim`，时长是 `Style.motion*`：按钮类控件的指针反馈用 `motionPointer`，数据驱动的状态色用 `motionSwitch`。行类元素不加颜色 `Behavior`。
- `loops: Animation.Infinite` 的动画必须在自己或外层的 `running`（或 `paused`）里读 `Style.reduceMotion`。判断"动画关闭"一律读 `Style.reduceMotion`，不读 `Settings.data.general.animationDisabled`：后者漏掉了性能模式。
- 进场和出场分开写时长和曲线：出场用 `motionExit`、`motionPopupOut`、`motionBubbleOut` 这类更短的令牌，曲线用减速的 `out`、`cssEaseOut`、`fall`，不用回弹曲线。`Behavior` 里按 `closing`/`isRemoving` 这类状态切换 `duration` 和 `curve`，例子见 `Widgets/NPopupReveal.qml`。
- 按钮类控件的按压缩放用 `NPressScale`，不要在组件里手写 `scale` 动画。QtQuick.Controls 的 `Popup` 的 `enter:`/`exit:` 只能是 `NPopupEnter {}`/`NPopupExit {}`（`check-popup-motion.py` 检查）。
- 新曲线要先进 `Scripts/test/test-motion-curves.py` 的参考表，再用 `--emit` 生成 `Style.qml` 里的令牌。拟合曲线不超过 10 段，原因见该脚本里的 `MAX_SEGMENTS`。
- 弹出窗口（`PopupWindow`）要给阴影留边：窗口每边比主体大 `Style.popupShadowInset`，内容用 `NPopupReveal` 的 `inset` 缩回去，输入区域用 `mask: Region { item: ... }` 只留主体，`anchor.adjustment` 设为 `PopupAdjustment.None`。例子见 `Widgets/NPopupContextMenu.qml`。

## 设置

### 新增或修改设置

一个设置要同时改四处：

1. `Assets/settings-default.json`
2. `Commons/Settings.qml`
3. 新建 `Commons/Migrations/MigrationNN.qml`，登记到 `Commons/Migrations/MigrationRegistry.qml`，并把 `Commons/Settings.qml` 的 `settingsVersion` 加一
4. 重建设置搜索索引：`python3 Scripts/test/build-settings-search-index.py`（或 `just search-index`）

用户能看到的新文字同时加翻译（见「界面文字」）。第 4 步和格式化在本机没有 hook 代劳，原因见 `AGENTS.md`「运行与校验」。

### 迁移写法

设置键的三种合法状态（活跃、兼容、删除）定义在 `AGENTS.md`「业务保真」。迁移按变更类型写：

- 新增键：用户配置里缺这个键时写入默认值。判断缺键读 `rawJson`，参考 `Migration75.qml`。
- 改名或搬迁：把旧值搬到新键，再从 `rawJson` 删除旧键，参考 `Migration65.qml`。
- 改默认值：只改仍等于旧默认值的配置，用户自己设过的值保留，参考 `Migration76.qml`。
- 删除功能：从 `rawJson` 删除对应键，并在 `DESIGN.md` §6.1 登记移除项，参考 `Migration67.qml` 与 §6.1 的对应行。
- 兼容数据：把值钉在 DDE 形态要求的取值上，并在 `Commons/Settings.qml` 的声明处注释原因，参考 `Migration72.qml`。

`Scripts/dev/check-settings-keys.py` 把这套规则固化成检查：默认值与声明必须同步，每个键必须代码里有读者（注释、迁移和生成的搜索索引不算），挂在 `lint.sh` 和 CI 里。注释里提到键名不算读者，迁移删掉的 `controlCenter.position` 就是被这条抓出来的。

### 设置页

- 设置页的分组和可见性规则见 `DESIGN.md` §3.5.3。实现上，功能关闭时用 `visible` 隐藏它的配置项；整个子页失效时把 `NSubTabsPane` 里对应 `Title` 的 `shown` 设为 false，隐藏子页签。
- 控件接在当前生效的前端上。只接在已删除或非默认前端上的控件等于没有控件。

### 挂件设置页

挂件设置页（`Modules/Panels/Settings/{Bar,DesktopWidgets,ControlCenter}/WidgetSettings/`）内嵌 `Widgets/WidgetSettingsHelper.qml` 读写设置：

- 读：`settingsHelper.value("key", fallback?)`，依次取编辑中的值、已存值、metadata 默认值、`fallback`。回退链由它负责，页面里不再写三元表达式或 `||`、`??` 回退。
- 写：`settingsHelper.set("key", v)`，整体替换编辑对象，`value()` 的绑定随之刷新。
- 存：`var settings = settingsHelper.save()`，在已存设置的基础上只覆盖编辑过的字段，没改过的字段不写盘。

`value()` 在没有已存值时会回退到默认值。需要"没有已存值就显示空，靠 placeholder 提示默认值"的控件保留直读写法，例如 `Bar/CustomButtonSettings.qml` 的 `textIntervalMs`。在 `saveSettings` 里组装嵌套字段的 SpinBox 也保留原写法。

## 公共件

写新的样板代码之前先查这张表。表里每一项都是已经收敛的公共实现，API 细节看各文件头部注释。同样的写法出现第二次时，把它收敛成公共件，并登记到这张表。

| 公共件 | 负责的事 |
| --- | --- |
| `Widgets/NSubTabsPane.qml` | 设置页的子页导航骨架，取代按 `currentIndex === N` 判断序号 |
| `Widgets/NDisplayModeComboBox.qml` | onhover / alwaysShow / alwaysHide 三选一组合框 |
| `Widgets/WidgetSettingsHelper.qml` | 挂件设置页的读、写、存（见上节） |
| `Modules/Panels/Settings/Bar/WidgetSettings/IconColorSettings.qml` | 只有 iconColor 一项设置的挂件设置页，在 `BarWidgetRegistry` 的 `widgetSettingsMap` 里直接映射到它 |
| `Modules/Bar/Extras/BarWidgetSettingsMenu.qml` | 挂件右键菜单骨架（固定的挂件设置尾项和打开前的准备） |
| `Modules/Bar/Extras/BarWidgetLoader.qml` | 加载挂件并经 `widgetProps` 向挂件注入属性（见「QML 规则」） |
| `Modules/Bar/Extras/FashionTile.qml` | 时尚 dock 里放不下原内容的挂件共用的一格瓦片 |
| `Commons/Settings.getWidgetSettings()` | 按屏幕、区段和序号解析挂件实例的设置 |
| `Commons/AppIdMatcher.qml` | appId 归一化、驻留判定、desktop entry 解析 |
| `Commons/SessionActions.qml` | 电源动作分发（锁定、关机、重启等） |
| `Commons/WorkspaceQuery.js` | 筛选属于某块屏幕的工作区 |
| `Commons/NSurfaceRegion.qml` | 表面输入区域和模糊区域的注册，内含 Quickshell 的平台陷阱处理 |

## 注册

面板通过 `PanelService` 注册和打开，任务栏挂件通过 `BarWidgetRegistry` 注册。新面板和新挂件沿用同一套注册机制。

## QML 规则

- 向不受我们控制的组件注入属性时（第三方插件挂件尤其如此），先确认对方声明了该属性再赋值。`Loader.setSource` 的初始属性不做过滤，对方没有声明就会报 `Cannot assign to non-existent property`。挂件一律经 `BarWidgetLoader` 的 `widgetProps` 守卫式赋值，dock 侧的 `dockPresentation` 也走这条路（`DESIGN.md` §3.1.4）。
- `Item.visible` 读出的是有效可见性：自身和所有祖先都可见时才为 true。祖先一隐藏，子项读出的值就一直是 false。要判断某一项本身是否被设为隐藏，另存一个标志属性再读它，例如 `NSubTabsPane` 给页签按钮加的 `tabShown`。
- JS 对象数组作为 `Repeater` 或 `ListView` 的 model 时会被 QVariant 包装，`modelData` 拿到的是副本，和原数组元素用 `===` 比较永远为 false。选中态和按引用查下标会静默失效（不报错，只是不高亮）。比较一律用稳定字段（`modelData.id === x.id`）；需要保存对象时，先换回原数组里的元素。
- 同一层包装还会去掉 QObject 的生命周期跟踪。数组元素里嵌着的 QObject（`Toplevel`、`DesktopEntry`、媒体播放器、蓝牙设备这类由服务随时销毁的对象），进了 `modelData` 就变成不受 `QPointer` 保护的裸指针。对象销毁后、model 重建前，只要有绑定再读一次就是释放后使用：可能读到 null，可能读到别的对象，也可能直接段错误。条目里会带这类对象时，view 的 model 只给主键或下标（纯数据），委托里用 `owner.entries[index]` 从持有数组的 `property var` 取原 JS 元素。原数组里的 QObject 引用受跟踪：对象销毁后读到的是失效的包装（属性为 `undefined`），不会再解引用野指针，按存活列表过滤（例如 `ToplevelManager.toplevels.values.includes(t)`）就能剔除。例子见 `Modules/Dock/DockContent.qml` 的应用格。
- 挂在高频服务信号（如 `windowListChanged`）上的 JS 快照数组，不要直接作 `Repeater` 的 model：重建出的新数组即使等长同序也是新 model，全部委托会被销毁重建，`asynchronous: true` 的图标会闪烁。改用数量作 model（`model: entries.length`），委托里按下标从持有数组的 `property var` 读条目（`entries[index] ?? 共享空条目`）。例子见 `Modules/Bar/Widgets/Taskbar.qml`。
- 可变 `ListModel` 的行读取（`model.<role>`、`modelData.<role>`、`get(i).<role>`，以及把 `get()` 结果当快照）只在 JS 函数/handler 体内合法；放进绑定表达式会在下一次模型变更后段错误。委托侧的合法读法：逐角色 `required property`（`id` 保留字需改名），或主键/下标行 + 普通 dict 镜像数组。完整规则与崩溃链见 `DESIGN.md` §1.7「动态列表的模型安全」。
- 面板、气泡、菜单、抽屉要避让贴边外壳条带时，不要自己用 `getBarPositionForScreen` + `getBarHeightForScreen` 或 `efficient ? Style.barHeight : Style.dockItemThickness` 拼厚度：时尚模式下无状态栏时 `hasBarOnScreen` 为 false、位置函数又回退到任务栏边，算出来要么为 0 要么只有状态栏密度高，dock 会压住表面。一律用 `BarService` 的四个边距函数，按语义选：`edgeClearance`（要避开的全部占用：条带窗口 + 浮动 margin + 框条模式环带，气泡/菜单/OSD 用这个）、`edgeStripThickness`（只要窗口并集厚度，菜单贴着宿主的偏移用这个）、`edgeBarThickness`（只要栏窗口，dock 允许压上去的面板如 edge sheet 用这个）、`edgeReservedThickness`（栏真正占的工作区）。挂件内部的 `barHeight` 尺寸不在此列，那是组件自身大小，不是避让量。
- 可交互 item 上的 `layer.enabled` 不要绑到会在交互过程中翻转的状态（滚动位置、悬停、选中项、动画中的尺寸）。开关一次 layer 就会销毁并重建盖在 item 上的 effect item，翻转恰好落在按下与松开之间时，这次点击整个丢失，不报错，只能统计复现。layer 的开关条件只用变化缓慢的结构性状态（例如"内容能否滚动"），随交互变化的部分放进 effect 的参数里。再有，遮罩源不能是被 layer 的 item 自己的后代，否则 layer 会采样自身，第一帧之后不再重绘。例子见 `Widgets/NScrollEdgeMask.qml` 的 `needed`，以及 `NScrollView` 把 layer 放在内层 Flickable 上的做法。
- `MouseArea` 的 `onWheel` 里"放行"（让下层 item 继续收到滚轮）必须显式写 `event.accepted = false` 再 `return`，只 `return` 或条件不命中让它掉到函数末尾都不算放行：niri 的滚轮事件到达时默认 accepted，事件就此终止，sway 下却会穿透，差异只在 niri 上暴露。所有盖在可滚内容上、只想旁观滚轮的 `NoButton` 覆盖层都遵守这条；消费滚轮时显式 `event.accepted = true`。例子见 `Widgets/NScrollView.qml` 的滚轮覆盖层和 `SettingsModuleView` 的 takeover 层。
- `ScrollView`（包括 `NScrollView`）里只有一个内容子项时，它按这个子项的隐式尺寸推算 `contentWidth` 和 `contentHeight`。内容子项有两个或更多时（比如内容列旁边再放一个旁观滚轮的覆盖层），推算结果不可靠，可能读出 0，滚动和边缘淡出随之失效且不报错。这种情况下显式写 `contentWidth` 和 `contentHeight`。`lint.sh` 里的 `check-scrollview-content.py` 拦截缺 `contentHeight` 的写法。例子见 `SettingsModuleView` 的 `settingsContentScroll`。

## 界面文字

界面文字一律用 `I18n.tr("key")`。新 key 至少写进 `Assets/Translations/en.json` 和 `Assets/Translations/zh-CN.json`；其余语言文件是子集，缺键时回落到英文。

`Scripts/dev/check-translations.py` 检查两边一致：代码引用的 key 必须存在于 en.json（`trp` 还要 `-plural` 形式），en.json 里不被引用的 key 用 `--fix` 删掉（动态拼接的 key 靠前缀识别，别用纯 grep 判断死活），也挂在 `lint.sh` 和 CI 里。

## 日志

日志一律用 `Logger.d/i/w/e("模块名", ...)`。`Logger.d` 只在调试模式下输出，验证时的用法见 [`DEBUGGING.md`](./DEBUGGING.md)「打开调试」。

## 格式化与注释

- 改过的 QML 文件跑 `Scripts/dev/qmlfmt.sh <路径>`（或 `just fmt <路径>`）。缩进、行宽和按 Qt 版本切换的参数都写在脚本里，直接调用 `qmlformat` 会绕过这些设置。
- 保留现有注释。新代码只在意图不显而易见的地方加一行注释。
