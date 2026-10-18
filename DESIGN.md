# nosDshell 设计规范：DDE 15 视觉语言

本文件规定 nosDshell 的视觉和交互风格，目标是让 Noctalia 的每项功能都以 deepin 15（DDE 15）的界面方式呈现。所有界面改动都要符合本规范。代码与规范冲突时改代码；确实要改规范，就单独提交，并在提交说明里写清理由。

数值的来源是 `references/` 下的 GXDE-OS 仓库（DDE 15 的社区维护版，GPL-3.0，只供阅读）。出处写成 `gxde-dock/frame/item/appitem.cpp:297` 的形式，路径相对 `references/`。两种标记说明数值不是直接取自源码：

- 〔派生〕：参考源码里没有，由本规范按 DDE 的总体规则推导。
- 〔演进〕：有意偏离原版的现代化取值（见 §0「2026 演绎」），新值取代原值生效。

---

## 0. 一句话概括 DDE 15

> **近黑色的毛玻璃，上面叠半透明白色；只有一个强调色：深度蓝 `#2CA7F8`。**

DDE 15 的界面安静、扁平、几何感强。表面要么是"模糊加黑色蒙版"，要么是"模糊加白色蒙版"。悬停、按下、选中这几种状态，只靠白色叠加层的透明度来区分，不换颜色。表面上不放彩色，强调色只用在"当前项"上。

> **2026 演绎**：结构、布局和交互逐条忠于 DDE 15，渲染层按现代惯例精修，包括看得见的发丝描边、更柔和的阴影，以及能跟随主题的瞬时面（OSD、通知、吐司，见 §1.2）。这些取值标为〔演进〕。默认值仍落在 DDE 15 的范围内，超出范围的调节交给设置项（§6）。

### 设计原则

1. **用蒙版，不用色块。** 常驻面板的背景是背后模糊加一层半透明蒙版。蒙版颜色取自配色方案的表面角色〔演进：原为纯黑、纯白字面量〕，面板取 `mSurface`，弹出层取 `mSurfaceVariant`；蒙版的 DDE 透明度和模糊行为不变。Deepin 方案的表面值（暗 `#181818`、浅 `#F8F8F8`）就是 DDE 15 的近黑、近白观感，其他方案得到各自色调的玻璃（§5）。面板背景不用渐变，也不直接铺 Material 的不透明 tonal surface。OSD 和通知气泡这类瞬时提示例外，它们读 `maskTransient` 令牌族：经典形态是不透明浅色实底（DDE 原版），也可以切换为深色玻璃或跟随明暗模式（§1.2，`ui.transientSurface`）。
2. **前景透明度阶梯。** 表面上的所有层级都是"该表面的前景色 × 某个透明度"。暗色面用 `onShell`，壁纸面用恒白，浅色瞬时面用深色文字色（§1.3）。
3. **一个强调色。** `#2CA7F8` 只用在：当前活动项、菜单悬停行、按下态、进度和高亮、链接。其他地方不出现。
4. **小圆角。** 圆角在 4–10 px 之间（§1.4）。除头像、圆点这类正圆外，不要胶囊形，不要大圆角卡片。
5. **贴边并居中。** 任务栏贴住屏幕边缘并居中；控制中心贴右边、占满屏高；弹出层用带箭头的矩形指向触发它的任务栏图标，与栏保持分离，不用 Noctalia 的 attached panel 和反向圆角。
6. **少动效。** 指针反馈分两类。独立的按钮类控件（按钮、图标按钮、页签、快捷开关格、分段按钮）的悬停和按下颜色用 80 ms 的 `motionPointer` 淡变〔演进，§1.7〕；成组排列的行类元素（菜单行、列表行、网格单元、设置行、导航按钮、任务栏项）仍然瞬变，与 DDE 的即时重绘一致，指针扫过一串行时不留拖影。弹出层、菜单与提示框的显隐用一套短促的淡入淡出〔演进，§1.7〕。只有数据或生命周期驱动的变化才做动画：进入用 `OutCubic`，位移和尺寸用 `InOutCubic`，时长基准 300 ms，退场比进场快并使用 ease-in 曲线。弹簧、回弹和水波纹都不用。
7. **每个效果都要有降级方案。** 关掉模糊时，蒙版要更不透明（§1.2）。关掉动画时，时长为 0。

---

## 1. 设计令牌（Design Tokens）

令牌放在 `Commons/Style.qml`（尺寸、时长）和 `Commons/Color.qml`（颜色）。组件只读令牌；需要新数值时，先在这两个文件里加令牌。

### 1.1 强调色与功能色

| 令牌 | 值 | 用途 | 来源 |
|---|---|---|---|
| `accent` | `#2CA7F8` | 活动项、菜单悬停、按下态、选中线、链接 | `gxde-dock/frame/item/appitem.cpp:297-309`；`deepin-menu/src/dmenucontent.cpp:164` |
| `accentAlt` | `#01BDFF` | 设置组标题旁的"编辑"类文字按钮、OSD 高亮 | `gxde-control-center` `SettingsHead QLabel#Edit`（dark.qss） |
| `accentAction` | `#0087FF` | 浅色气泡里的动作按钮文字；悬停时变成白字蓝底 | `gxde-session-ui/dde-osd/notification/actionbutton.cpp:30-63` |
| `attention` | `#F18A2E` | 窗口请求注意时（任务栏项填充 80%） | `gxde-dock/frame/item/appitem.cpp:313` |
| `alert` | `#F9704F` | 密码错误边框、错误提示文字 | `gxde-session-ui/dde-lock/skin/dpasswdeditanimated.qss` |
| `lowPower` | `#FF8000` | 低电量警告文字 | `gxde-session-ui/dde-lowpower/window.cpp` |
| `positive` | `#9AD82D`（暗）/ `#4E7A00`（亮） | 接通电源/充电态着色 | 暗色侧：`gxde-dock/plugins/power/resources/icons/battery_*_plugged.svg` 填充色；浅色侧〔派生：原填充色在浅底文字/图标上仅约 1.6:1，按同色相加暗至 ≈4.8:1〕 |
| `textDisabledDark` | `#646464` | 暗色菜单里的禁用项 | `deepin-menu/src/ddockmenu.cpp:92-96` |

### 1.2 表面（蒙版）

| 令牌 | 有模糊时 | 无模糊时 | 来源 |
|---|---|---|---|
| `maskDark` | `mSurface` × `ui.panelBackgroundOpacity`（默认 0.65） | `mSurface` × 0.8 | dtkwidget `DBlurEffectWidget::maskColor()`（DarkColor：有模糊时用 maskAlpha，无模糊时用 `MASK_COLOR_ALPHA_DEFAULT=204`）。Deepin 原默认 `opacity=0.4`（`gxde-desktop-schemas` `com.deepin.dde.appearance`），这里提到 0.65，压住透上来的文字〔演进〕。RGB 改取方案表面色〔演进〕，Deepin 的 `#181818` 接近原版 `#000000` |
| `maskLight` | `mSurface` × `ui.panelBackgroundOpacity`〔派生，与暗色对称〕 | `mSurface` × 0.8 | 同上（LightColor）。RGB 改取方案表面色〔演进〕，Deepin 的 `#F8F8F8` 接近原版 `#FFFFFF` |
| `popupDark` | `mSurfaceVariant` × 0.86 × `ui.popupOpacity`（默认 1.0，范围 0.3–1.0；`popupShell` 在应用层再乘这个系数） | 同左 | `gxde-dock/frame/util/dockpopupwindow.cpp:50-55`（Wayland 实测值）。RGB 改取方案 `mSurfaceVariant`〔演进〕，Deepin 的 `#2A2A2A` 接近原版 `#242424` |
| `borderDark` | `mOutline` × 0.10〔演进：原版 0.05 在现代屏幕上几乎看不见，提高到看得见的发丝边。底色改取方案 `mOutline`，Deepin 的 `#3A3A3A` 接近原版 `#2C3238`〕 | `mOutline` | `gxde-dock/frame/util/dockpopupwindow.cpp:207-213` |
| `borderLight` | `mOutline` × 0.08〔演进：原版 0.04。底色改取方案 `mOutline`，Deepin 的 `#D5D5D5` 接近原版 `#E5E5E5`〕 | `mOutline` | `gxde-session-ui/dde-osd/container.cpp:73-78`；`notification/bubble.cpp:288-296` |

规则：

- 任务栏、控制中心和启动器小窗口用 `maskDark`。任务栏弹出层和暗色菜单面积小，需要更高的不透明度才看得清，用 `popupDark`。
- OSD、通知气泡和吐司用 `maskTransient` 令牌族。瞬时面的形态由 `ui.transientSurface` 控制：
  - `light`：不透明的浅色实底配深色文字，即 DDE 15 原版形态，浅色瞬时提示叠在暗色常驻外壳之上。底色取方案的浅色面〔演进〕。浅色模式下就是 `mSurface`（Deepin 为 `#F8F8F8`，其他浅色方案各随其色调）；暗色模式下方案没有浅色面，退为固定的经典值 `#F8F8F8`，保证 `light` 始终是 DDE 的那块浅色方块。DDE 原版用近乎不透明的 `DBlurEffectWidget::LightColor`，半透明会发浑并降低对比度，所以取实色。
  - `dark`〔演进〕：深色玻璃。暗色模式下底色取方案的 `mSurfaceVariant`（Deepin 为 `#2A2A2A`）；浅色模式下方案没有深色面，退为固定的 `#242424`。有模糊时 alpha 不低于 0.5。文字、描边和叠加层整体换成暗面规格（见本节最后一条）。
  - `auto`（默认）〔演进〕：暗色模式按 `dark`，浅色模式按 `light`，跟随系统观感。
  - `ui.transientOpacity`（默认 1.0，范围 0.3–1.0）作用于两种形态。有模糊时直接乘在各自的基准 alpha 上（light 为 1.0，dark 为 0.86）；无模糊时最终 alpha 一律不低于 0.9，因为没有模糊的半透明面会发浑，宁可平坦。`notifications.backgroundOpacity` 是通知专属的系数，在此基础上再相乘。
- 全屏界面（全屏启动器、关机界面、锁屏）不用蒙版，背景是预先模糊好的壁纸（§1.8）。
- "有模糊"指 `Settings.data.general.enableBlurBehind` 为真，并且合成器确实提供 `ext-background-effect-v1`（启动时探测，见 §4.1）。合成器不支持时一律按无模糊处理，取 0.8 蒙版；否则半透明蒙版下面是清晰的壁纸，文字无法阅读。透明度只由令牌计算，组件直接读 `Color.maskDark` 这类令牌。
- 半透明蒙版是为"底下有合成器模糊"设计的：任何用 `maskShell`/`maskDark` 这类蒙版填充可视内容的表面（面板、菜单、对话框宿主），都必须把这块区域注册为 `BackgroundEffect.blurRegion`（用 `NSurfaceRegion` 跟踪可视项），漏注册时蒙版下透出的是清晰内容。例：`PopupMenuWindow` 承载右键菜单打开的挂件设置对话框，只在对话框存在且 `Color.blurActive` 时把对话框矩形注册为模糊区域。因此设置页里的模态 `Popup`（挂件/插件/规则编辑等）一律经 `PanelService.hostSettingsPopup`（一次性对象则用 `PopupMenuWindow.hostDialog`）寄宿到该表面，不要直接挂在 `Overlay.overlay` 上——设置窗口自己的表面没有为对话框注册模糊区。
- 组件实际读的是下列语义令牌：
  - `Color.maskShell`：常驻外壳（任务栏、控制中心、小窗口启动器、对话框）。暗色模式下等于 `maskDark`，浅色模式下等于 `maskLight`。DDE 15 只有暗色外壳，浅色外壳是为配色方案的浅色模式准备的。
  - `Color.popupShell`：弹出层和暗色菜单。暗色模式下等于 `popupDark`，浅色模式下为 `mSurface` × 0.9〔演进：原为固定白色 × 0.9〕。
  - `Color.popupPage`：不透明页面表面上的弹出菜单（设置页等内容页里的下拉）。RGB 同 `popupShell`（暗色 `mSurfaceVariant`、浅色 `mSurface`），恒不透明、不受 `ui.popupOpacity` 缩放。底下的表面是页面不是壁纸，半透明会透出文字〔演进：原先组件直用不透明的方案表面色实填〕。
  - `Color.borderShell` 和 `Color.borderTransient`：分别对应 `borderDark` 和 `borderLight`，浅色外壳使用 `borderLight`。描边透明度整体乘以 `ui.borderEmphasis`（0–2，默认 1，0 表示无描边）〔演进〕。
  - `Color.maskTransient`：瞬时提示（OSD、通知气泡、吐司），按上面的 `ui.transientSurface` 规则取值〔演进：原版恒为不透明 `#F8F8F8`〕。
- 配套的前景色：
  - `Color.onShell` 是方案的 `mOnSurface`〔演进〕。Deepin 仍是暗色 `#FFFFFF`、浅色 `#303030`，其他方案的外壳文字随方案色相（例如 Gruvbox 的米黄）。
  - `Color.onTransient` 同理：浅色瞬时面用深色文字（浅色模式取 `onShell`，暗色模式固定为经典值 `#303030`），深色瞬时面用浅色文字。
  - `onShellSecondary` 和 `onShellTertiary` 是弱化级。暗色侧按 DDE 规格取 alpha 0.8 和 0.6。浅色侧的 tertiary 提到 0.7：`#303030` × 0.6 在白底上对比度只有约 3.8:1，0.7 约为 `#6E6E6E`（约 5:1），与浅色方案的 `mOnSurfaceVariant`（`#6B6B6B`）一致。
  - §1.3 的叠加阶梯以对应表面的前景色为底色。
- 瞬时面为 `dark` 时，整组瞬时令牌翻转〔演进〕。暗色模式下，`onTransient` 取 `onShell`（方案的白色或米白等），`onTransientBody` 取前景 × 0.85，`onTransientTrack` 取前景 × 0.15，`onTransientTick` 取前景 × 0.5，`overlayTransient(level)` 取前景阶梯，动作文字 `transientAction` 取 `accent`（浅色面上是 `accentAction`）。浅色模式下强制使用深色方块时，前景退为固定的白色。组件只读这些令牌，不判断当前是哪种形态。
- 壁纸面（全屏启动器、关机界面、锁屏，即 §1.8 的预模糊壁纸加暗色压暗）在两种模式下都是暗色表面，上面的内容使用不随主题翻转的令牌：`Color.onWallpaper`、`onWallpaperSecondary`、`onWallpaperTertiary`（恒白阶梯），`overlayWallpaper(level)`（恒白叠加阶梯），`onWallpaperShadow`（§1.5 的文字投影 `rgba(0,0,0,0.31)`）。这些表面上不用 `onShell` 和 `overlay()`。

### 1.3 前景叠加阶梯（MD3 state layer）

阶梯的规则与 MD3 state layer 相同：状态色等于该表面的前景色乘以层级透明度。`Color.overlay(level)` 以 `onShell` 为底色，也就是方案的 `mOnSurface`：暗色模式下 Deepin 为白色，其他方案随各自色相；浅色模式下取 `mOnSurface` 的深色值，Deepin 为 `#303030`，接近原版的黑色阶梯〔演进：原为白色、黑色字面量〕。壁纸面改用 `overlayWallpaper`（恒白），瞬时面用 `overlayTransient`（以 `onTransient` 为底色）。

| 层级 | α | 典型用途 | 来源 |
|---|---|---|---|
| `idle` | 0.03 | 控制中心模块格子默认态、更新提示条 | `gxde-control-center/src/frame/navigation/navdelegate.cpp:41-57`（7/255） |
| `subtle` | 0.05 | 小窗口启动器里视图的容器底色 | launcher `miniframe.qss #ViewWrapper` |
| `hover` | 0.10 | 列表行悬停、分隔线、插件项悬停、启动器搜索结果 | `gxde-launcher/src/delegate/applistdelegate.cpp:79-90`；`gxde-dock/frame/item/pluginsitem.cpp:131-160` |
| `field` | 0.15 | 密码框底色、控制中心分隔线 | `gxde-session-ui/session-widgets/userinputwidget.cpp:58-69` |
| `strong` | 0.20 | 设置项底色（`rgba(238,238,238,.2)`）、搜索框底色、高效模式下运行中应用的底色 | control-center dark.qss `SettingsItem`；launcher `#SearchEdit`；`appitem.cpp:316` |
| `checked` | 0.30 | 选中、可交互设置行的悬停 | control-center dark.qss / common.qss |

**黑色压暗**（用在模糊壁纸上的选中块）：`rgba(0,0,0,0.41)`（105/255），用于全屏启动器网格的悬停/选中，以及关机按钮的选中态（`gxde-launcher/src/delegate/appitemdelegate.cpp:131-140`；`gxde-session-ui/widgets/rounditembutton.cpp:175-189`）。

### 1.4 圆角

| 令牌 | px | 用途 | 来源 |
|---|---|---|---|
| `radiusRow` | 4 | 列表行悬停、导航按钮、小窗口启动器的按钮、暗色菜单 | `applistdelegate.cpp:79-90`；`deepin-menu/src/dmenubase.cpp:45-62` |
| `radiusItem` | 5 | 控制中心格子、设置组的首尾行、搜索框、时尚模式任务栏窗口、登录按钮 | `navdelegate.cpp`；common.qss；`gxde-dock/frame/window/mainwindow.cpp:842` |
| `radiusPopup` | 6 | 带箭头弹出层、密码框、快捷开关的选中块、插件悬停 | `gxde-dock/frame/item/dockitem.cpp:68`；`quickswitchbutton.cpp:74-99` |
| `radiusWindow` | 8 | 通知气泡、对话框（`dtk-window-radius`）、浅色菜单 | `bubble.cpp:288-296`；xsettings `dtk-window-radius=8` |
| `radiusLarge` | 10 | OSD、关机按钮选中块、启动器网格悬停、时尚托盘胶囊、小窗口启动器贴近任务栏的那个角 | `dde-osd/container.cpp:318-321`；`rounditembutton.cpp`；`appitemdelegate.cpp:131`；`gxde-launcher/src/windowedframe.h:159` |

- 圆角令牌的基准值不超过 10 px，正圆除外。
- `general.radiusRatio` 和 `iRadiusRatio`（取值 0–2，即 0–200%，默认 1）继续作为整体缩放系数。用户可以借它把整套圆角等比放大到超过 10 px，这是有意留给用户的调节空间。
- 控制中心贴边部分是直角（`frame.cpp:150`）。任务栏在高效模式下是直角。

### 1.5 文字

| 角色 | 规格 | 来源 |
|---|---|---|
| 系统字体 | `Noto Sans`；中日韩用 `Noto Sans CJK SC/TC/JP/KR`；等宽 `Noto Mono` | `gxde-desktop-schemas` appearance `font-standard`；`gxde-default-settings/.../fontconfig.json` |
| 基础字号 | 9 pt（约 12 px） | appearance `font-size=9.0` |
| 暗色表面主文字 | `#FFFFFF` | 多处 |
| 暗色次要文字 | 白 × 0.8（数值、提示）；白 × 0.6（导航默认态、容量） | control-center `TipsLabel`；launcher `categorybutton.cpp:193-213` |
| 浅色表面标题 | `#303030`，原版字重 460，取 Medium(500) | `dde-osd/notification/appbody.cpp:30-31` |
| 浅色表面正文 | `rgba(0,0,0,0.9)` | 同上 |
| 页面标题 | 14 px，字重 500，居中 | control-center `QLabel#ContentTitle` |
| 设置组标题 | 原版字重 550，取 DemiBold(600) | `settingshead.cpp` + common.qss |
| 控制中心时钟 | 46 px，Light | `mainwidget.cpp:99-107` |
| 锁屏时钟 | 68 px，Light（原版字体为 Maven Pro Light；退回 `Noto Sans` Light），日期 16 px | `dde-lock/timewidget.cpp:36-60` |
| 模糊壁纸上的文字 | 白色，加一层黑色投影 `rgba(0,0,0,0.31)`，偏移 (0,1) | `appitemdelegate.cpp:142-153` |

- 字重只用 Light(300)、Regular(400)、Medium(500)、DemiBold(600)，不用 Bold。
- 字体相关设置项（`ui.fontDefault` 等）保留。默认值为空，表示按上表依次回退。
- 数值读数（百分比、温度、时长、计数）用界面字体加等宽数字（`font.features: { "tnum": 1 }`），数字跳动时宽度不变。等宽字体 `ui.fontFixed` 只用于代码、命令、键名和十六进制色值这类本身就是等宽的内容〔演进：原先滑块旁的百分比用等宽字体，与同一行的界面字体混排〕。
- 日期和时间一律经 `Commons/Time.qml` 的格式化函数输出，底层是 `I18n.locale`，跟随界面语言：长日期用 `Time.formatLongDate(date)`，"月份 + 年份"用 `Time.formatMonthYear(date)`（模式写在翻译文件的 `time.month-year-format` 里，英文 `MMMM yyyy`，中文 `yyyy年M月`）。不用 `Qt.formatDate`、`Qt.formatDateTime`、`Qt.formatTime` 和 `toLocale*String(Qt.locale())`：它们按系统区域格式化，界面是中文时会冒出英文日期。本地化的月名、星期名不转大写（§7）。

### 1.6 阴影

| 用途 | 模糊半径 | 偏移 | 颜色 | 来源 |
|---|---|---|---|---|
| 带箭头弹出层 | 32 | (0,3) | 黑 × 0.18〔演进：原版为 20、(0,2)、0.5，改为半径更大、不透明度更低的柔和阴影〕 | `dockitem.cpp:64-67` |
| 控制中心 | 32 | (-16,0) | 黑 × 0.24 〔演进〕 | `frame.cpp:151-154` |
| OSD | 24 | (0,5) | 黑 × 0.14 〔演进：原版 16/0.27〕 | `container.cpp:73-78` |
| 通知气泡 | 24 | (0,4) | 黑 × 0.18 〔演进：原版 14/0.39〕 | `bubble.cpp:133-134` |
| 浅色菜单 | 20 | (0,8) | 黑 × 0.12 〔演进：原版 12/0.2〕 | `dmenubase.cpp:88-96` |
| 对话框 | 32 | (0,0) | 黑 × 0.18 〔演进〕 | `dockitem.cpp:64-67` |

任务栏本身没有阴影（`mainwindow.cpp:104-110`）。阴影统一用 `NDropShadow` 绘制，参数从令牌读取。原有的 `general.shadowDirection` 和 `shadowOffset*` 设置保留，默认值改为上表。`general.shadowStrength`（0–2，默认 1）整体缩放阴影颜色的不透明度〔演进〕。阴影颜色的不透明度刻意压在 0.24 以下：剪影式阴影在原轮廓内部是一整块满 alpha 的区域，放在矩形气泡下会看成一块半透明黑底；低 alpha 加大模糊半径能让这块区域淡成柔和的投影。

### 1.7 动效

DDE 15 的动效很少。`deepin-menu` 整个库没有一个动画对象；dock 的弹出层、tooltip 和窗口预览全部瞬变（本实现给弹出面的显隐补了短淡入淡出，见下方规则）；hover 高亮在鼠标事件里直接重绘。真正做插值的动画分三层：微反馈（不超过 180 ms）、空间过渡（300 ms 主节拍）、长动效（壁纸交叉淡化、滚轮惯性、attention 摆动）。

| 令牌 | 时长 | 曲线 | 用于 | 来源 |
|---|---|---|---|---|
| `motionPanel` | 300 ms | InOutCubic | 任务栏显示/隐藏/尺寸变化、控制中心内的页面切换 | `gxde-dock/frame/window/mainwindow.cpp:360-386`；`gxde-control-center/src/frame/framewidget.cpp:44-51` |
| `motionEnter` | 300 ms | OutCubic | 控制中心整窗滑入、各类面板出现 | `gxde-control-center/src/frame/frame.cpp:71,90-95` |
| `motionBubbleIn` | 180 ms | OutCubic，从锚定的屏幕边水平滑入 12 px 并淡入（DDE 右下角气泡把 waylandEnterOffset 从 −12 变到 0，加在 rightMargin 上） | 通知出现 | `gxde-session-ui/dde-osd/notification/bubble.cpp:218-225,496-508` |
| `motionBubbleOut` | 300 ms | OutCubic，向右滑出（DDE 为向右缘塌缩的 geometry 动画） | 通知消失 | `gxde-session-ui/dde-osd/notification/bubble.cpp:486-488` |
| `motionOsdIn` / `motionOsdOut` | 160 / 120 ms | OutCubic / InCubic。进入时下边距偏移从 −12 变到 0（自下而上），退出时变到 −8 | OSD 出现/消失 | `gxde-session-ui/dde-osd/container.cpp:199-218` |
| 壁纸过渡 | 1000 ms | InOutCubic | `wallpaper.transitionDuration`（默认 1000，设置滑杆 0.5–10 s） | `gxde-session-ui/widgets/fullscreenbackground.cpp:51-74` |
| `motionPopupIn` / `motionPopupOut` | 160 / 120 ms | OutCubic / InCubic。淡入淡出；有锚定边的弹出面（任务栏弹出层、菜单）同时沿锚定边方向位移：进入时从朝锚点偏移 `popupEnterOffset`（8 px）处滑到原位，退出时滑回 `popupExitOffset`（4 px）。没有锚定边的面（提示框、子菜单、下拉框、对话框）只淡入淡出 | 任务栏弹出层、各类菜单、提示框、下拉框与对话框的显隐〔演进：DDE 原版瞬变，见下方规则〕 | 时长与曲线取自 `motionOsdIn` / `motionOsdOut` 的同一组节拍（`gxde-session-ui/dde-osd/container.cpp:199-218`） |
| `motionNavZoom` | 300 ms | OutCubic | 启动器分类导航悬停时从 1.0 放大到 1.2 | `gxde-launcher/src/widgets/navigationwidget.cpp:213-230` |
| `motionSettingsScroll` | 1400 ms | OutQuint | 设置页内定位与页内长滚动 | `gxde-control-center/src/frame/widgets/contentwidget.cpp:51,106-112` |
| `motionScrollWheel` | 800 ms | OutQuint | 滚轮惯性滚动（列表/网格/滚动视图） | `gxde-launcher/src/view/applistview.cpp:105-112` |
| `motionProgramScroll` | 300 ms | OutQuad | 程序化滚动定位（点分类跳锚点、滚动到可见） | `gxde-launcher/src/fullscreenframe.cpp:189-204`（未显式设时长，Qt 默认 250，归并到 300 主节拍） |
| `motionSwing` | 1200 ms | Linear 关键帧（±8°，阻尼衰减回中） | dock 项 attention 摆动，持续期间每 ~2.2 s 重播 | `gxde-dock/frame/item/components/appswingeffectbuilder.h:87-118`；`appitem.cpp:690-732` |
| `motionPointer` | 80 ms | OutCubic | 按钮类控件的悬停、按下颜色淡变（§0 原则 6） | 〔演进〕DDE 原版瞬变。取 Windows 11 WinUI 指针反馈的量级（`ControlFasterAnimationDuration` 83 ms），曲线并入本节词汇表 |
| `motionSwitch` | 150 ms | OutCubic | 开关滑块；数据驱动的状态色（选中、已连接、勿扰开启这类不由指针直接决定的颜色）的过渡 | 派生自 DTK（§3.5.4） |
| `tooltipDelayDock` | 500 ms | — | 任务栏悬停提示 | `gxde-dock/frame/item/dockitem.cpp:75` |

非动画时长不进 Style 令牌，它们是用户可调设置：`osd.autoHideMs`（默认 1000，`dde-osd/manager.cpp:74`）与 `notifications.*UrgencyDuration`（低/普通/紧急 3/5/15 s，`bubble.cpp:514-517`）。

规则：

- **瞬变清单。** DDE 明确不做动画的地方，这里也不补动效：菜单悬停与子菜单内的高亮移动；行类元素（§0 原则 6）的指针态颜色与透明度，包括悬停才显示的行内按钮；禁用态；attention 图标切换；OSD 数值条；密码错误反馈（描边 + 文字，无抖动）；启动器显示模式切换。
- **颜色过渡标注意图。** 每个 `Behavior on color` / `border.color` 的时长都写成表明意图的令牌：按钮类的指针反馈用 `motionPointer`，状态色用 `motionSwitch`，其他场景按上表取。`Style.animationFast` 这类通用时长和字面量不用于颜色过渡，行类元素的指针态不加 Behavior。主题切换期间颜色一律瞬变（`enabled: !Color.isTransitioning`）。`Scripts/dev/check-color-motion.py` 检查颜色过渡的时长令牌和下一条的曲线词汇表。
- 有意的偏离：弹出面的显隐〔演进〕。DDE 的菜单、任务栏弹出层和提示框都是瞬显瞬隐（`deepin-menu` 没有动画对象，`dockpopupwindow.cpp:84-148` 直接 show/hide）。本实现统一用 `motionPopupIn` / `motionPopupOut`：瞬显瞬隐在合成器上读作闪烁，短促的淡入加锚定方向的小位移能交代弹出层从哪里来，同时不拖慢操作。弹出面的背景、阴影、内容一起淡化；背后模糊无法渐变，进入时随面一起出现，退出开始时立即撤掉，不让模糊比面多停留。
- **曲线词汇表。** `OutCubic` = 进入；`InOutCubic` = 位移/尺寸/页面切换；`InCubic` = 快速退场；`OutQuad` = 程序化滚动定位；`OutQuint` = 滚轮长惯性；`Linear` = 旋转/循环/计时/拖拽跟手。其余曲线（`InOutQuad` 等不在表中的 Quad/Sine/Expo 变体，以及 Back、Elastic、Bounce、Spring、自定义 `BezierSpline`）一律禁用。
- **不对称退场。** 退出比进入短，并使用 ease-in 曲线。OSD 的 160/120 ms、`OutCubic` 进入配 `InCubic` 退出是范例。
- **合并语义。** 运行中的动画再次被触发时，只改目标值，不打断。QML 的 `Behavior` 本来就这样；手写 `start()` 时先以当前值为起点。
- **延时不是动画。** tooltip 的 500 ms、预览的 200/300 ms、自动隐藏的 100 ms（`mainwindow.cpp:282-294`；`docksettings.h:78`）这类 `singleShot` 是状态切换前的防抖等待，不换算成缓动。
- **应用条增删项动画（两模式同一套配方）〔演进〕。** DDE 的应用条增删项瞬变（`Repeater` 直接重建），本实现为数据/生命周期驱动的进出补动效：应用条用带字符串行键的 `ListModel` + 延迟移除——条目消失时行转为 dying、沿长轴塌缩到 0（`animationFast` + `InCubic` 退场曲线）后再从模型里删；新条目在 0 长处长出到正常尺寸（`animationNormal` 300 ms + `InOutCubic`），进出都带 `animationFast` 淡入淡出；兄弟项的滑动由塌缩本身驱动，不用 positioner transition（Layout 容器不支持）。高效 `Taskbar.qml` 的 `itemRows` 与时尚 `Dock.qml` 的 `dockRows` 是同一配方的两份实现。
- **动态列表的模型安全（崩溃教训）。** 会反复重建的 JS 数组永远不直接喂 `Repeater.model`——整体赋值即 `QQuickRepeater::setModel` → 孵化，孵化期间的 notify 重入模型变更会踩坏 V4 堆（`QV4::Object::insertMember` SIGSEGV）。收敛做法：渲染模型是常驻 `ListModel`，数据侧变化经 `Qt.callLater` 合并后增量同步（`insert`/`remove`/`setProperty`），行只放原始值键（id/序号/tag），payload 由委托侧按键实时解析；ListModel 行角色在首次写入时钉死类型，存对象/数组/`null` 混合值既触发角色类型冲突警告、又会在委托销毁中途返回已失效的 `QObject*`（`QQmlListModel::data` 崩溃类）。落点：`Bar._initModels`/`Dock.updateDockApps`/`Taskbar.updateCombinedModel`/`DockContent.segmentRows`/`NSectionEditor.widgetRows`。
- 有意的偏离：DDE 的启动器开合和关机界面都是零动画瞬显，本实现为这两类全屏毛玻璃面保留 `motionEnter` 短淡入。layer-shell 全屏面瞬间出现时合成器上会闪一下，而且要等模糊壁纸的第一帧。
- 关闭模糊时，panel/enter 类动画时长改为 150 ms（`framewidget.cpp:172`）。`animationDisabled` 为真时一律为 0。
- 已有的 `Style.animationFast/Normal/...` 继续留给通用场景（如拖拽跟手、装饰性循环）。上表列出的场景一律用表中的令牌。

### 1.8 背景与模糊壁纸

- 全屏启动器、关机界面和锁屏都画预先模糊好的当前壁纸，按 cover 方式（等比放大后居中裁切）缩放到屏幕尺寸，最底下先铺一层纯黑（`fullscreenbackground.cpp:142,259-275`）。
- 模糊图由 Rust 工具 `nosd-blur` 生成并缓存（对应 deepin 的 `com.deepin.daemon.ImageBlur`，见 §4）。缓存图还没生成好时，先用 `MultiEffect` 实时模糊顶替。
- 启动器上下两端各有 60 px 的渐隐带（`GradientLabel`，`constants.h:41`）。

### 1.9 图标

- **应用图标**：全彩，取系统图标主题（推荐 Papirus 或 deepin；不随仓库分发）。
- **状态与托盘图标**：16 px 的 `*-symbolic` 主题图标（`battery-*-symbolic`、`audio-volume-*-symbolic`、`network-*-symbolic`）。主题里找不到时，退回 Tabler 字形。
- **电池图标的状态色**〔演进〕：接通电源（充电中或已充满）时，图标和电量文字着 `positive` 绿色；电量低于 `systemMonitor.batteryWarningThreshold`（默认 20%，在阈值页调整）时着 `alert` 红色。DDE 自己的电源素材本来就分颜色（`battery_*_plugged.svg` 和 `battery_plugged.svg` 为绿色，`battery_0.svg` 为红色，`battery_2.svg` 为琥珀色），这里把原色统一到令牌。
- **界面字形**：继续用 Tabler 线性图标（风格和 DDE 15 的细线图标一致）。常用尺寸 16 / 22 / 24 px，**不用填充（filled）变体**。
- 控制中心模块图标 24 px，关机按钮图标 75 px，锁屏头像 100 px（§3）。
- **DDE 专属素材可以直接复用**（本仓库与参考仓库同为 GPL-3.0）。凡是 DDE 15 自带、系统图标主题里没有对应物的界面素材，优先从 `references/` 复制原件，而不是用 Tabler 字形或 QML 重画近似物：
  - 时尚模式时钟插件的表盘与数字（`gxde-dock/plugins/datetime/resources/icons/*.svg`）
  - 关机界面按钮（`gxde-session-ui/dde-shutdown/img/*.svg`，含 normal / hover / press 三态）
  - 锁屏右下角操作按钮（`gxde-session-ui/widgets/img/bottom_actions/*.svg`）
  - 启动器搜索行按钮、分类图标、小窗口右栏图标（`gxde-launcher/src/skin/icons/*`、`gxde-launcher/src/widgets/images/*`）
  - 控制中心导航条与模块图标（`gxde-control-center/src/frame/modules/*/themes/dark/icons/*.svg`）
- 复用规则：
  - 原样复制到 `Assets/DDE/<参考仓库名>/<原相对路径>`，不改文件名，便于溯源；每个 `Assets/DDE/<仓库>/` 目录放一份 `NOTICE`，列出来源仓库、上游版权声明和许可证。
  - 有多态素材（normal / hover / press / checked）的，按原逻辑切换，不用透明度或滤镜模拟。
  - 只复制实际用到的文件。应用图标和托盘/状态图标仍然从系统图标主题读取，不随仓库分发。
  - 复制的位图如有 `@2x` 版本，一并复制，按屏幕缩放选用。
- 参考仓库里没有素材的小装饰（运行指示条、弹出层箭头等），继续用 QML 画（`Rectangle`、`Shape`、`Canvas`）。
- **自绘图标与原版同重。** `Assets/Nav/` 里补齐的扩展模块图标会和 DDE 原版图标并排出现在导航条和所有设置页的模块网格里，视觉重量必须一致：以实心剪影为主，图形占 24 px 画布中约 20 px（坐标 2–22），镂空和间隙不窄于 1.5 px，不用 1 px 线框〔演进：早期自绘图标是 1 px 描边、只占 18 px，与原版的实心剪影并排时明显偏小偏淡〕。
- **启动器图标只有一个来源。** 时尚模式的启动器项、高效模式的启动器插件和状态栏的启动器挂件都取同一个图标：主题图标 `deepin-launcher`，找不到时依次试 `start-here`，最后用 `Assets/DDE/deepin-icon-theme/deepin/places/96/deepin-launcher.svg`。查找逻辑只在 `Commons/ThemeIcons.qml` 的一个函数里，用户在设置里指定的自定义图标优先。

### 1.10 文案与术语

界面中文用 DDE 15 的叫法，同一个对象全仓库只用一个名字：

| 代码 / 英文 | 中文 |
|---|---|
| Dock | 任务栏 |
| Bar | 状态栏 |
| Launcher | 启动器 |
| Control Center | 控制中心 |
| Bar / Dock widget | 插件 |
| Desktop widget | 桌面挂件 |
| Session menu | 关机界面 |
| Toast | 提示条 |
| Workspace | 工作区 |
| Bluetooth | 蓝牙 |

- 可以保留原文的只有通用缩写和专有名词：Wi-Fi、VPN、CPU、GPU、OSD、IPC、JSON、UEFI、Markdown、产品名（nosDshell、niri、Wallhaven、GitHub、Material 等）和命令名。`check-translations.py` 检查 `zh-CN.json` 里不出现上表左列的英文词，钩子说明、占位符示例这类引用命令原文的键在脚本里登记例外。
- 开关行的标题写功能名（"勿扰模式"），开没开由开关本身表达，不写"启用勿扰模式""关闭勿扰模式"这类随状态变化的动作句〔GNOME、macOS、Windows 11 的开关都这样写〕。
- 按钮写动作（"全部清除""连接"）。开放网络（无密码）的安全性写"开放"，不写成动词"打开"。
- 空状态写"没有 X"，有下一步可做时补一句提示（"在设置中设置位置以查看天气"）。不留只有占位图、没有文字的空白区域。
- 同一弹出层或页面里不出现两个同名分区标题；需要区分时写全对象（"输出设备""输入设备"）。

---

## 2. Noctalia 功能与 DDE 15 模块的对照

左列的每项 Noctalia 功能都落到右列的 DDE 形态上。

| Noctalia | DDE 15 形态 | 规格章节 |
|---|---|---|
| `Modules/Bar`（顶栏） | 任务栏 · 高效模式（贴边通栏） | §3.1 |
| `Modules/Dock` | 任务栏 · 时尚模式（居中） | §3.1 |
| Bar 上的挂件（`Modules/Bar/Widgets/*`） | 任务栏插件（两种模式下样式不同） | §3.1.4 |
| Bar 和 Dock 上的弹出面板（Audio / Network / Bluetooth / Battery / Brightness / Clock / Media / SystemStats / Tray 抽屉 / 插件面板） | 带箭头弹出层（DockPopupWindow） | §3.2 |
| 提示框 `Modules/Tooltip` | 暗色带箭头的提示框（TipsWidget） | §3.2 |
| 右键菜单 `NContextMenu` / `NPopupContextMenu` / `TrayMenu` / `DockMenu` | deepin-menu：暗色带箭头菜单 / 浅色菜单 | §3.3 |
| 启动器 `Panels/Launcher` | 全屏启动器（默认）+ 小窗口启动器 | §3.4 |
| 控制中心 `Panels/ControlCenter` + 卡片 | 控制中心首页（右侧滑出） | §3.5 |
| 设置 `Panels/Settings` | 控制中心设置页（56 px 图标导航条 + 内容区） | §3.5.3 |
| 通知历史 `Panels/NotificationHistory` | 控制中心默认首页的通知区（铃铛切换到所有设置页） | §3.5.2 |
| 通知 `Modules/Notification` | 浅色通知气泡 | §3.6 |
| 吐司 `Modules/Toast` | 浅色气泡的简化版 | §3.6 |
| OSD `Modules/OSD` | dde-osd 浅色方块 | §3.7 |
| 会话菜单 `Panels/SessionMenu` | dde-shutdown 全屏关机界面 | §3.8 |
| 锁屏 `Modules/LockScreen` | dde-lock | §3.9 |
| 壁纸 `Panels/Wallpaper` | 底部壁纸选择条〔派生自 dde-desktop，参考仓库中没有〕 | §3.10 |
| 首次设置向导 `Panels/SetupWizard` | 类似 dde-welcome：模糊壁纸 + 居中的暗色对话框 | §3.11 |
| 各类确认弹窗 | DDialog 暗色对话框 | §3.11 |
| 桌面挂件 `Modules/DesktopWidgets` | 暗色毛玻璃小卡片 | §3.12 |
| 屏幕圆角 `ScreenCorners`、栏的 framed/floating 形态、外圆角 | DDE 中没有。屏幕圆角保留功能代码、默认关闭；栏体形态只对可选状态栏开放（§3.13），任务栏永远是 `simple`。屏幕圆角的设置在"个性化"，栏体细节在"任务栏"〔演进：按配置对象归位，不集中放在"高级"〕 | — |
| 多个配色方案、壁纸取色 | 默认用 Deepin 方案。切换方案时，表面色调、文字色相和强调色随方案变化 | §5 |

---

## 3. 组件规格

### 3.1 任务栏（Dock）

任务栏只有一个，有两种模式，同一时刻只显示一种，由 `dock.mode` 选择：`"fashion"`（默认）或 `"efficient"`。
来源：`gxde-dock`；默认值取自 `com.deepin.dde.dock.gschema.xml`。

#### 3.1.1 通用

- 位置：`bottom`（默认）、`top`、`left`、`right`，贴住屏幕边缘。
- 尺寸：图标尺寸分小 30、中 36（默认）、大 48 三档（`docksettings.cpp:42-44`）。
  - 项高 = 图标尺寸 × 1.5（时尚）或 × 1.2（高效）。
  - 项宽 = 项高 × 1.1（时尚）或 × 1.4（高效）。
  - 项内图标边长 = min(w,h) × 0.8（时尚）或 × 0.7（高效）。
- 背景：`maskDark`，再乘 `dock.backgroundOpacity`（默认 1.0，范围 0.3–1.0）〔演进〕。直接贴边，没有阴影，没有边框。时尚模式在启用合成时圆角为 5（`radiusItem`），高效模式为直角。
- 隐藏模式（对应 DDE 的 `hide-mode`）：
  - `keep-showing`：预留屏幕空间（exclusive）。
  - `keep-hidden`：自动隐藏。
  - `smart-hide`：有窗口挡住时隐藏；合成器不支持时按 `keep-hidden` 处理。
- 全屏：某个输出上有窗口全屏时，该输出的任务栏无条件隐藏，不留 2 px 感应条，悬停也不唤出；退出全屏后恢复。〔派生：DDE 里真正全屏的应用会盖住 dock〕
- 隐藏和显示：沿屏幕边缘滑动，`motionPanel`。显示延迟 100 ms（`show-timeout`），隐藏延迟 100 ms。隐藏后只在边缘留 2 px 的感应条。
- 悬停提示：延迟 500 ms，用暗色带箭头提示框，箭头尖端距项边缘 2 px。
- 右键：
  - 点在图标区域内（居中、边长为 0.8 × min(w,h) 的正方形），弹出该项的暗色带箭头菜单。
  - 点在图标区域外，或点在空白处，弹出任务栏设置菜单，包含模式、位置、大小、状态和插件开关（`docksettings.cpp:208-251`），以及一个「任务管理器」入口。〔演进：原版固定为浅色菜单，这里改用随全局明暗变化的 `popupShell`。`NPopupContextMenu` 的 `"dark"` 变体就是跟随主题的表面，`"light"` 只留给明确要求 DDE 经典白底的场景。任务管理器是 nosd 扩展，对齐 Windows 任务栏右键的习惯：执行 `dock.taskManagerCommand`（默认 `btop`），经 `appLauncher.terminalCommand` 套终端运行，命令在设置 → 任务栏里可改。〕

#### 3.1.2 时尚模式（fashion）

- 居中。最大长度 = 屏幕边长 − 60 px（`FASHION_MODE_PADDING=30`）。
- 条内容 = 有序序列，不做硬编码分区：`dock.taskbarWidgets.left` ++ `dock.taskbarWidgets.center` ++ `dock.plugins` 打平成一条（`DockContent.contentList`）。Launcher / Taskbar / Spacer 是结构化条目（各自的形态件渲染）；其余已注册挂件 id 每段连续区间并成一个插件瓦片区，瓦片前留一道细缝。每个条目都可增删、排序、改实例设置——入口与高效模式共用同一个编辑器（§3.5.3），一份布置跨模式生效。
- 应用条的工作区过滤沿用 Taskbar 条目的 `onlyActiveWorkspaces`（默认开）：开=只显示活动工作区的应用，关=显示全部工作区。设在任务栏插件页 Taskbar 条目的齿轮里，两模式同键同语义。
- 运行指示：
  - 运行中：在贴屏幕边的一侧画一条 20×2 px 的横条（竖放时 2×20），距项边缘 1–3 px，颜色白 × 0.25。
  - 活动窗口：同一位置，颜色为 `accent`，两端渐隐（`appitem.cpp:320-358`）。
- 悬停：图标整体提亮（相当于 `QColor::lighter`，QML 中用约 0.15 的 `MultiEffect.brightness` 实现），不画悬停底色。
- 请求注意：图标轻微摆动（swing），同时指示条变为 `attention` 色。
- 应用太多放不下时，按比例缩小每个项（`mainpanel.cpp:623-698`）。

#### 3.1.3 高效模式（efficient）

- 占满整条屏幕边。从左到右依次是启动器、任务列表、伸缩空白、托盘与插件区、显示桌面条。
- 部件布局可编辑〔演进〕：`dock.taskbarWidgets.{left,center}` 存任务栏左侧与中间区的部件（含启动器、任务列表条目本身，可增删排序）；右侧插件区仍是 `dock.plugins`，与时尚模式共用同一份有序列表；显示桌面条固定收尾，不进列表。编辑入口在设置 → 任务栏 → 插件子页（§3.5.3），形态同状态栏的左/中/右三区编辑器；状态栏自己的布局仍是 `bar.widgets`，两者互不影响。左区只有含填充部件（任务列表、伸缩空白）时才伸展到插件区，否则按 `bar.widgetSpacing` 紧凑排布；中区部件的中轴始终对齐屏幕中线。各区的可用长度由条本身算给部件：伸展区给填充项剩余量，中区给绕中线的对称净空，右区给到左簇的跨度；任务列表项超出可用长度才按 `gxde-dock mainpanel.cpp` 的比例收缩（项长 `barHeight×1.4`，图标取短边 × 0.7）。
- 应用项（`appitem.cpp:291-317`），各状态都在项的矩形内、四周缩进 1 px：
  - 活动：填充 `accent` × 0.3，并在贴屏幕边的一侧画一条 `accent` 线，项高 > 50 时线宽 4 px，否则 2 px。
  - 运行中：填充白 × 0.2。
  - 请求注意：填充 `attention` × 0.8。
- 显示桌面条：宽 10 px，与前一项间隔 1 px。默认白 × 0.1，悬停白 × 0.2，按下为 `accent` 实色（`showdesktopitem.cpp:86-98`）。点击动作取决于合成器：支持时显示桌面，否则切换概览；两者都不支持时隐藏。
- 插件项悬停：插件的 sizeHint 区域内画白 × 0.1 底色，圆角 6。
- 被收纳的托盘图标放进一个 24×24 的箭头容器，箭头指向远离屏幕边的方向（`containeritem.cpp`）。

#### 3.1.4 插件（原 Bar 挂件）

各插件在两种模式下的形态：

| Noctalia 挂件 | 高效模式 | 时尚模式 |
|---|---|---|
| Launcher | 启动器图标，`dock.launcherIconSize` px（0 = 推导为 16，与其余插件 glyph 同号） | 启动器图标（0.6–0.8） |
| Taskbar | 应用项（§3.1.3） | 应用条段——DockContent 的 taskbarComp，条目可移动/删除/配置（`onlyActiveWorkspaces` 等实例设置在齿轮里生效） |
| Clock | 白字两行居中 `hh:mm` / `yyyy/MM/dd`；竖放时三行；宽 = 字宽 + 20 | 占满一个应用项大小的槽位，显示"时钟图标"：表盘为槽位的 0.8 倍，上面是大号数字时间。它与应用图标同级，不是小瓦片（`datetimewidget.cpp` 的 sizeHint 返回应用项槽位），不受 `dock.pluginSpacing` 影响 |
| Tray | 16 px 图标排成一行，间距 10 | 时尚托盘：圆角 10 的胶囊，可展开、收起；分隔线 2 px，白 × 0.1（`fashiontraycontrolwidget.cpp`）。胶囊底色与其他插件瓦片一致，用 `overlay` 阶梯（`subtle`、`hover`、`checked`）〔演进：上游展开态是暗色 `#282828` × 0.5〕。图标默认彩色；挂件的"图标着色"（`colorizeIcons`）开关对任务栏内联图标、时尚胶囊和收纳弹层同键生效，开启后统一按 `onShell` 单色化 |
| Volume / Microphone / Network / Bluetooth / VPN / Brightness / Battery | 16 px symbolic 图标，sizeHint 26×26；Battery 在图标右侧加百分比文字 | 0.8 倍的图标 |
| SessionMenu | `system-shutdown` symbolic | `system-shutdown` 彩色图标 |
| NotificationHistory | 铃铛 symbolic（有未读时显示角标） | 铃铛图标；点击打开控制中心的通知页 |
| ControlCenter / Settings | 控制中心图标 | 同左 |
| Workspace | 同 bar 的胶囊行（`WorkspacePill`，可变宽格）：默认显示工作区索引，当前项 `accent` 底且加宽，`labelMode`/`pillSize`/字号等控件同样生效；每格可点直接切换，右键仍是挂件菜单 〔演进：原为 14 px 纯色小方格，不带编号且无法表达占用态，与时尚模式同为胶囊行〕 | 同高效模式；可选的按应用分组视图也可用 〔演进〕 |
| ActiveWindow / MediaMini / SystemMonitor / AudioVisualizer / KeyboardLayout / LockKeys / CustomButton / DarkMode / NightLight / KeepAwake / PowerProfile / NoctaliaPerformance / WallpaperSelector | 16 px 图标，或单行白字（可选） | 0.8 倍的图标，不显示文字 |
| Spacer | 伸缩空白 | 忽略 |
| （新增）Trash | `user-trash[-full]` | 同左；点击打开回收站，弹出层里可清空 |

- 默认插件（时尚模式）：Tray、NotificationHistory、Network、Volume、Battery、Clock、SessionMenu、Trash。
- 统一接口 `dockPresentation`：时尚 dock 加载挂件时注入这个属性，注入方式见 `CODING_STANDARDS.md`「QML 规则」。每个可以被 `dock.plugins` 引用的挂件都要声明它并实现时尚呈现，按挂件类型分三种做法：
  - 图标按钮类：把 `baseSize`、`bgSize`、`iconRatio`、`colorBg`、`border` 切换到瓦片取值。
  - `BarPill` 类：把属性转发给 pill，pill 已经实现了 `collapseToIcon`。
  - 自绘类（ActiveWindow、MediaMini、SystemMonitor、AudioVisualizer、LockKeys 等，文字或图形收不进一格）：隐藏原内容，显示 `Modules/Bar/Extras/FashionTile`，即一格共享瓦片，点击行为与原挂件的主操作相同。

  没有声明这个属性的第三方插件挂件按 bar 形态显示，不错位、不报错。
- 时尚模式插件区的布局规则〔演进：上游每个插件固定占一个 `itemThickness` 方格，间隔过大〕：
  - 每个插件占一格，格宽等于插件自身的视觉宽度加两侧各一个 `dock.pluginSpacing`。固定瓦片的格宽是 `Style.dockPluginCellSize`（`dockPluginTileSize` + 2 × spacing），托盘这类宽度会变的插件按当前视觉宽度计算。这样任意两个相邻插件的边到边距离都等于 2 × spacing + `itemSpacing`，合并底色时间距也均匀。
  - 瓦片内容（图标、底色块）在自己的格子里居中，格内留白只来自 spacing。
  - 插件区总长度按实际排布测量，不按格数估算，末尾的插件才不会被 dock 边缘裁掉。
  - 时钟是唯一的例外：它占满一个应用项槽位（见上表），不参与格宽规则。
- 时尚模式插件区的两个设置〔演进〕：
  - `dock.pluginSpacing`（默认 4 px，范围 0–24）：瓦片两侧的留白。
  - `dock.fusedPlugins`（默认关）：所有插件瓦片的底色合并成一条共享长条（`overlay("subtle")`），各瓦片自己的底色块隐藏，悬停态不变。
- 旧配置的 `bar.widgets.{left,center,right}` 由迁移复制为有序列表 `dock.plugins`（§6）。

### 3.2 带箭头弹出层与提示框（DockPopupWindow / TipsWidget）

凡是从任务栏项弹出的面板，都用这个形态：

- 形状：圆角矩形，`radiusPopup` = 6；箭头宽 18、高 10，指向触发项，箭头尖端距项边缘 2 px（`dockitem.cpp:64-71,441-456`）。
- 背景 `popupDark`，描边 `borderDark`，阴影见 §1.6。
- 与任务栏保持分离。Noctalia 的 `panelsAttachedToBar` 对这类面板不起作用。
- 内容宽度：200–320 px（声音 200、磁盘 300）。行高 36，左右内边距 10–20。
- 分区标题：白 × 0.6、字号 S。分隔线：1 px、白 × 0.1。滑块高 22。
- 点击外部或按 Esc 关闭。显隐用 `motionPopupIn` / `motionPopupOut`，沿箭头所在边位移〔演进：`dockpopupwindow.cpp:84-148` 原版算好位置后直接 show/hide，见 §1.7〕。
- 提示框：同样的形态，只放白色文字；宽 = 文字宽 + 6 × 字高；没有图标。
- 弹出层里的可选项清单（Wi-Fi 网络、蓝牙设备、音频输出/输入设备）按 §3.5.4「列表页」的规则做：整行可点，点击执行主操作（连接、设为当前设备）；当前项或已连接项用右侧 `accent` ✓ 和状态文字表示；次要操作（断开、忘记、详情）只在指针悬停的那一行或行内展开区里出现，不在每一行常驻同样的按钮〔演进：参照 GNOME 和 Windows 11 的网络列表；每行一个"连接"按钮会在列表上堆出一列重复的强调色文字〕。正在连接的行显示行内转圈。
- 内容高度超过屏幕可用高度的 2/3 时，弹出层封顶在这个高度，清单在内部滚动。
- 网络面板的连接详情卡片支持 grid/list 两种排布，右上角有切换按钮，分别持久化在 `network.wifiDetailsViewMode` 与 `network.ethernetDetailsViewMode`；以太网排布另在 设置 → 连接 页底部的以太网组里有下拉框（设置树里没有专门的以太网页）。

### 3.3 菜单（deepin-menu）

两种菜单：

**暗色带箭头菜单**（DDockMenu，用于任务栏项、托盘应用、启动器项）。来源：`deepin-menu/src/ddockmenu.cpp`、`dmenucontent.cpp`。

- 外框同 §3.2，箭头宽 18 × 高 10。
- 行高 = 字高 + 8（上下内边距各 4）。左右内边距 20。宽 = 最长文字 + 50，最大 500。
- 普通项：透明底、白字。悬停：整行填 `accent`，白字。禁用：`#646464`。
- 悬停块带 `radiusRow`（4）圆角〔演进：`dmenucontent.cpp:181` 原版用 `fillRect` 画直角。行已经缩在 `marginS` 内边距里，加圆角后与外框圆角相配，接近新版 DDE 的观感〕。
- 分隔行高 6 px，中间是一道"凹槽"：上一条 1 px `rgba(0,0,0,0.1)`、下一条 1 px `rgba(255,255,255,0.1)`，左右各缩进 4 px。
- 键盘：↑ / ↓ 移动，Enter 激活，Esc 关闭。
- 允许有勾选标记和子菜单箭头（DDE 有这些素材但没画出来）。用 12 px 的 Tabler 字形，放在右侧，颜色取所在行的文字色（普通态和悬停态都是白，禁用态为禁用色），不着 `accent`：菜单里 `accent` 只用在悬停行的底色上（§0 原则 3）。

**浅色菜单**（DDesktopMenu，用于桌面右键、任务栏设置菜单）〔派生自 DTK dstyle〕。

- 白 × 0.9 底，圆角 `radiusRow` = 4，阴影见 §1.6。
- 文字 `#303030`；悬停整行 `accent` 底、白字；禁用为黑 × 0.3。
- 有勾选和子菜单。在光标处弹出，超出屏幕时向内收。

### 3.4 启动器（dde-launcher）

由 `appLauncher.mode` 控制：`"fullscreen"`（默认，对应 schema 中 `fullscreen=true`）或 `"mini"`。

#### 3.4.1 全屏模式

- 覆盖整个屏幕。背景为模糊壁纸（§1.8）。点击空白处关闭；Esc 关闭；直接打字即开始搜索。
- 布局（`fullscreenframe.cpp`、`appsmanager.h:50-51`）：
  - 顶部留 30 px（任务栏在顶部时再加上任务栏高度），然后是搜索行。
  - 搜索行（`searchwidget.cpp:81-103`）从左到右依次为：左边距 30、分类切换按钮（22 px）、伸缩空白、搜索框（宽 290，水平居中，底色 `strong`，圆角 5，左右内边距 25 和 20，白字）、伸缩空白、切换到小窗口按钮、间距 30、设置按钮、间距 30、电源按钮（打开 §3.8）、右边距 30。按钮图片用原版多态素材（§1.9）。
  - 搜索行下方 20 px（`APPS_AREA_TOP_MARGIN`）是应用网格。网格左右各留 180 px（屏幕宽 ≤ 1366 时 130 px，`calculate_util.cpp:47-54`）；任务栏在底部时，网格底部留 60 px。
  - 启动器窗口覆盖整个屏幕（包括任务栏占用的区域），任务栏保持显示在启动器之上。
- 网格（`calculate_util.cpp:104-145`）：
  - 单元宽度预算：屏幕宽 ≤ 1440 时 170 px，否则 200 px；间距 10 / 14。列数 = (屏幕宽 − 2×左右留白) ÷ 宽度预算；实际单元边长 = (容器宽 − 间距 × 列数 × 2) ÷ 列数。单元是正方形，行高不随容器高度拉伸。
  - 图标边长 = 单元尺寸 × `appLauncher.iconRatio`（默认 0.5，范围 0.2–0.6，Ctrl+± 调整）。
  - 标签：12 px 白字，最多两行，超出用 `…` 截断，带投影（§1.5）。
  - 悬停或选中：黑色压暗块（`rgba(0,0,0,0.41)`），圆角 10。
  - 新安装的应用：标签左侧显示 10 px 的 `accent` 圆点。
- 两种显示方式（`display-mode`）：
  - `free`：所有应用平铺，纵向滚动（不分页）。
  - `category`：左侧分类导航栏（屏幕宽 > 1366 时 180 px，否则 130 px）。
    - 11 个分类：网络、社交、音乐、视频、图像、游戏、办公、阅读、编程、系统、其他。
    - 每个按钮高约 42，22 px 图标加文字。文字白 × 0.6 / 0.8（悬停）/ 1.0（选中）。悬停时整列放大到 1.2。
    - 右侧每个分类有一行标题（高 50），文字后面跟一条 1 px 的渐隐线，从白 × 0.3 渐变到透明。滚动时，当前分类的标题吸附在网格顶部。
- 滚动：`OutQuad` 动画，滚动条隐藏。
- 非应用类结果（计算器、剪贴板、表情、命令、窗口、会话、设置搜索）：在网格上方显示成分组列表，行样式同 §3.4.2，宽度与搜索框对齐，最大 600〔派生〕。剪贴板预览放在列表右侧的暗色卡片里。

#### 3.4.2 小窗口模式（mini）

- 尺寸：高 502，宽为左侧窗格 320 加右栏约 160（`windowedframe.cpp:158,169`）。
- 紧贴任务栏，间距 1 px。高效模式下贴在屏幕角落；时尚模式下与任务栏起始边对齐。
- 背景 `maskDark`。描边 `rgba(255,255,255,0.1)`。圆角 5；高效模式下只有贴近任务栏的那个角是 10。
- 左侧窗格，从上到下：
  1. 10 px 间距
  2. 搜索框（宽 290）
  3. 10 px 间距
  4. 1 px 分隔线
  5. 4 px 间距
  6. 应用列表（行高 36；图标 24 px 放在 x=10；文字从 x=48 开始，过长时右侧截断；悬停底色 `hover`，圆角 4，缩进 1 px）
  7. 全部应用与分类之间的切换按钮（悬停、选中底色 `hover`，圆角 4；按下时文字变为 `accent`）。在应用列表里显示"分类"加 20 px 的进入箭头；在分类视图（分类列表或某个分类内）显示"返回"。从全部应用点它进入分类列表，点某个分类进入该分类，点"返回"回到分类列表（`windowedframe.cpp` 的 `onSwitchBtnClicked`）
  8. 15 px 间距
- 右栏：
  - 左边缘一条 1 px 竖线（白 × 0.1）。
  - 顶部先留 30 px，然后是 60×60 的圆形头像（`avatar.cpp:42`），左对齐。
  - 中部：常用位置按钮（计算机、视频、音乐、图片、文档、下载），只有文字、没有图标（`miniframerightbar.cpp:61-67` 只传入 `tr("Computer")` 这类文本）；字号取基础字号（px）+ 2 与 14 px 中的较大者（`miniframebutton.cpp:43-48`）；悬停或键盘选中时显示选中底（白 × 0.1，圆角 4）。DDE 还有第 7 个 "Manual" 项，仅当系统装有 `dman` 时显示（`miniframerightbar.cpp:57`）；nosDshell 没有手册应用，不显示。
  - 底部：先是时间（40 px，白色，`datetimewidget.cpp:35`），下面一行日期；再下面横排"设置"和"电源"两个按钮，文字加左侧图标（原版 `settings.svg` / `power.svg`，`miniframerightbar.cpp:95-96`）。
  - 右上角：24×24 的全屏切换按钮，用原版 `fullscreen_{normal,hover,press}.png`。
  - 内边距 (18, 0, 12, 18)（`miniframerightbar.cpp:144`）。
- 列表里的分类项：文字白 × 0.6；选中时文字 `accent`，底色 `rgba(21,21,21,0.2)`，圆角 4。

#### 3.4.3 设置联动

启动器设置页（设置 → 启动器 → 通用）的每个控件都落在上面两种视图上：

- `appLauncher.mode`：在全屏和迷你之间切换。`LauncherState.setMode` 会把正在打开的视图直接切换过去。
- `appLauncher.displayMode`：`free`（默认，应用平铺滚动）或 `category`（左侧分类导航栏），对应 §3.4.1 的两种显示方式；全屏视图搜索行的分类按钮和 `launcher switchDisplayMode` IPC 写的是同一个键。
- `appLauncher.viewMode`：`grid`（默认）全屏浏览态用网格；`list` 浏览态改为列表（搜索态本来就是列表）。
- `appLauncher.density`：行高 30/36/44（×`ui.rowHeightScale`）、列表图标 20/24/28、全屏单元预算 ×0.85/1.0/1.15。
- `appLauncher.showCategories`：关闭后隐藏全屏模式的分类导航和模式切换按钮，以及迷你模式的"分类"按钮，provider 不再按分类过滤；`displayMode` 的取值保留。
- `appLauncher.iconRatio`：全屏网格的图标边长系数（0.2–0.6），入口是全屏视图内的 Ctrl+滚轮/±，设置页不开放（§6）。
- `appLauncher.showIconBackground`：图标后垫 `radiusRow` 底板。
- `appLauncher.iconMode`：provider 给出 Tabler 字形名时，列表项先查主题图标，找不到再用字形（`apps` 为最后的兜底）。
- `appLauncher.ignoreMouseInput`：视图内悬停、点击、滚轮全部关闭，键盘导航不受影响。
- `appLauncher.enableClipPreview`：全屏模式剪贴板预览卡片的开关。切换 `enableClipboardHistory` 会立即注册或注销剪贴板 provider。
- 启动器按钮图标组（与任务栏页共用一份实现 `Tabs/Shared/LauncherIconGroup.qml`）：`dock.launcherUseDistroLogo`、`dock.launcherIcon`、`dock.launcherIconColor` 与 `dock.launcherIconSize`。同一套键驱动高效模式任务栏启动器和时尚模式任务栏启动器项；高效模式右键启动器按钮走"启动器设置"落在本页，所以按钮图标的控件也在这里。尺寸滑条两种模式都显示：像素值作用于启动器*项*（高效任务栏 glyph 与时尚任务栏启动器块），`0`/重置 = 自动按模式推导（高效 16px，时尚随 `dock.iconSize`）；时尚状态栏胶囊不读该键，其图标始终按固定胶囊高度的比例推导。
- Noctalia 原有的 `appLauncher.position` 和 `overviewLayer` 属于 SmartPanel/overlay 前端，已随该前端一起移除（登记见 §6.1）。启动器只有本节这一套 DDE 实现。

### 3.5 控制中心（dde-control-center）

来源：`gxde-control-center/src/frame/*`。

#### 3.5.1 外框

- 宽 408 px，高度占满屏幕，贴住屏幕右边（`frame.h:53`、`frame.cpp:517-523`），直角。阴影见 §1.6。
- 背景 `maskDark`。从右侧滑入，`motionEnter`（300 ms OutCubic）。
- 外框左侧只有共享的 dimmer 压暗（`general.dimmerOpacity`，默认 0.35〔演进〕）。透过全屏透明层看到的窗口是正常的桌面内容，不再另加遮罩。
- 压暗只对占据屏幕的帧类面板生效（控制中心、设置、启动器等）。dock 弹出的小面板（音量、网络、蓝牙、亮度、电池、时钟、媒体、系统监控、托盘抽屉、壁纸、插件槽）设置 `SmartPanel.dimsBackground = false`，打开时不压暗壁纸〔演进：DDE 原版的弹层本来就叠在没有 dimmer 的桌面上〕。
- 点击外部关闭；按 Esc 时，如果在子页面就先返回上一级，否则关闭。
- 控制中心永远在右侧；任务栏在右侧时，控制中心排在任务栏内侧（`controlCenter.position` 的移除登记见 §6.1）。

#### 3.5.2 首页

从上到下（`mainwidget.cpp`）：

1. **头部**，高 140，内边距 (40, 0, 0, 10)。
   - 左上：头像（圆形）。
   - 时钟：46 px，Light，白色，`HH:mm`。
   - 日期：长日期格式（`Time.formatLongDate`，跟随界面语言，§1.5），白色。
   - 右侧：铃铛按钮（32×32，可切换），用于在"通知首页"和"所有设置页（模块网格）"之间切换；旁边的齿轮按钮同样进入所有设置页。
2. **更新提示条**（有更新时出现）：底色 `idle`，悬停 `hover`。
3. **中部**，可滚动，有两个页面，由铃铛切换〔演进：默认页改成通知优先〕：
   - **通知页**（默认页）：勿扰开关行 + 通知历史列表。开关行标题是"勿扰模式"（§1.10），开启时铃铛图标换成 `bell-off` 并着 `accent`。列表视口占满中部剩余高度，**内容顶对齐**：通知从列表头顶端向下堆叠，空余视口收在末尾之后〔演进：曾用贴底对齐让通知贴着快捷控制条堆叠，但条高变化（分页、收起）会带动整块通知上下挪动；置顶让通知块的位置与底部控件完全解耦，也与 macOS/Windows 通知从固定锚点生长的惯例一致〕。
     - **列表头**：列表内容的第一行，左侧"通知"（白 × 0.6、字号 S），右侧"清除历史记录"文字按钮（底色 `idle`，悬停 `hover`，内边距 4，`radiusRow`）。它属于列表内容，随内容一起顶对齐，始终紧挨第一条通知。没有通知时隐藏。
     - **日期分段**：按通知时间分成"今天""昨天""更早"三段，每段前一行分段标题（白 × 0.6、字号 XS、行高 24）。只有一段时也显示标题〔演进：取代上游的时间筛选。上游有一排可见的筛选页签；页签在 DDE 化时删掉了，Tab 键却还在切换筛选，界面上看不出当前筛的是哪一段〕。
     - **按应用分组**〔演进：DDE 15 是平铺列表；macOS、Windows 11 和 GNOME 48 都把同一应用的通知叠成一组〕：同一段里同一应用的通知归为一组。组按组内最新一条的时间排序，组内按时间倒序。只有一条的组就是一条普通通知。多条的组默认折叠，只显示最新一条，卡片下方露出两道错开的底边（每道比上一道左右各缩进 8 px、高 4 px、底色 `overlay("hover")`、`radiusItem`），卡片元信息行显示"还有 N 条"。点击底边、"还有 N 条"或用键盘 Enter 展开；展开后组顶部出现组头：应用名、"收起"文字按钮、清除本组的 × 按钮。展开和收起是数据驱动的尺寸变化，用 `motionPanel`。
     - **每条通知**是浅色气泡的暗色版本：白字，底色 `strong`，圆角 5。元信息行是应用名和相对时间。
       - 点击正文执行通知的默认动作（`default`）；没有默认动作或执行失败时，聚焦发送方的窗口（`NotificationService.focusSenderWindow`）。两种情况都随后关闭控制中心（上游 `a08ff3619:Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml:795-806`）。
       - 正文或标题被截断时，右上角显示展开按钮（`chevron-down` / `chevron-up`）；展开后显示全文，正文里的链接可点。悬停时右上角另显示删除 ×。
       - 向左或向右拖动卡片超过上游阈值后松手即删除，不到阈值回弹（上游 swipe-dismiss）。删除时沿拖动方向滑出，`motionPanel`。
       - 动作按钮：`accentAlt` 文字按钮，悬停 `hover` 底，`radiusRow`。
     - **键盘**：↑ / ↓ 在列表项之间移动（折叠的组算一项），← / → 在动作之间移动，Enter 执行当前动作，没有选中动作时展开折叠组或执行默认动作，Delete 删除当前通知。当前项画 1 px `accent` 描边。
     - 列表为空时"无通知"居中显示在空余视口里。
   - **所有设置页**：模块网格，是设置的入口页（类似 Windows 控制面板）。网格 3 列，每个格子缩进 5、圆角 5，默认 `idle`、悬停 `hover`；格子里是 24 px 图标加文字。头部齿轮、启动器里的设置入口和 `settings open/toggle` IPC 都落在这里；铃铛切换回通知页。
4. **快捷控制面板**（底部，`quick_control/*`），只属于通知首页，所有设置页和模块视图打开时隐藏。分页显示，用分页指示器切换（高 40；当前页的圆点为 `onShell` × 0.8，其余为 × 0.3，所以在深色外框上是白色，在浅色外框上自动变深）。分页条右下角有一枚收起 chevron（展开时 ⌄、收起时 ⌃），点击把整条收成一行指示器带高，腾出的高度全部还给通知列表；按钮锚在底边右角，收起和展开是同一个屏幕坐标〔演进：原方案是顶部居中把手，收起后按钮位置会变〕。每页按自己的内容定高，翻页时面板高度用 `motionPanel` 动画过渡，不留统一槽高带来的空白〔演进：原方案所有页共用 `quickControlPanelHeight`〕。**页面顺序由 `controlCenter.quickPageOrder` 决定**（默认 卡片 → 基础 → Wi-Fi → 蓝牙 → VPN），在设置 → 控制中心 → 页面里拖拽调整〔演进〕。分页以页 id 为准，正在看的页被重排时跟随自己的位置而不是悄悄换成同索引的另一页；某页内容被卡片开关全部关掉、或服务不可用时直接从分页条里消失（蓝牙页需 `BluetoothService.bluetoothAvailable`，VPN 页需有连接），重新出现时回到存储的位次：
   - **卡片页**（默认第一页）：已启用的 Noctalia 卡片（天气、媒体+系统监控），每张底色 `idle`、圆角 5；页高 = 已启用卡片的实际内容高（天气卡按数据收缩、媒体/监控行 `controlCenterMediaCardRowHeight` = 160·s）+ 上下留白〔演进：首页默认控件收进分页条〕。模型在交给 Repeater 前先过滤到本页实际渲染且已启用的条目：`controlCenter.cards` 里 profile/shortcuts/audio/brightness 的条目对应的是已重新分配的功能（见下方对应表，它们的 enabled 各自门控头部之外的区域、并被 OSD 抑制逻辑读取），不属于本页，不过滤会产生占布局槽位的空 Loader；关掉的条目连 Loader 都不建。媒体+系统监控卡里的系统监控表盘显示哪些指标由 `controlCenter.sysmonMetrics` 决定（cpu/temp/mem/disk 的子集，默认前三项），在设置 → 控制中心 → 卡片的卡片开关组下方配置；该卡关闭时整组隐藏，磁盘路径下拉只在磁盘指标开启时出现〔演进〕。没有播放器时媒体卡在占位封面下方写"没有正在播放的媒体"（白 × 0.6、字号 S），不只留一张灰色唱片图（§1.10 空状态）。
   - **基础页**：音量和亮度两条滑块（两端各有 24 px 图标），下面两排快捷开关。三段分别由 `audio-card` / `brightness-card` / `shortcuts-card` 开关门控，关掉即从页上消失（不再渲染，不留空槽）；亮度滑条还要求硬件存在。三段全关时整页从分页条消失。
   - **快捷开关**：每个 70×72，每行 5 个共两行，一页最多显示 10 个，`controlCenter.shortcuts` 的 left++right 合并后截前 10 个，超出的不再放进溢出页〔演进：溢出页删除，要显示哪些开关、什么顺序在设置 → 控制中心里配〕。图标在上、名称在下〔演进：DDE 原版 70×60 只有图标，名称靠提示框；GNOME、macOS 和 Windows 11 的快捷设置都直接写出名称，图标含义不明的开关（性能模式、电源模式）不用悬停就能认出〕：图标 24 px，底边距格子底部 32；名称一行，字号 XS，白 × 0.8（开启时白），水平居中，左右各留 4 px，超出用 … 截断，底边距格子底部 12。名称取注册表的显示名，与设置 → 控制中心里快捷开关列表的叫法一致；提示框仍显示挂件给出的动态说明（例如当前连接的网络名）。开启时，背后画一块白 × 0.2 的底，圆角 6，下边距 5。悬停底色和开启底色的切换按按钮类处理（`motionPointer`）。
   - **Wi-Fi 页、蓝牙页、VPN 页**：列表行高 36，样式同 §3.5.4；页高贴内容、超出 `quickControlPanelHeight` 时滚动，空列表给一行提示〔演进：显示页删除，它的亮度滑块与基础页重复、夜间模式本就是快捷开关，同一组件不在两页出现〕。

Noctalia 卡片的对应关系：

| Noctalia 卡片 | 控制中心位置 |
|---|---|
| ProfileCard | 头部（required，恒开） |
| ShortcutsCard | 快捷开关（`shortcuts-card` 开关控制基础页开关格显隐） |
| AudioCard、BrightnessCard | 快捷控制面板的基础页（`audio-card`/`brightness-card` 分别门控音量、亮度滑条） |
| WeatherCard、MediaCard、SystemMonitorCard、CalendarCards | 快捷控制面板的卡片页（默认第一页）；SystemMonitorCard 显示哪些指标由 `controlCenter.sysmonMetrics` 配置 |

#### 3.5.3 设置页（原 Settings 面板）

- DDE 15 的设置页是一整页"所有设置"（`settingswidget.cpp:90`），所有模块按顺序纵向排在同一个滚动区里，每个模块以"模块头"开头。从所有设置页的模块网格点某个模块进来，等于打开"所有设置"并滚动到该模块；返回回到模块网格〔演进〕。
- 进入模块视图后，控制中心外框不动，头部（头像、时钟）和底部快捷控制面板都隐藏，整个外框高度只留给两栏（`frame.cpp:127-137`，参照 `references/1.jpg`）：
  - **左栏**：56 px 宽的导航条（`frame.h:54`）。按钮整体垂直居中（上下各一段伸缩空白），按钮间距 20（`navigationbar.cpp:102-110`）。每个按钮左右外边距 10、上下内边距 5、圆角 4；悬停底色白 × 0.2，选中白 × 0.3（`dark.qss` `NavigationBar DImageButton`）。图标用原版 24 px 的 `nav_<模块>_normal.svg`（默认）和 `nav_<模块>.svg`（选中）（§1.9）。上游没有的扩展模块（任务栏、启动器、控制中心、通知、桌面挂件、系统监视、插件、高级）用 `Assets/Nav/` 下同规格的自绘素材（24 px、白色、默认态内嵌 0.2 透明度），不混用其他图标族。悬停时向左弹出暗色箭头提示框（Wayland 下底色黑 × 0.8，`navigationbar.cpp:96-99`）。
  - **右栏**：内容区，宽 352。
- 导航与滚动联动：
  - 点导航按钮时，内容区平滑滚动到该模块头，`OutQuint` 1400 ms（`contentwidget.cpp:51,106-112`）。
  - 滚动过程中导航选中项实时跟随视口中第一个顶部可见的模块（`settingswidget.cpp:342-380`；〔演进〕上游按滚动停下再更新，这里逐帧同步，选中项拖动到哪高亮到哪；当前模块在视口内仍相交时保持选中，避免来回抖动）。
- 模块头（`modulewidget.cpp`）：左边距 11，24×24 的模块图标（与导航选中态同一个 `nav_<模块>.svg`），接大号标题（LargeLabel，白色），上下内边距 5（`modulewidgetheader.cpp`）。模块之间留 1 个分组间距。
- 内容区顶部：返回按钮（24×24 圆角 4 的方块，底色白 × 0.2），居中标题"所有设置"（14 px / 500），再下面 15 px 是一条分隔线。内容可滚动，滚动条隐藏。
- 二级页（"下一页"行进入，`NNextPageRow` → `SettingsModuleView.pushPage`）：新页面从右侧推入，旧页面向左推出，`motionPanel`（300 ms InOutCubic）；位移过程中按距离同步淡出。二级页的标题换成该页名称，返回按钮回到上一级。进入方式、转场和返回在所有页面统一，不允许在行内展开大段内容作为替代。
- 性能：一次展开所有模块代价较大，允许按顺序异步加载（`Loader.asynchronous`）。先加载目标模块和它前后各一个，其余在空闲时补齐。未加载的模块用估计高度占位，加载完成后当前目标模块的头部位置保持不动。
- 模块顺序与对应（DDE 原有顺序见 `navigationbar.cpp:39-85`）：

| DDE 模块 | 承载的 Noctalia 设置 Tab |
|---|---|
| 账户 accounts | General（头像、用户名） |
| 显示 display | Display（亮度、夜灯） |
| 个性化 personalization | ColorScheme、Wallpaper、UserInterface |
| 任务栏 dock | Dock，分常规、状态栏、显示器、插件四个子页〔演进：常规页合并了原"外观"页，状态栏页收进了原来放在常规页底部的状态栏开关组〕。常规页先是 `dock.enabled` 开关，下面依次是模式、位置、大小、状态，然后是外观和窗口分组。状态栏页先是 `bar.enabled` 开关和状态栏自己的位置、显示、形态、密度、字体、显示器，挂件配置由"下一页"行推入二级页，下面是任何模式下都作用于当前 Bar 的外观、行为和自动隐藏设置；状态栏空白处的右键动作只在状态栏启用时出现，高效模式右键是固定的任务栏设置菜单。插件子页随模式换形态：高效模式是任务栏部件的左/中/右三区编辑器（左中编辑 `dock.taskbarWidgets`，右区编辑 `dock.plugins`），时尚模式是 `dock.plugins` 的扁平有序编辑器。原 Noctalia 的 `bar.*`、`dock.*` 细节设置（透明度、间距、分组、点击动作等）都按配置对象收在这里〔演进：不集中放在"高级"，见下方归位原则〕 |
| 启动器 launcher | Launcher |
| 控制中心 | ControlCenter |
| 网络 network | Connections / Wi-Fi |
| 蓝牙 bluetooth | Connections / Bluetooth |
| 声音 sound | Audio、Osd |
| 通知 notifications | Notifications |
| 时间日期 datetime | Region（语言、位置、天气） |
| 电源 power | Idle、SessionMenu、LockScreen |
| 键盘 keyboard | General / Keybinds |
| 桌面挂件 | DesktopWidgets |
| 系统监控 | SystemMonitor |
| 插件 | Plugins |
| 高级 | Hooks。只放在任何 DDE 模块里都没有归属的设置；曾经放在这里的 dock、bar 细节和面板圆角已按配置对象移到任务栏和个性化〔演进〕 |
| 系统信息 systeminfo | About |

- **设置项归位原则**〔演进〕：新设置项放进它所配置的对象对应的模块。dock 和 bar 的外观与行为放在任务栏；面板、圆角、阴影、动画这类 shell 全局观感放在个性化；按显示器的覆盖设置放在任务栏的显示器子页。DDE 没有对应开关不是放进高级的理由，高级只放完全没有归属的设置（目前只有 Hooks）。
- **设置分组与可见性原则**〔演进〕：
  - 页内先放功能开关，紧接着放这个功能的配置。开关和它的配置放在同一个子页、同一个分组里。
  - 功能关闭时，它的全部配置项隐藏（用 `visible`，不用 `enabled` 置灰）。整页都失效时，连子页签一起隐藏，例如任务栏页的显示器和插件子页随 `dock.enabled` 隐藏。
  - 只在某种模式或状态下有意义的设置随条件自动隐藏。时尚模式专属项绑定 `dock.mode === "fashion"`；高效模式下 Bar 就是任务栏本身，状态栏开关组整块隐藏。文案里不标注"（时尚模式）"，能否看到就说明了适用范围。
- 原来的子 Tab 不再用横向标签栏，改为分组（SettingsGroup，每组带组标题）。内容较多的子页，用"下一页"行（NextPageWidget）进入二级页。
- 设置页只在控制中心外框里显示。`ui.settingsPanelMode` 是兼容数据，迁移把它固定为 `"controlCenter"`（§6）。

#### 3.5.4 设置项控件（dcc::widgets）

- **SettingsGroup**：一组行纵向排列，行与行之间留 1 px 缝隙（透出下面的蒙版，形成分隔效果）。整组外缘：第一行上方两角、最后一行下方两角为圆角 5。
- **SettingsItem**：行底色 `strong`（`rgba(238,238,238,0.2)`）。可交互的行悬停时为 `checked`（0.3）。出错时画 2 px 的 `alert` 色描边。
- **SettingsHead**：高 24，左右内边距 (20, 10)。标题 DemiBold、白色。右侧可放"编辑"文字按钮（`accentAlt`）。
- **标准行**：高 36，左右内边距 (20, 10)。
  - 下一页行：标题，右侧是数值（白 × 0.8），再右侧是一个 `›` 箭头。
  - 开关行：标题，右侧是开关。
- **开关**（DSwitchButton）〔派生自 DTK〕：外形 40×22 的胶囊（开关是唯一允许用胶囊形的控件）。关闭时底色白 × 0.2；开启时底色 `accent`；滑块为白色圆点，直径 18。切换动画 150 ms。
- **滑块**（DSlider）：
  - 整个控件高 35，滑槽只有 2 px，已填充部分为 `accent`，未填充部分为白 × 0.2。
  - 滑块按钮是 12 px 的白色圆点〔派生〕，带 1 px `knobBorder` 描边。所有场景（设置页、控制中心、弹出层）同一尺寸，不随滑块高度缩放。按钮背后不画挖空底盘：Noctalia 的 cutout 是一块不透明的 `mSurface` 圆，在半透明面上显成按钮外的一圈黑环，也违反本节的「表面令牌边界」。
  - 数值读数（滑块旁或标题行的百分比）用 §1.5 的等宽数字，白 × 0.8。
  - 下方可加刻度注释（`DCCSliderAnnotated`），文字白 × 0.6。
- **控件列宽**〔派生〕：设置行右侧的下拉框、可搜索下拉框、数值框和单行文本输入，宽度固定为 `settingsFieldWidth`（170 × 缩放），最小、首选、最大宽度相同。同一页各行的控件左右边缘因此对齐；标题和描述在剩余宽度里换行，不去挤压控件。
- **文本输入**：高 30〔派生〕，底色 `field`，圆角 5，白字。获得焦点时画 1 px `accent` 描边；出错时描边为 `alert`。没有内容时显示占位文字（白 × 0.6），搜索框的占位文字写明搜什么（"搜索设置"）。
- **下拉框**：外观同文本输入，右侧有 ▾。弹出的列表用暗色菜单（§3.3），不带箭头，带 §1.6 的 `shadowPopup` 投影。设置页上的弹层底色用不透明的 `mSurfaceVariant`，因为设置页本身不透明，`popupShell` 为模糊外壳设计的半透明会让页面文字透上来。只有弹层落在半透明外壳上时（例如壁纸条的来源下拉框，`onShellSurface`），才沿用 `popupShell` 的玻璃效果。弹层列表不为滚动条预留槽位（`reserveScrollbarSpace: false`，滑块直接叠在右缘上），但内容超高时滑块常驻显示（`showScrollbarWhenScrollable`），保证隐藏的项有"还有更多"的可见提示。
- **按钮**（DDE 的 RoundedButton 样式）：
  - 圆角 15 的胶囊（这是第二处允许胶囊形的地方），底色白 × 0.2。悬停白 × 0.5，按下 `accent`。
  - 推荐操作按钮：文字为 `accent`。
- **单选 / 复选**（OptionItem）：整行可点，选中时右侧显示 `accent` 色的 ✓。DDE 不使用圆形单选框。
- **分隔线**：1 px，前景 × 0.15（`separator` 令牌）。
- **行高系数**〔演进〕：行高类令牌（`detailRowHeight`、`settingsRowHeight`、`launcherMiniRowHeight`、`dialogButtonHeight`、`sliderBasicHeight`、`settingsFieldHeight`）整体乘以 `ui.rowHeightScale`（0.9–1.2，默认 1）。写死行高的组件不会跟着缩放，所以行高一律读令牌。
- **表面令牌边界**：设置页里的行、列表和嵌板一律用叠加阶梯（`overlay`）或蒙版（`maskShell`）。配色方案只经由令牌层影响组件。组件不直接用 `mSurface`、`mSurfaceVariant`、`mOutline` 这类 Material 颜色填充行或卡片：方案颜色是不透明的（要供 GTK 和终端模板使用），绕过令牌的透明度处理后会在玻璃面上变成实心色块。`m*` 颜色只在两处直接使用：配色方案预览这类"内容本身就是颜色"的展示，以及徽章、状态点的语义色。
- **列表页**（Wi-Fi 网络、蓝牙设备、插件、配色模板这类可选多项的清单）：每一项是一个 SettingsItem 行。选中或已连接用右侧的 `accent` ✓ 和状态文字表示，整行底色不变。进行中的操作用行内转圈表示。行内展开区（密码、详情）用 `overlay("field")` 加 `radiusItem` 的嵌板。列表末尾接一个可点击的"添加"或"新建"行。
- **堆叠子页**：`NTabView.stacked` 时，每个子页是一个 NHeader 加一个 SettingsGroup。组头与它的组之间只有 1 px 缝，组与组之间 15 px。间距全部放在上一组末行与下一组头之间，组头与组之间不再额外留白。
- **成块的内容不折叠进行内**：设置页不用"点行展开/收起"的形式藏内容，行内不出现控制整段内容显隐的 chevron 行。内容较多时按 §3.5.3 用"下一页"行（`NNextPageRow`）推入二级页；其余情况直接常显。唯一的例外是 §3.5.4 列表页的行内展开区（密码、详情），那是列表项自身的展开行为，不折叠整组内容。
- **控件必须对齐当前呈现形态**：挂件/插件的设置页只显示当前呈现形态实际消费的控件；形态下没有消费方的控件隐藏而非置灰，键值保留（切回该形态或旧配置上它仍生效）。例：`Workspace` 的分组应用视图在高效模式没有消费方，其相关控件只在高效模式下隐藏（`WorkspaceSettings.qml` 的 `groupedUnsupported` 与 `Workspace.qml` 的 `showApplications` 钳制同一公式）。

### 3.6 通知气泡（dde-osd notification）

来源：`gxde-session-ui/dde-osd/notification/*`。

- **表面**：背景 `maskTransient`（默认 auto 跟随模式，规格见 §1.2；`light` 形态下为不透明 `#F8F8F8`），描边 `borderTransient`，圆角 8，阴影见 §1.6。
- 尺寸：基准 300×70。正文较长时允许增高，但最多显示 3 行。
- 位置：屏幕右上角，距离屏幕边缘 20 px（DDE 15 原版行为，见 `bubblemanager.cpp` 的 `getY()`）。
  - 任务栏在顶部时，气泡排在任务栏下方；控制中心打开时，气泡排在控制中心左侧。
  - `notifications.location` 仍然可以修改，GXDE 默认的右下角是可选项之一。
- 布局：
  - 应用图标 48×48，距左边 11，在气泡内垂直居中。DDE 气泡固定高 70，图标放在 (11, 11) 正好居中（`bubble.cpp:470-471`）；这里气泡会随正文增高，所以保持居中而不是钉在顶边 11〔演进〕。
  - 正文从 x=70 开始，宽 220；有动作按钮时宽 150。
  - 标题 `onTransient`、Medium；正文 `onTransientBody`；超出按行截断。
- 动作按钮：竖排在右侧，宽 70。文字用 `transientAction`（浅色面上就是 `accentAction`）；悬停时变为白字，底色是原来的按钮文字色。按钮之间用 1 px `overlayTransient("hover")` 分隔线。
- 动效：出现用 `motionBubbleIn`，消失用 `motionBubbleOut`（向右滑出）。
- 时长：普通通知 5000 ms；低优先级沿用 Noctalia 设置；紧急通知不自动消失。
- 堆叠：默认同一时刻只显示一条，其余排队（DDE 行为）。`notifications.maxVisible`（默认 1）可以调大，调大后多条气泡纵向堆叠，间距 10。
- 如果新通知的 `replacesId` 与已有通知相同，就原地更新那条气泡的内容。
- 吐司（Toast）：同样的气泡，没有动作按钮，高度随内容，显示在屏幕上方居中〔派生〕。

### 3.7 OSD（dde-osd）

来源：`gxde-session-ui/dde-osd/container.cpp`、`common.cpp`。

- **方块**：背景 `maskTransient`（默认 auto 跟随模式，规格见 §1.2；`light` 形态下为不透明 `#F8F8F8`），圆角 10，阴影见 §1.6，描边 `borderTransient`。
- 尺寸 140×140。
- 位置：水平居中，方块底边距离屏幕底边 180 px。`osd.location` 仍然可以修改，默认值改为 `"bottom_center"`。
- 内容：
  - 图标居中：只有图标时距顶 40，下面有文字时距顶 25，下面有进度条时距顶 30。图标着 `onTransient`（`light` 形态下为深色），字号 `osdIconSize`（48 pt，墨迹量约等于原版 64 px 的 SVG，`icons/OSD_*.svg`）。
  - 进度条：80×4，距顶 110，圆角 2。滑槽 `onTransientTrack`，已填充部分 `onTransient` 实色。
  - 音量超过 100% 时，在滑槽 2/3 处画两条 1×5 的刻度线（`onTransientTick`）。
- 键盘布局 OSD：竖向列表，宽度为文字宽与 200 中的较大者再加 30，行高为字高加 10，当前行底色 `overlayTransient("hover")`。
- 锁定键 OSD（大写锁定、数字锁定）：只显示图标和文字。
- 出现和消失用 `motionOsdIn` 和 `motionOsdOut`。显示 1000 ms（`osd.autoHideMs` 默认值改为 1000）。

### 3.8 关机界面（dde-shutdown）

来源：`gxde-session-ui/dde-shutdown/*`、`widgets/rounditembutton.cpp`。

- 覆盖整个屏幕，背景为模糊壁纸。
- 按钮横排一行，垂直居中，按钮间距 10。按钮顺序为关机、重启、待机、休眠、锁定、切换用户、注销，另加 Noctalia 独有的"重启到 UEFI"。实际显示哪些按钮、按什么顺序，由 `sessionMenu.powerOptions` 决定。
- 每个按钮（RoundItemButton）：
  - 尺寸 140×140。图标 75×75，图标下方 10 px 是文字（白色，可换行）。
  - 悬停或选中：黑色压暗块，圆角 10。不可用时整体透明度 0.5。
- 打开时默认选中"锁定"。
- 键盘：左右方向键移动选中，Enter 执行，Esc 取消。保留 Noctalia 的数字快捷键（1–7），数字显示在按钮文字后面，颜色白 × 0.6。
- 点击空白处取消。
- 倒计时（`sessionMenu.enableCountdown`）：在按钮行下方 40 px 处显示一行白色文字，例如"将在 N 秒后关机"。按任意键取消倒计时。
- 有程序阻止关机（inhibitor）时，按钮行换成警告视图，列出程序名和原因，下面是"仍然关机"（`accent` 文字）和"取消"两个按钮。
- Noctalia 原有的会话菜单布局选项在 DDE 布局下没有对应物（移除登记见 §6.1）。

### 3.9 锁屏（dde-lock）

来源：`gxde-session-ui/dde-lock/*`、`session-widgets/*`、`widgets/*`。

- 背景：模糊壁纸（`general.lockScreenBlur` 默认改为启用）。
- 窗口底部有一条高 132 的区域，上下各留 33 px 边距：
  - 左下：时间，68 px，Light，白色，左对齐，左边距 48。时间下方是日期，16 px，格式 `yyyy-MM-dd dddd`。
  - 右下：一排控制按钮，间距 26，右侧留 60：
    - 媒体控制（MPRIS，可选）
    - 键盘布局
    - 切换用户
    - 电源。电源按钮会在锁屏内打开 §3.8 的按钮行；此时密码区隐藏。
    - 按钮底色走壁纸面恒白叠加阶梯：常态 `overlayWallpaper("field")`，悬停 `strong`，按下 `checked`；图标前景 `onWallpaper`〔演进：原为白色字面量 0.12/0.2/0.3，0.12 一档在 §1.3 阶梯中无对应级别，归档到 field（`gxde-session-ui/widgets/skin/layoutbutton.qss:7` 的 hover 即 0.15）〕。
- 中央，从上到下：
  - 头像：100 px 圆形，无描边。
  - 用户名：16 px 白字，在头像下方 25 px。
  - 用户名下方 20 px 是密码框：280×36，底色 `field`，圆角 6，白字，右侧嵌着解锁图标按钮。
  - 这一整块在屏幕高度减去 132 px 底部区域后的剩余空间里垂直居中。
- 密码错误：密码框描边变为 1 px `alert`；框下方弹出一个白底提示（文字 `alert`），并带一个指向密码框的箭头。
- 大写锁定开启时，密码框内左侧显示一个提示图标。
- 认证进行中：在密码框内显示一个白 × 0.35 的加载动画。
- 指纹（`allowPasswordWithFprintd`）：密码框里的占位文字显示"验证指纹或输入密码"。
- Noctalia 锁屏上的天气、电池、倒计时等附加信息，以白 × 0.8 的小号文字放在时钟右侧，默认关闭。
- Noctalia 的紧凑锁屏布局在 DDE 中没有对应物（移除登记见 §6.1）。

### 3.10 壁纸选择〔派生〕

- 参考仓库中没有 dde-desktop 的壁纸选择器，以下按 DDE 15 的总体规则设计。
- 一条贴住屏幕底边的横条，背景 `maskDark`，高约 160。
- 缩略图 16:9、宽 160，间距 10，横向滚动。
  - 滚动有三条路：纵向滚轮与触摸板横滚都映射到 `contentX`（`animationFast` 过渡）；条两端各叠一枚圆形翻页按钮（`chevron-left/right`，`overlay("field")` 底 + `borderShell` 描边，悬停 `hover` 洗色），只在对应方向还有内容时出现，点击滚动近一屏宽并留下首尾缩略图作参照；直接拖动仍然可用。
  - 当前壁纸：外圈 2 px `accent` 描边。
  - 悬停的缩略图：底缘内叠出"浅色""深色""两者"三个按钮（胶囊形与尺寸同 §3.5.4，但配色走 §1.5 的壁纸令牌：`veilWallpaper`×0.6 底（悬停 0.8）+ `onWallpaper` 字，因为照片是任意底色，随主题的 `overlay`/`onShell` 在亮色壁纸上会洗没），分别写入亮、暗、两个外观槽位。按钮按固定槽位标注而不是"当前/另一外观"，免得读者先回忆当前是哪种模式；悬停才出现的行不占条带高度（放进缩略图下方会被 `clip` 截断）。原版的三个按钮是"仅桌面""仅锁屏""都设置"。本 shell 没有单独的锁屏壁纸：`LockScreenBackground` 复用桌面壁纸的预模糊缓存，`WallpaperService.changeWallpaper` 只区分 `"light"` 和 `"dark"` 两个外观（`WallpaperService.qml:422-424`），所以三个按钮对应亮、暗两个外观，结构与原版一致。以后加入单独的锁屏壁纸时，再改回原版的三个按钮。
- 顶部一行（目录、Wallhaven 来源、搜索）按 §3.5.4 的控件样式绘制。
  - 右侧的调色盘按钮打开取色器，选色后走 `WallpaperService.setSolidColor` 切换到纯色壁纸（`wallpaper.solidColor` + `useSolidColor`）；纯色生效时按钮按选中态着色。
- 本地缩略图左上角有收藏星标：悬停或已收藏时可见，点击走 `WallpaperService.toggleFavorite`；收藏项排在列表最前（上游 `a08ff3619` 的同名行为）。Wallhaven 项不显示星标，其 path 是远程缩略图 URL，不是本地壁纸。

### 3.11 对话框（DDialog）

- 暗色：背景 `maskDark`，圆角 8，阴影见 §1.6。
- 宽 380（polkit 对话框的最大宽度，`AuthDialog.cpp:277`），内容多时最大 640。
- 左上 48 px 图标，标题 Medium，正文白 × 0.8。
- 底部按钮行横跨对话框全宽，按钮之间用 1 px 白 × 0.1 的分隔线隔开；推荐操作按钮的文字为 `accent`。
- 首次设置向导：模糊壁纸背景，中间是上述对话框（宽 640），底部用分页圆点表示步骤，右下角是"下一步"按钮。
- Polkit 认证对话框（`Services/Polkit/PolkitService.qml` + `Modules/Polkit/PolkitAuthDialog.qml`）：shell 启动即注册 `PolkitAgent`，认证请求弹出 overlay 对话框。按 `gxde-polkit-agent/AuthDialog.cpp` 实现：48 px 应用图标、有多个身份时显示身份下拉框（`Identity.displayName`）、高 24 的密码框、transient 单元名（`run-PID-*.service`）解析为真实命令；密码错误时输入框显示 `alert` 状态并在其下方给出错误提示（开始输入即消除），服务器未给补充错误时回退到 `authentication.wrong-password`。底部按钮行为全宽条带：取消/确认之间 1 px 分隔线，确认的推荐文字为 `accent`。

### 3.12 桌面挂件

- DDE 15 没有桌面挂件，这里按 DDE 的通用规则处理：卡片背景 `maskDark`，圆角 8，不加阴影。文字规格同 §1.5。
- 时钟挂件采用控制中心时钟的样式（46 px Light）。
- 拖拽时只用白 × 0.1 的描边表示可放置区域，不加发光效果。

### 3.13 状态栏〔nosd 扩展〕

- DDE 15 本身没有状态栏。这是借 Noctalia 的 bar 管线提供的可选扩展，定位类似 macOS 的菜单栏：显示系统信息和全局挂件，不显示窗口任务列表。
- 只在时尚模式下可用。高效模式下任务栏本身就是通栏，状态栏不出现；切换模式时自动隐藏或恢复，用户不用重新设置。
- 开关是 `bar.enabled`（默认关）。位置是 `bar.position`（默认 `top`），与 `dock.position` 相互独立。显示在哪些显示器上由 `bar.monitors` 决定（留空表示全部）。显示模式是 `bar.displayMode`（`always_visible`、`non_exclusive`、`auto_hide`，沿用 `bar.autoHideDelay`、`bar.autoShowDelay`、`bar.showOnWorkspaceSwitch`）。
- 形态是 `bar.barType`（默认 `simple`；`framed` 加 `frameThickness`/`frameRadius` 的框体）。`bar.floating`（默认关）是独立修饰：让整个栏面四边离开屏幕边缘，外边距是 `marginVertical`/`marginHorizontal`，`simple` 和 `framed` 均可叠加（旧配置里的 `barType: "floating"` 由迁移 v81 转成 `barType: "simple"` + `floating: true`）。外圆角 `bar.outerCorners` 只在非悬浮的 `simple` 下生效。§7 的栏体兼容形态只对状态栏开放。
- 空白处右键执行 `bar.rightClickAction`（默认 `controlCenter`，另有 `settings`、`launcherPanel`、`command`；`command` 用 `bar.rightClickCommand`，`bar.rightClickFollowMouse` 控制弹出面板是否跟随光标）。
- 挂件内容用 `bar.widgets` 的左、中、右三段布局。默认左侧是启动器、时钟、系统监视器、活动窗口、迷你媒体，中间是工作区，右侧是托盘、通知、电量、音量、亮度等。
- 两个位置函数含义不同。`getBarPositionForScreen()` 返回 bar 窗口所在的边：时尚模式开着状态栏时是 `bar.position`，否则是任务栏所在的边。`getTaskbarPositionForScreen()` 总是返回任务栏所在的边，启动器定位、按屏覆盖编辑器和避让判断都用它。挂件弹层跟随所在的表面：dock 里的挂件弹层按任务栏的边，状态栏里的挂件弹层按状态栏的边。
- 状态栏和 dock 可以在同一条边上（悬浮居中的 dock 会叠在状态栏上方），建议放在不同的边。
- 自动隐藏时状态栏收进屏幕边缘，鼠标停在边缘的触发区时唤出。常驻时 `BarExclusionZone` 为它保留屏幕空间，规则与任务栏相同。
- 视觉：底色 `Color.maskShell`，无阴影，圆角按 `bar.barType`。与任务栏同屏时不额外加描边或发光。

---

## 4. 工具：`nosd-blur`（Rust）

- 作用：对应 deepin 的 `com.deepin.daemon.ImageBlur`，为全屏界面生成预模糊壁纸。QML 的 `MultiEffect` 最大模糊半径只有 64，强度不够，而且每帧全屏实时模糊太耗资源。
- 位置：`tools/nosd-blur/`（Cargo 项目）。
- 命令行：`nosd-blur <src> <dst> --width W --height H [--sigma S]`。
  - 处理流程：先按 cover 方式缩放并居中裁切，再做三次 box blur 近似高斯模糊，最后写出 PNG 或 JPEG。
  - 进程退出码 0 表示成功。
- 调用方式：由 `ImageCacheService` 调用。
  - 缓存键是源路径、修改时间、尺寸和 sigma 的哈希；缓存目录为 `Settings.cacheDir + "blur/"`。
  - 找不到 `nosd-blur` 时，退回 `MultiEffect` 实时模糊，并输出一次警告日志。
- sigma：默认取屏幕短边的 3%（1080p 约为 32）〔派生〕。`wallpaper.blurSigma`（默认 0，表示自动）为正数时改用这个固定值〔演进〕。deepin 原版 `image-blur-helper` 的参数不在参考仓库里。

### 4.1 `nosd-helpers wl-probe`

- 作用：探测当前 Wayland 合成器公布的全局接口，供 §1.2 判断合成器是否支持模糊。QML 拿不到 Wayland 注册表，Quickshell 在不支持时只打印一行警告。
- 命令行：`nosd-helpers wl-probe`，向 stdout 输出一行 JSON：`{"compositor_blur": true|false, "globals": ["wl_compositor", ...]}`；`compositor_blur` 为真当且仅当存在 `ext_background_effect_manager_v1`。连不上 Wayland 时退出码非 0。
- 调用方式：shell 启动时调用一次，结果存进 `CompositorService.blurSupported`。设置开启且 `blurSupported` 为真时，`Color.blurActive` 才为真。工具缺失或执行失败时按"支持"处理（与加入探测前的行为一致），并输出一次 `Logger.w`。

### 4.2 合成器侧规则（niri）

- nosdshell 通过 `ext-background-effect` 自己发布模糊区域（bar 与面板在 `nosdshell-background` 上，dock 和两个启动器各自发布），niri ≥ 26.04 无需任何规则即按客户端申请的形状精确模糊。layer-rule 只负责两件事：给浮动在窗口上的发布面关掉 xray（否则默认只采样壁纸），和给"永不模糊"的面钉 `blur false`。
- **绝不**在 nosdshell 面的 surface 级规则里写 `blur true`：niri 会按整个面（含透明区）施加模糊，而 `nosdshell-background`、`popupmenu`、`notifications`、`toast` 等大多是全屏面，这就是 2026-10 的巨型模糊事故。整面 `blur true` 只许写在 `popups {}` 里（xdg_popup 天然内容尺寸）。
- 三档取舍（性能由低到高：无模糊 < xray < 真模糊）：Tier 2 真模糊给浮在窗口上的发布面（`background`、`dock`、`launcher-mini`）；Tier 1 xray 给全屏静态面（`launcher-full`，它要的就是"模糊壁纸"观感）；Tier 0 给其余（壁纸面是模糊源本身、overview/关机界面/向导自画预模糊、`bar-content` 透传已模糊区域、瞬态卡片按 §1.2 无需模糊即可读、辅助面不可见）。
- 规则集的仓库内唯一事实源是 `Scripts/docs/nosdshell-layer-rules.kdl`，`check-layer-namespaces.py` 校验全部发射的 namespace 被归类且阻止 surface 级 `blur true` 回归；该文件经 `vendor-legacy-docs.py` 注入 docs 站的 niri 页。

### 4.3 `nosd-helpers portal`

- 作用：深色/浅色模式的对外权威面。单进程、单连接同时持有 `org.freedesktop.impl.portal.desktop.nosdshell`（portal Settings 后端：`Read`/`ReadAll`/`Version=1`/`SettingChanged`）、`nl.whynothugo.darkman`（darkman 兼容 API：可写 `Mode` 属性 + `ModeChanged` 信号）与 `org.freedesktop.impl.portal.desktop.darkman`（存量 `darkman.portal` 描述符的零配置别名）。`darkman get|set|toggle`、Emacs `self-theme` 等既有消费者无需改动；`~/.local/share/{dark,light}-mode.d/` 钩子目录语义与 darkman 一致。
- 命令行：`nosd-helpers portal <run|get|set|toggle|hooks>`；状态持久化于 `~/.local/state/nosdshell/color-scheme`；`~/.config/darkman/config.yaml` 的 `lat`/`lng` 启用 NOAA 日出日落调度（`usegeoclue` 不支持，`dbusserver`/`portal` 可分别关掉对应总线名）。
- 调用方式：`DarkModeService` 在每次 `darkMode` 变化时执行 `portal set`，并在 helpers 就绪时幂等拉起 `portal run`（进程内 flock + 总线名占有检查保证单实例）。portal 反方向（外部 `set`/`toggle`、太阳计时器）经 `SettingChanged` 广播，`schedulingMode: "system"` 的既有跟随逻辑天然接住，其他模式下由 daemon 侧 `nosdshell ipc call darkMode` 兜底写入。
- `.d` 钩子开关：设置里的 `colorSchemes.runDarkmanHooks` 由 `DarkModeService` 经 `portal hooks on|off` 写成 `~/.local/state/nosdshell/darkman-hooks` 标志文件（本地写，不等守护进程在线）；daemon 在每次 transition 时重读，0/off/false 即跳过钩子目录（其余状态/信号/转发不受影响）。文件缺失等于开，保持 darkman 默认行为。
- 工具缺失时 `pushPortal` 输出一次 `Logger.w` 并跳过；shell 自身主题切换不受影响，仅 portal 订阅者（GTK4/Electron 等）收不到通知。

---

## 5. 配色方案

- 新增预设方案 `Assets/ColorScheme/Deepin/Deepin.json`，并设为默认（`colorSchemes.predefinedScheme = "Deepin"`）。
  - 暗色：`mPrimary #2CA7F8`、`mOnPrimary #FFFFFF`、`mSecondary #01BDFF`、`mOnSecondary #FFFFFF`、`mTertiary #0087FF`、`mOnTertiary #FFFFFF`、`mError #F9704F`、`mOnError #FFFFFF`、`mSurface #181818`、`mOnSurface #FFFFFF`、`mSurfaceVariant #2A2A2A`、`mOnSurfaceVariant #B4B4B4`、`mOutline #3A3A3A`、`mShadow #000000`、`mHover #2CA7F8`、`mOnHover #FFFFFF`。
  - 浅色：强调色相同；`mSurface #F8F8F8`、`mOnSurface #303030`、`mSurfaceVariant #EBEBEB`、`mOnSurfaceVariant #6B6B6B`、`mOutline #D5D5D5`、`mShadow #000000`。
  - 方案中的颜色一律不透明，因为 GTK、终端等模板要直接使用这些颜色，尚未改造的组件也会把 `mSurfaceVariant` 当作实色来画。DDE 的半透明表面只从 §1.2 和 §1.3 的令牌获得。
- **表面令牌读取配色方案的表面角色**〔演进：原来只看明暗模式〕：蒙版取 `mSurface`，弹出层取 `mSurfaceVariant`，描边取 `mOutline`，外壳前景和叠加阶梯取 `mOnSurface`，`alert` 取 `mError`，禁用文字按 MD3 规则取 `onSurface` × 0.38。切换方案或用壁纸取色时，表面色调、文字色相、状态层和错误色都随方案变化。Deepin 方案的这些角色特意设成 DDE 15 的值（`#181818`、`#2A2A2A`、`#3A3A3A`、`#FFFFFF`、`#F9704F`），所以默认观感不变。以下颜色固定，不随方案变化：壁纸面的恒白阶梯、强制使用相反形态时瞬时面的经典值、浅色菜单的固定浅色调色板（`popupLight*`）、分隔槽的一对刻线，以及下一条的强调色覆盖。
- **`ui.accentOverride`**（默认空）〔演进〕：值为合法颜色时，`Color.mPrimary`、`mSecondary`、`mTertiary`、`mHover` 四个强调色角色都取这个颜色，对应的 `mOn*` 按它的亮度取白色或 `#303030`。`accent`、`accentAlt`、`accentAction`、`onAccent` 是这些 `m*` 角色的别名，所以直接读 `mPrimary` 的组件（进度环、滑块、勾选态）也会跟着变。`mError` 和表面类令牌不受影响。GTK 和终端模板直接读方案 JSON，不经过 `Color.qml`，照常使用方案颜色。设置页"当前方案"的预览条显示生效的颜色（即覆盖色），各方案的候选色板仍显示方案自带的颜色。
- 模板功能（GTK、终端等配色文件的生成）照常使用当前方案的完整颜色。

---

## 6. 设置与兼容

新增或修改设置的步骤见 `CODING_STANDARDS.md`「设置」，设置键的三种合法状态（活跃、兼容、删除）见 `AGENTS.md`「业务保真」。本节记录设计层面的取值和迁移含义。

下表列出相对上游 Noctalia 新增或改变了默认值的主要设置，完整默认值以 `Assets/settings-default.json` 为准。新设置的默认值体现了 DDE 规格或〔演进〕取舍时，在这里登记一行并注明规格章节。

| 设置 | 新默认值 |
|---|---|
| `dock.mode` | `fashion` |
| `dock.position` | `bottom` |
| `dock.iconSize` | 36 |
| `dock.hideMode` | `keep-showing` |
| `appLauncher.mode` | `fullscreen` |
| `appLauncher.displayMode` | `free` |
| `appLauncher.iconRatio` | 0.5 |
| `ui.panelBackgroundOpacity` | `0.65`（有模糊时的帧体 alpha；无模糊固定 0.8）〔演进〕 |
| `ui.settingsPanelMode` | `controlCenter` |
| `ui.panelsAttachedToBar` | `false` |
| `osd.location` | `bottom_center` |
| `osd.autoHideMs` | 1000 |
| `notifications.location` | `top_right` |
| `notifications.maxVisible` | 1 |
| `general.showScreenCorners` | `false` |
| `general.lockScreenBlur` | 启用 |
| `colorSchemes.predefinedScheme` | `Deepin` |
| `colorSchemes.schedulingMode` | `"off"`（`off`/`manual`/`location`/`system`；`system` 跟随 xdg-desktop-portal 的 `org.freedesktop.appearance/color-scheme`）〔演进〕 |
| `colorSchemes.runDarkmanHooks` | `true`（每次明暗切换时执行 `~/.local/share/{dark,light}-mode.d/` 钩子，§4.3）〔演进〕 |
| `bar.enabled` | `false`（可选状态栏，§3.13） |
| `ui.transientSurface` | `"auto"`（`light`/`dark`/`auto`，§1.2）〔演进〕 |
| `ui.transientOpacity` | `1.0`（0.3–1.0，瞬时面不透明度，§1.2）〔演进〕 |
| `ui.popupOpacity` | `1.0`（0.3–1.0，`popupShell` 族：菜单/箭头弹层/迷你启动器）〔演进〕 |
| `dock.backgroundOpacity` | `1.0`（0.3–1.0，dock 背景在 `panelBackgroundOpacity` 上的额外系数）〔演进〕 |
| `general.dimmerOpacity` | `0.35`（帧类面板背幕压暗，§3.5.1）〔演进〕 |
| `ui.borderEmphasis` | `1.0`（0–2，描边强度，§1.2）〔演进〕 |
| `general.shadowStrength` | `1.0`（0–2，阴影强度，§1.6）〔演进〕 |
| `ui.rowHeightScale` | `1.0`（0.9–1.2，行高系数，§3.5.4）〔演进〕 |
| `ui.accentOverride` | `""`（合法颜色时覆盖强调色系，§5）〔演进〕 |
| `wallpaper.blurSigma` | `0`（0 表示自动，取屏幕短边的 3%；正数为固定 px，§4）〔演进〕 |
| `dock.pluginSpacing` | `4`（0–24 px，时尚模式插件瓦片两侧留白，§3.1.4）〔演进〕 |
| `dock.fusedPlugins` | `false`（时尚模式插件底色合并为长条，§3.1.4）〔演进〕 |

兼容数据：

- `ui.settingsPanelMode`：设置页只在控制中心里显示，选择器已移除。上游的面板代码仍读取这个键，`Migration72` 把旧值固定为 `controlCenter`。

无设置页控件的活跃键（不是兼容钉值，消费方健在，用户入口在别处或刻意不开放）：

- `appLauncher.iconRatio`：全屏启动器内 Ctrl+滚轮/± 调整（§3.4.1）；DDE 把图标大小调节放在启动器内，设置页不开放。
- `general.shadowOffsetX`、`general.shadowOffsetY`：经 `Commons/Style.qml` 令牌读取（`NDropShadow`），DDE 阴影偏移是 §1.6 的固定规格而非偏好项，设置页不开放；上游键保留，手改 JSON 仍生效。

从上游 Noctalia 配置升级时的迁移：

- `bar.widgets` 复制为 `dock.plugins`，`bar.position` 复制为 `dock.position`。两个旧键保留，现在分别是状态栏（§3.13）的挂件布局和位置。
- 原来启用了 Bar 的用户，`dock.mode` 设为 `"efficient"`。
- `bar.barType` 保留原值（旧的 `"floating"` 取值由迁移 v81 转为 `bar.floating` 独立开关，§3.13）。高效模式下不生效（按 `simple` 绘制），时尚模式的状态栏按它绘制圆角，状态栏页有形态选择器（§3.13）。

### 6.1 上游功能移除清单

以下 Noctalia v4 能力是有意移除的，逐项记录理由。删除上游能力的规则见 `AGENTS.md`「业务保真」，每次删除都登记在这里。

| 移除项 | 理由 |
|---|---|
| `Services/Noctalia/UpdateService.qml` 应用内更新检查、`Panels/Changelog` 更新日志弹窗、`general.showChangelogOnStartup` | nosDshell 经 Guix 打包分发，更新统一走系统包管理器；应用内更新检查会引导用户绕过包管理。版本信息仍在"关于"页展示 |
| `Services/Noctalia/TelemetryService.qml` 遥测（`general.telemetryEnabled`） | 隐私考量，fork 不向外部服务上报使用数据 |
| `Services/Noctalia/GitHubService.qml`、`SupporterService.qml`、About 页的 Contributors/Supporters 子页 | 用于展示上游 noctalia 项目的贡献者和赞助者，这份名单不代表本项目。配色方案下载不依赖它们（`SchemeDownloader` 直接访问 colorschemes 仓库） |
| Talia 天气吉祥物（`location.weatherMascotAlways`、`location.weatherTaliaMascotAlways`） | noctalia 品牌资产，随重命名移除（v65/v66 迁移删除持久化键） |
| `Panels/NotificationHistory` 独立弹窗 | 并入控制中心通知页（§3.5.2），键盘操作模型已随 `NotificationHistoryList` 保留 |
| `general.showSessionButtonsOnLockScreen`、`general.showHibernateOnLockScreen` | DDE 锁屏的电源按钮固定显示（§3.9），休眠可见性由 `sessionMenu.powerOptions` 与系统能力决定，这两个开关不再门控任何东西；v67 迁移删除 |
| `general.compactLockScreen` | DDE 锁屏没有紧凑布局变体（§3.9）；v78 迁移删除 |
| `sessionMenu.position`、`sessionMenu.showHeader`、`sessionMenu.largeButtonsStyle`、`sessionMenu.largeButtonsLayout` | DDE 会话菜单是固定全屏按钮行（§3.8），这些布局选项没有对应物；v78 迁移删除 |
| `controlCenter.position` | 控制中心固定贴屏幕右缘（§3.5.1）；v78 迁移删除 |
| `Modules/Panels/Dock/StaticDockPanel.qml`（上游的 dock 样式面板） | 没有任何打开路径（无 open()/toggle()/PanelService 入口），随 `d3f2097f2` 与其专属键一起移除 |
| 通知历史的 Tab 键时间筛选（`currentRange`：全部/今天/昨天/更早） | 可见的日期分段标题取代了它（§3.5.2）。筛选页签在 DDE 化时已删，Tab 键仍切换隐形筛选状态，界面上看不出当前筛的是哪一段，也不能再切回全部；分段标题给出同样的时间上下文且不藏内容 |
| 启动器的 SmartPanel/overlay 前端（`Modules/Launcher/LauncherOverlayWindow.qml` 等，`appLauncher.position`、`appLauncher.overviewLayer`） | §3.4 的 DDE 视图是唯一激活前端，overlay 前端没有任何显示路径，`390d8de79` 移除 |
| 把旧配置目录 `~/.config/noctalia` 自动搬到 `~/.config/nosdshell` | 不做。nosDshell 是独立的 shell，不是 noctalia 的就地升级；`MigrationNN` 只负责 nosDshell 自身配置的逐键演进 |

本表只登记被移除的**上游能力**。清理已无读取方的死键不算移除：v55/v65 的键改名、`dock.windowPreviews`（v68，分叉点即无读取方）、v80 的 25 个 Noctalia 旧键（清单见 `Commons/Migrations/Migration80.qml`）均不进本表。

---

## 7. 禁止清单

以下做法与 DDE 15 冲突，评审时一律退回：

- 胶囊形外观（开关和圆角按钮除外）、超过 10 px 的圆角、Material 风格的彩色表面、水波纹、按压时的缩放、弹簧或回弹动画。
- 弹出层和栏融合在一起、反向圆角、外圆角、框架式栏（framed bar）。任务栏和 DDE 表面一律不采用；栏体的 floating/framed 形态与外圆角只作为可选状态栏（§3.13）上的非默认选项保留。
- 用彩色区分状态（例外：活动项 `accent`、请求注意 `attention`、错误 `alert`、充电态 `positive`）。
- 加粗（Bold / ExtraBold）；全大写的标题（包括把本地化的月名、星期名 `toUpperCase()`）；字间距不为 0 的正文。
- 界面中文里混用英文术语（术语表见 §1.10）；开关行标题写成随状态变化的动作句；用等宽字体显示数值读数（§1.5）。
- 在列表的每一行常驻同样的操作按钮（§3.2）；只有占位图、没有文字的空状态。
- 绕过 `Time` 用 `Qt.formatDate` 一类函数格式化日期（§1.5）。
- 在一个界面里同时出现两个强调色；用渐变给表面着色。
- 复制 `references/` 的素材或代码却不留出处（出处规则见 §1.9）。
- 用 Tabler 字形或 QML 近似重画参考仓库里已有原件的 DDE 专属素材（见 §1.9）。
- 在组件里写死颜色、尺寸或时长，绕过令牌。
