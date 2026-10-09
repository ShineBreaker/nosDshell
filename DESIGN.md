# nosDshell 设计规范 —— DDE 15 视觉语言

本文件规定 nosDshell 的视觉和交互风格。目标：Noctalia 的每项功能都用 **deepin 15（DDE 15）** 的界面方式呈现。凡是界面改动，都要符合本规范；如果和本规范冲突，就改代码，不改规范。确实要改规范，单独提交，并在提交说明里写清理由。

事实来源：`references/` 下的 GXDE-OS 仓库（DDE 15 的社区维护版，GPL-3.0，只供阅读）。本文中的数值都来自这些源码，形如 `gxde-dock/frame/item/appitem.cpp:297`（路径相对 `references/`）。参考源码里没有、由本规范推导出来的值，标为 **〔派生〕**。

---

## 0. 一句话概括 DDE 15

> **近黑色的毛玻璃，上面叠半透明白色；只有一个强调色：深度蓝 `#2CA7F8`。**

DDE 15 的界面安静、扁平、几何感强。表面要么是"模糊加黑色蒙版"，要么是"模糊加白色蒙版"。悬停、按下、选中这几种状态，只靠白色叠加层的透明度来区分，不换颜色。表面上不放彩色，强调色只用在"当前项"上。

> **2026 演绎**：结构、布局、交互逐条忠于 DDE 15；渲染层按现代惯例精修——可见的发丝描边、更软更深的阴影、可跟随主题的瞬时面（OSD/通知/吐司，见 §1.2）。这类有意偏离原版的数值标 **〔演进〕**，标注处的新值取代原值生效。默认值仍落在 DDE 15 的范围内，超出范围的调节交给设置项（§6）。

### 设计原则

1. **蒙版，而不是色块。** 常驻面板背景 = 背后模糊 + 半透明蒙版。蒙版颜色取自配色方案的表面角色〔演进：原为纯黑/纯白字面量〕——面板取 `mSurface`、弹出层取 `mSurfaceVariant`，蒙版自身的 DDE 透明度和模糊行为不变。Deepin 方案的表面值（暗 `#181818` / 浅 `#F8F8F8`）就是 DDE 15 的近黑/近白观感；其他方案得到各自色调的玻璃，这是方案染色可定制性的落点（§5）。面板背景不用渐变，不用 Material 实色 tonal surface 直接铺。OSD 和通知气泡这类瞬时提示是例外——它们不读蒙版，走 `maskTransient` 令牌体系：经典形态是不透明浅色实底（DDE 原版），也可切换为深色玻璃或跟随明暗模式（§1.2，`ui.transientSurface`）。
2. **前景透明度阶梯。** 表面上所有层级都是"该表面前景色 × 某个透明度"——暗色面用 `onShell`、壁纸面用恒白、浅色瞬时用深文字色（§1.3）。
3. **一个强调色。** `#2CA7F8` 只用在：当前活动项、菜单悬停行、按下态、进度和高亮、链接。其他地方不出现。
4. **小圆角。** 圆角在 4–10 px 之间（§1.4）。除头像、圆点这类正圆外，不要胶囊形，不要大圆角卡片。
5. **贴边并居中。** 任务栏贴住屏幕边缘并居中；控制中心贴右边、占满屏高；弹出层用带箭头的矩形指向触发它的任务栏图标。**弹出层不和栏融合成一体**（不要 Noctalia 的 attached panel 和反向圆角）。
6. **少动效。** 指针状态（悬停、按下、选中、禁用）一律瞬变——DDE 的 hover 高亮全是即时重绘，菜单与提示框没有任何显隐动画。能动的只有模型/生命周期驱动的变化：进入用 `OutCubic`，位移和尺寸用 `InOutCubic`，时长基准 300 ms，退场比进场快且收 ease-in。不要弹簧，不要回弹，不要水波纹。
7. **每个效果都要有降级方案。** 关掉模糊时，蒙版要更不透明（§1.2）。关掉动画时，时长为 0。

---

## 1. 设计令牌（Design Tokens）

令牌放在 `Commons/Style.qml`（尺寸、时长）和 `Commons/Color.qml`（颜色）。**组件里不要写死数值**，需要新数值就先在这里加令牌。

### 1.1 强调色与功能色

| 令牌 | 值 | 用途 | 来源 |
|---|---|---|---|
| `accent` | `#2CA7F8` | 活动项、菜单悬停、按下态、选中线、链接 | `gxde-dock/frame/item/appitem.cpp:297-309`；`deepin-menu/src/dmenucontent.cpp:164` |
| `accentAlt` | `#01BDFF` | 设置组标题旁的"编辑"类文字按钮、OSD 高亮 | `gxde-control-center` `SettingsHead QLabel#Edit`（dark.qss） |
| `accentAction` | `#0087FF` | 浅色气泡里的动作按钮文字；悬停时变成白字蓝底 | `gxde-session-ui/dde-osd/notification/actionbutton.cpp:30-63` |
| `attention` | `#F18A2E` | 窗口请求注意时（任务栏项填充 80%） | `gxde-dock/frame/item/appitem.cpp:313` |
| `alert` | `#F9704F` | 密码错误边框、错误提示文字 | `gxde-session-ui/dde-lock/skin/dpasswdeditanimated.qss` |
| `lowPower` | `#FF8000` | 低电量警告文字 | `gxde-session-ui/dde-lowpower/window.cpp` |
| `textDisabledDark` | `#646464` | 暗色菜单里的禁用项 | `deepin-menu/src/ddockmenu.cpp:92-96` |

### 1.2 表面（蒙版）

| 令牌 | 有模糊时 | 无模糊时 | 来源 |
|---|---|---|---|
| `maskDark` | `mSurface` × `ui.panelBackgroundOpacity`（默认 **0.4**） | `mSurface` × **0.8** | dtkwidget `DBlurEffectWidget::maskColor()`（DarkColor：有模糊用 maskAlpha，无模糊用 `MASK_COLOR_ALPHA_DEFAULT=204`）；默认透明度见 `gxde-desktop-schemas` `com.deepin.dde.appearance` `opacity=0.4`；RGB 改取方案表面色〔演进〕——Deepin `#181818` ≈ 原 `#000000` |
| `maskLight` | `mSurface` × 0.4 〔派生，与暗色对称〕 | `mSurface` × **0.8** | 同上（LightColor）；RGB 改取方案表面色〔演进〕——Deepin `#F8F8F8` ≈ 原 `#FFFFFF` |
| `popupDark` | `mSurfaceVariant` × 0.86 | 同左 | `gxde-dock/frame/util/dockpopupwindow.cpp:50-55`（Wayland 实测值）；RGB 改取方案 surfaceVariant〔演进〕——Deepin `#2A2A2A` ≈ 原 `#242424` |
| `borderDark` | `mOutline` × 0.10〔演进：原版 0.05 在现代屏上近乎不可见，提到 Win11 式可见发丝边；底色改取方案 mOutline——Deepin `#3A3A3A` ≈ 原 `#2C3238`〕 | `mOutline` | `gxde-dock/frame/util/dockpopupwindow.cpp:207-213` |
| `borderLight` | `mOutline` × 0.08〔演进：原版 0.04；底色改取方案 mOutline——Deepin `#D5D5D5` ≈ 原 `#E5E5E5`〕 | `mOutline` | `gxde-session-ui/dde-osd/container.cpp:73-78`；`notification/bubble.cpp:288-296` |

规则：

- **任务栏、控制中心、启动器小窗口、任务栏弹出层、暗色菜单**都用 `maskDark`。其中任务栏弹出层和暗色菜单用 `popupDark`（这两者的面积小，需要更高的不透明度才看得清）。
- **OSD、通知气泡、吐司**用 `maskTransient` 令牌族。瞬时面的形态由 `ui.transientSurface` 控制（§6）：
  - `light`：不透明浅色实底 + 深文字——DDE 15 的原版形态：浅色瞬时提示叠在暗色常驻外壳之上。底色取方案浅色面〔演进〕：浅色模式下即 `mSurface`（Deepin `#F8F8F8`，其他浅色方案各随其调）；暗色模式下方案没有浅色面，退为固定经典值 `#F8F8F8`，保证"light"始终是 DDE 那块浅砖。DDE 原版用 `DBlurEffectWidget::LightColor`（近不透明），半透明会浑浊且毁对比度，故取实色。
  - `dark`〔演进〕：深色玻璃，暗色模式底色取方案 `mSurfaceVariant`（Deepin `#2A2A2A`）；浅色模式下方案没有深色面，退为固定 `#242424`。有模糊时 alpha = `0.86 × ui.transientOpacity`（下限 0.5），无模糊时下限抬到 0.9——同样是"宁可平坦，不可浑浊"。文字/描边/叠加层整体翻为暗面规格（见下表"瞬时令牌"）。
  - `auto`（默认）〔演进〕：暗色模式按 `dark`，浅色模式按 `light`——跟随系统观感。
  - `ui.transientOpacity`（默认 1.0，范围 0.3–1.0）同时作用于两种形态：有模糊时直接乘在各自的基准 alpha 上（light 基准 1.0，dark 基准 0.86），无模糊时最终 alpha 一律抬到 ≥0.9——同样是"宁可平坦，不可浑浊"。`notifications.backgroundOpacity` 作为通知专属系数继续叠加。
- **全屏界面**（全屏启动器、关机界面、锁屏）不用蒙版，背景是**预先模糊好的壁纸**（§1.8）。
- "有模糊"= `Settings.data.general.enableBlurBehind` 为真 **且** 合成器确实提供 `ext-background-effect-v1`（启动时探测，见 §4 `nosd-helpers wl-probe`）。合成器不支持时一律按"无模糊"取 0.8 蒙版，否则半透明蒙版下面是清晰的壁纸，文字不可读。组件只读 `Color.maskDark` 这类令牌，不自己算透明度。
- 组件实际使用的是下列**语义令牌**：
  - `Color.maskShell`：常驻外壳（任务栏、控制中心、小窗口启动器、对话框）。暗色模式下等于 `maskDark`，浅色模式下等于 `maskLight`。DDE 15 只有暗色外壳，浅色外壳是为配色方案的浅色模式准备的。
  - `Color.popupShell`：弹出层和暗色菜单。暗色模式下等于 `popupDark`，浅色模式下为 `mSurface` × 0.9〔演进：原固定白 × 0.9〕。
  - `Color.borderShell` / `Color.borderTransient`：分别对应 `borderDark` / `borderLight`（浅色外壳使用 `borderLight`）；描边透明度受 `ui.borderEmphasis`（0–2，默认 1，0 = 无边框）整体缩放〔演进〕。
  - `Color.maskTransient`：瞬时提示（OSD、通知气泡、吐司），取值按上面的 `transientSurface` 规则解析——不再恒为不透明 `#F8F8F8`〔演进〕。
- 与之配套的前景色：`Color.onShell` = 方案的 `mOnSurface`〔演进〕——Deepin 仍是暗 `#FFFFFF` / 浅 `#303030`，其他方案的壳上文字随方案色相（如 Gruvbox 的米黄）。`Color.onTransient` 同理：浅色瞬时面 = 浅深文字（浅色模式取 `onShell`，暗色模式固定 `#303030` 经典值），深色瞬时面 = 浅文字。`onShellSecondary` / `onShellTertiary` 是它的弱化级：暗色侧用 DDE 规格 alpha 0.8 / 0.6，浅色侧 tertiary 提到 0.7——`#303030` × 0.6 在白帧上只有约 3.8:1，0.7 落到 ≈`#6E6E6E`（~5:1），对齐浅色方案的 `mOnSurfaceVariant`（`#6B6B6B`）。§1.3 的叠加阶梯以对应表面的前景色为底色。
- 瞬时面为 `dark` 时，整组瞬时令牌翻转〔演进〕：暗色模式下 `onTransient`→`onShell`（方案白/米白等）、`onTransientBody`→前景 × 0.85、`onTransientTrack`→前景 × 0.15、`onTransientTick`→前景 × 0.5、`overlayTransient(level)`→前景阶梯、动作文字 `transientAction`→`accent`（浅色面上是 `accentAction`）；浅色模式强制 dark 砖时前景退为固定恒白。组件永远只读这些令牌，不判断当前形态。
- 壁纸面（全屏启动器、关机界面、锁屏，§1.8 的预模糊壁纸 + 暗色压暗）在两种模式下都是暗色表面，上面的内容用不随主题翻转的令牌：`Color.onWallpaper` / `onWallpaperSecondary` / `onWallpaperTertiary`（恒白阶梯）、`overlayWallpaper(level)`（恒白叠加阶梯）、`onWallpaperShadow`（§1.5 文字投影 `rgba(0,0,0,0.31)`）。这些面上禁用 `onShell` 和 `overlay()`。

### 1.3 前景叠加阶梯（MD3 state layer）

阶梯底色的规则同 MD3 state layer：**状态色 = 该表面的前景色 × 层级透明度**。`Color.overlay(level)` 以 `onShell` 为底——暗色模式即 `mOnSurface`（Deepin 为白，其他方案随其色相）；浅色模式同理取 `mOnSurface` 的深色值（Deepin `#303030` ≈ 原黑阶梯）〔演进：原为白/黑字面量〕。壁纸面另用 `overlayWallpaper`（恒白），瞬时面用 `overlayTransient`（取 `onTransient`）。

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

- **禁止**超过 10 px 的圆角，正圆除外——约束的是基准令牌值；`radiusRatio`/`iRadiusRatio`（0–200%）允许用户把整套圆角等比放大超出该上限，这是有意的自由度出口。
- `general.radiusRatio` / `iRadiusRatio` 继续作为整体缩放系数，默认 1。
- 控制中心贴边部分是直角（`frame.cpp:150`）。任务栏在高效模式下是直角。

### 1.5 文字

| 角色 | 规格 | 来源 |
|---|---|---|
| 系统字体 | `Noto Sans`；中日韩用 `Noto Sans CJK SC/TC/JP/KR`；等宽 `Noto Mono` | `gxde-desktop-schemas` appearance `font-standard`；`gxde-default-settings/.../fontconfig.json` |
| 基础字号 | 9 pt（约 12 px） | appearance `font-size=9.0` |
| 暗色表面主文字 | `#FFFFFF` | 多处 |
| 暗色次要文字 | 白 × 0.8（数值、提示）；白 × 0.6（导航默认态、容量） | control-center `TipsLabel`；launcher `categorybutton.cpp:193-213` |
| 浅色表面标题 | `#303030`，字重 460 → 用 Medium(500) | `dde-osd/notification/appbody.cpp:30-31` |
| 浅色表面正文 | `rgba(0,0,0,0.9)` | 同上 |
| 页面标题 | 14 px，字重 500，居中 | control-center `QLabel#ContentTitle` |
| 设置组标题 | 字重 550 → 用 DemiBold(600) | `settingshead.cpp` + common.qss |
| 控制中心时钟 | 46 px，Light | `mainwidget.cpp:99-107` |
| 锁屏时钟 | 68 px，Light（原版字体为 Maven Pro Light；退回 `Noto Sans` Light），日期 16 px | `dde-lock/timewidget.cpp:36-60` |
| 模糊壁纸上的文字 | 白色，加一层黑色投影 `rgba(0,0,0,0.31)`，偏移 (0,1) | `appitemdelegate.cpp:142-153` |

- 字重只用 Light(300)、Regular(400)、Medium(500)、DemiBold(600)。**不用 Bold**。
- 字体相关设置项（`ui.fontDefault` 等）保留。默认值为空，表示按上表依次回退。

### 1.6 阴影

| 用途 | 模糊半径 | 偏移 | 颜色 | 来源 |
|---|---|---|---|---|
| 带箭头弹出层 | 32 | (0,3) | 黑 × 0.32 〔演进：原版 20/(0,2)/0.5，更大半径更低不透明度是现代软阴影〕 | `dockitem.cpp:64-67` |
| 控制中心 | 32 | (-16,0) | 黑 × 0.32 〔演进〕 | `frame.cpp:151-154` |
| OSD | 24 | (0,5) | 黑 × 0.24 〔演进：原版 16/0.27〕 | `container.cpp:73-78` |
| 通知气泡 | 24 | (0,4) | 黑 × 0.30 〔演进：原版 14/0.39〕 | `bubble.cpp:133-134` |
| 浅色菜单 | 20 | (0,8) | 黑 × 0.16 〔演进：原版 12/0.2〕 | `dmenubase.cpp:88-96` |
| 对话框 | 32 | (0,0) | 黑 × 0.32 〔演进〕 | `dockitem.cpp:64-67` |

任务栏本身**没有阴影**（`mainwindow.cpp:104-110`）。阴影统一走 `NDropShadow`，参数从令牌读取。原来的 `general.shadowDirection` / `shadowOffset*` 设置保留，但默认值改为上表。`general.shadowStrength`（0–2，默认 1）整体缩放阴影颜色的不透明度〔演进〕。

### 1.7 动效

DDE 15 的动效是"先砍再调"。`deepin-menu` 整库没有一个动画对象；dock 的弹出层、tooltip、窗口预览全部瞬变；hover 高亮在 mouse 事件里直接重绘。真正插值的动画集中在三层：**微反馈**（≤180 ms）、**空间过渡**（300 ms 主节拍）、**长动效**（壁纸交叉淡化、滚轮惯性、attention 摆动）。

| 令牌 | 时长 | 曲线 | 用于 | 来源 |
|---|---|---|---|---|
| `motionPanel` | 300 ms | InOutCubic | 任务栏显示/隐藏/尺寸变化、控制中心内的页面切换 | `gxde-dock/frame/window/mainwindow.cpp:360-386`；`gxde-control-center/src/frame/framewidget.cpp:44-51` |
| `motionEnter` | 300 ms | OutCubic | 控制中心整窗滑入、各类面板出现 | `gxde-control-center/src/frame/frame.cpp:71,90-95` |
| `motionBubbleIn` | 180 ms | OutCubic，从锚定缘水平滑入 12 px 并淡入（DDE 右下气泡：waylandEnterOffset −12→0 加在 rightMargin） | 通知出现 | `gxde-session-ui/dde-osd/notification/bubble.cpp:218-225,496-508` |
| `motionBubbleOut` | 300 ms | OutCubic，向右滑出（DDE 为向右缘塌缩的 geometry 动画） | 通知消失 | `gxde-session-ui/dde-osd/notification/bubble.cpp:486-488` |
| `motionOsdIn` / `motionOsdOut` | 160 / 120 ms | OutCubic / InCubic，下缘 margin 偏移 −12→0（自下向上入）/ →−8 | OSD 出现/消失 | `gxde-session-ui/dde-osd/container.cpp:199-218` |
| 壁纸过渡 | 1000 ms | InOutCubic | `wallpaper.transitionDuration`（默认 1000，设置滑杆 0.5–10 s） | `gxde-session-ui/widgets/fullscreenbackground.cpp:51-74` |
| `motionNavZoom` | 300 ms | OutCubic | 启动器分类导航悬停放大 1.0→1.2 | `gxde-launcher/src/widgets/navigationwidget.cpp:213-230` |
| `motionSettingsScroll` | 1400 ms | OutQuint | 设置页内定位与页内长滚动 | `gxde-control-center/src/frame/widgets/contentwidget.cpp:51,106-112` |
| `motionScrollWheel` | 800 ms | OutQuint | 滚轮惯性滚动（列表/网格/滚动视图） | `gxde-launcher/src/view/applistview.cpp:105-112` |
| `motionProgramScroll` | 300 ms | OutQuad | 程序化滚动定位（点分类跳锚点、滚动到可见） | `gxde-launcher/src/fullscreenframe.cpp:189-204`（未显式设时长，Qt 默认 250，归并到 300 主节拍） |
| `motionSwing` | 1200 ms | Linear 关键帧（±8°，阻尼衰减回中） | dock 项 attention 摆动，持续期间每 ~2.2 s 重播 | `gxde-dock/frame/item/components/appswingeffectbuilder.h:87-118`；`appitem.cpp:690-732` |
| `motionSwitch` | 150 ms | — | 开关滑块 | 派生自 DTK（§3.5.4） |
| `tooltipDelayDock` | 500 ms | — | 任务栏悬停提示 | `gxde-dock/frame/item/dockitem.cpp:75` |

非动画时长不进 Style 令牌，它们是用户可调设置：`osd.autoHideMs`（默认 1000，`dde-osd/manager.cpp:74`）与 `notifications.*UrgencyDuration`（低/普通/紧急 3/5/15 s，`bubble.cpp:514-517`）。

规则：

- **瞬变清单**（DDE 明确不动画，禁止补动效）：菜单出现/消失/悬停/子菜单；任务栏弹出层与提示框的显隐；指针态颜色与透明度（hover/press/checked/disabled）；attention 图标切换；OSD 数值条；密码错误反馈（描边 + 文字，无抖动）；启动器显示模式切换。
- **曲线词汇表**：`OutCubic` = 进入；`InOutCubic` = 位移/尺寸/页面切换；`InCubic` = 快速退场；`OutQuad` = 程序化滚动定位；`OutQuint` = 滚轮长惯性；`Linear` = 旋转/循环/计时/拖拽跟手。其余曲线（Back、Elastic、Bounce、Spring、自定义 `BezierSpline`）一律禁用。
- **不对称退场**：退出比进入短且收 ease-in（OSD 160/120、`OutCubic`→`InCubic` 是范本）。
- **合并语义**：运行中的动画被再次触发时只改目标值、不打断（QML `Behavior` 天然如此；手写 `start()` 前先沿用当前值）。
- **延时不是动画**：tooltip 500 ms、预览 200/300 ms、自动隐藏收起 100 ms（`mainwindow.cpp:282-294`；`docksettings.h:78`）这类 `singleShot` 是状态切换的防抖，不换算成缓动。
- **适配说明**：DDE 的启动器开合、关机界面是零动画瞬显；本实现为这两类全屏毛玻璃面保留 `motionEnter` 短淡入——layer-shell 全屏面瞬显在合成器上会闪，且要等模糊壁纸首帧。这是有意的偏离，不是疏漏。
- 关闭模糊时，panel/enter 类动画时长改为 150 ms（`framewidget.cpp:172`）。`animationDisabled` 为真时一律为 0。
- 已有的 `Style.animationFast/Normal/...` 继续保留给通用场景（如拖拽跟手、装饰性循环），但上表里列出的场景**必须**用对应令牌。

### 1.8 背景与模糊壁纸

- 全屏启动器、关机界面、锁屏都画**预先模糊的当前壁纸**：按 cover 方式（等比放大后居中裁切）缩放到屏幕尺寸，最底下先铺一层纯黑（`fullscreenbackground.cpp:142,259-275`）。
- 模糊图由 Rust 工具 `nosd-blur` 生成并缓存（对应 deepin 的 `com.deepin.daemon.ImageBlur`，见 §4）。缓存图还没生成好时，先用 `MultiEffect` 实时模糊顶替。
- 启动器上下两端各有 60 px 的渐隐带（`GradientLabel`，`constants.h:41`）。

### 1.9 图标

- **应用图标**：全彩，取系统图标主题（推荐 Papirus 或 deepin；不随仓库分发）。
- **状态与托盘图标**：16 px 的 `*-symbolic` 主题图标（`battery-*-symbolic`、`audio-volume-*-symbolic`、`network-*-symbolic`）。主题里找不到时，退回 Tabler 字形。
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

---

## 2. Noctalia 功能 → DDE 15 模块对照

左列每项 Noctalia 功能，都必须落到右列的 DDE 形态上。

| Noctalia | DDE 15 形态 | 规格章节 |
|---|---|---|
| `Modules/Bar`（顶栏） | **任务栏 · 高效模式**（贴边通栏） | §3.1 |
| `Modules/Dock` | **任务栏 · 时尚模式**（居中） | §3.1 |
| Bar 上的挂件（`Modules/Bar/Widgets/*`） | **任务栏插件**（两种模式下样式不同） | §3.1.4 |
| Bar 和 Dock 上的弹出面板（Audio / Network / Bluetooth / Battery / Brightness / Clock / Media / SystemStats / Tray 抽屉 / 插件面板） | **带箭头弹出层**（DockPopupWindow） | §3.2 |
| 提示框 `Modules/Tooltip` | 暗色带箭头的提示框（TipsWidget） | §3.2 |
| 右键菜单 `NContextMenu` / `NPopupContextMenu` / `TrayMenu` / `DockMenu` | **deepin-menu**：暗色带箭头菜单 / 浅色菜单 | §3.3 |
| 启动器 `Panels/Launcher` | **全屏启动器**（默认）+ **小窗口启动器** | §3.4 |
| 控制中心 `Panels/ControlCenter` + 卡片 | **控制中心首页**（右侧滑出） | §3.5 |
| 设置 `Panels/Settings` | **控制中心设置页**（56 px 图标导航条 + 内容区） | §3.5.3 |
| 通知历史 `Panels/NotificationHistory` | 控制中心首页的**通知页**（铃铛按钮切换） | §3.5.2 |
| 通知 `Modules/Notification` | **浅色通知气泡** | §3.6 |
| 吐司 `Modules/Toast` | 浅色气泡的简化版 | §3.6 |
| OSD `Modules/OSD` | **dde-osd 浅色方块** | §3.7 |
| 会话菜单 `Panels/SessionMenu` | **dde-shutdown 全屏关机界面** | §3.8 |
| 锁屏 `Modules/LockScreen` | **dde-lock** | §3.9 |
| 壁纸 `Panels/Wallpaper` | 底部壁纸选择条〔派生自 dde-desktop，参考仓库中没有〕 | §3.10 |
| 首次设置向导 `Panels/SetupWizard` | 类似 dde-welcome：模糊壁纸 + 居中的暗色对话框 | §3.11 |
| 各类确认弹窗 | **DDialog** 暗色对话框 | §3.11 |
| 桌面挂件 `Modules/DesktopWidgets` | 暗色毛玻璃小卡片 | §3.12 |
| 屏幕圆角 `ScreenCorners`、栏的 framed/floating 形态、外圆角 | **DDE 中没有**。保留功能代码，默认关闭，设置界面里放到"高级"下 | — |
| 多个配色方案 / 壁纸取色 | 默认用 **Deepin** 方案；切换其他方案只改强调色 | §5 |

---

## 3. 组件规格

### 3.1 任务栏（Dock）

一个任务栏，两种模式，同一时刻只显示一种。由 `dock.mode` 控制：`"fashion"`（默认）或 `"efficient"`。
来源：`gxde-dock`；默认值取自 `com.deepin.dde.dock.gschema.xml`。

#### 3.1.1 通用

- 位置：`bottom`（默认）/ `top` / `left` / `right`，贴住屏幕边缘。
- 尺寸：图标尺寸分小 30、中 **36**（默认）、大 48 三档（`docksettings.cpp:42-44`）。
  - 项高 = 图标尺寸 × 1.5（时尚）或 × 1.2（高效）。
  - 项宽 = 项高 × 1.1（时尚）或 × 1.4（高效）。
  - 项内图标边长 = min(w,h) × 0.8（时尚）或 × 0.7（高效）。
- 背景：`maskDark`，直接贴边，**没有阴影、没有边框**。时尚模式在启用合成时圆角为 5（`radiusItem`），高效模式为直角。
- 隐藏模式（对应 DDE 的 `hide-mode`）：
  - `keep-showing` → 预留屏幕空间（exclusive）
  - `keep-hidden` → 自动隐藏
  - `smart-hide` → 有窗口挡住时隐藏；合成器不支持时按 keep-hidden 处理
- **全屏**：窗口在某输出上全屏时，该输出的任务栏/dock 无条件隐藏（不含 2 px 感应条，悬停不唤出），退出全屏即恢复。〔派生：DDE 的真实全屏应用覆盖 dock〕
- 隐藏和显示：沿屏幕边缘滑动，`motionPanel`。显示延迟 100 ms（`show-timeout`），隐藏延迟 100 ms。隐藏后只在边缘留 2 px 的感应条。
- 悬停提示：延迟 500 ms，用暗色带箭头提示框，箭头尖端距项边缘 2 px。
- 右键：
  - 点在图标区域（居中、边长为 0.8×min(w,h) 的正方形）内 → 弹出该项的**暗色带箭头菜单**。
  - 点在图标区域外，或点在空白处 → 弹出**任务栏设置菜单**（浅色），含：模式、位置、大小、状态、插件开关（`docksettings.cpp:208-251`）。

#### 3.1.2 时尚模式（fashion）

- 居中。最大长度 = 屏幕边长 − 60 px（`FASHION_MODE_PADDING=30`）。
- 从左到右（竖放时从上到下）：**启动器图标 → 驻留和运行中的应用 → 插件区**。插件区紧接在应用后面，中间留一道细缝。
- 运行指示：
  - 运行中：在贴屏幕边的一侧画一条 **20×2 px** 的横条（竖放时 2×20），距项边缘 1–3 px，颜色白 × 0.25。
  - 活动窗口：同一位置，颜色为 `accent`，两端渐隐（`appitem.cpp:320-358`）。
- 悬停：图标整体提亮（相当于 `QColor::lighter`；QML 中用 `MultiEffect.brightness` ≈ 0.15 实现），**不画悬停底色**。
- 请求注意：图标轻微摆动（swing），同时指示条变为 `attention` 色。
- 应用太多放不下时，按比例缩小每个项（`mainpanel.cpp:623-698`）。

#### 3.1.3 高效模式（efficient）

- 占满整条屏幕边。从左到右：**启动器 → 任务列表 → 伸缩空白 → 托盘与插件区 → 显示桌面条**。
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
| Launcher | 启动器图标（0.7） | 启动器图标（0.6–0.8） |
| Taskbar | 应用项（§3.1.3） | 由任务栏本体负责，不作为插件出现 |
| Clock | 白字两行居中 `hh:mm` / `yyyy/MM/dd`；竖放时三行；宽 = 字宽 + 20 | 圆角方形"时钟图标"，上面是大号数字时间（用 QML 画） |
| Tray | 16 px 图标排成一行，间距 10 | 时尚托盘：圆角 10 的胶囊可展开/收起；分隔线 2 px 白 × 0.1（`fashiontraycontrolwidget.cpp`）。**胶囊底色用与其他插件一致的 `overlay` 梯度（`subtle`/`hover`/`checked`）〔派生：上游展开态是暗色 #282828@0.5，nosDshell 按用户要求统一为插件瓦片底色〕** |
| Volume / Microphone / Network / Bluetooth / VPN / Brightness / Battery | 16 px symbolic 图标，sizeHint 26×26；Battery 在图标右侧加百分比文字 | 0.8 倍的图标 |
| SessionMenu | `system-shutdown` symbolic | `system-shutdown` 彩色图标 |
| NotificationHistory | 铃铛 symbolic（有未读时显示角标） | 铃铛图标；点击打开控制中心的通知页 |
| ControlCenter / Settings | 控制中心图标 | 同左 |
| Workspace | 小方格，当前工作区为 `accent` 实色 〔派生〕 | 默认不显示 |
| ActiveWindow / MediaMini / SystemMonitor / AudioVisualizer / KeyboardLayout / LockKeys / CustomButton / DarkMode / NightLight / KeepAwake / PowerProfile / NoctaliaPerformance / WallpaperSelector | 16 px 图标，或单行白字（可选） | 0.8 倍的图标，不显示文字 |
| Spacer | 伸缩空白 | 忽略 |
| （新增）Trash | `user-trash[-full]` | 同左；点击打开回收站，弹出层里可清空 |

- 默认插件（时尚模式）：Tray、NotificationHistory、Network、Volume、Battery、Clock、SessionMenu、Trash。
- 原来的 `bar.widgets.{left,center,right}` 合并为 `dock.plugins`（有序列表），旧配置通过迁移转换（§6）。

### 3.2 带箭头弹出层与提示框（DockPopupWindow / TipsWidget）

凡是从任务栏项弹出的面板，都用这个形态：

- 形状：圆角矩形，`radiusPopup` = 6；箭头 **宽 18 × 高 10**，指向触发项，箭头尖端距项边缘 2 px（`dockitem.cpp:64-71,441-456`）。
- 背景 `popupDark`，描边 `borderDark`，阴影 20 / (0,2)。
- **不和任务栏连在一起**。Noctalia 的 `panelsAttachedToBar` 对这类面板一律不起作用。
- 内容宽度：200–320 px（声音 200、磁盘 300）。行高 36，左右内边距 10–20。
- 分区标题：白 × 0.6、字号 S。分隔线：1 px、白 × 0.1。滑块高 22。
- 点击外部关闭；按 Esc 关闭。显隐瞬变，不做动画（`dockpopupwindow.cpp:84-148`：算好位置直接 show/hide）。
- 提示框：同样的形态，只放白色文字；宽 = 文字宽 + 6 × 字高；没有图标。

### 3.3 菜单（deepin-menu）

两种菜单：

**暗色带箭头菜单**（DDockMenu，用于任务栏项、托盘应用、启动器项）。来源：`deepin-menu/src/ddockmenu.cpp`、`dmenucontent.cpp`。

- 外框同 §3.2，箭头宽 18 × 高 10。
- 行高 = 字高 + 8（上下内边距各 4）。左右内边距 20。宽 = 最长文字 + 50，最大 500。
- 普通项：透明底、白字。悬停：**整行填 `accent`**，白字。禁用：`#646464`。
- 分隔行高 6 px，中间是一道"凹槽"：上一条 1 px `rgba(0,0,0,0.1)`、下一条 1 px `rgba(255,255,255,0.1)`，左右各缩进 4 px。
- 键盘：↑ / ↓ 移动，Enter 激活，Esc 关闭。
- 允许有勾选标记和子菜单箭头（DDE 有这些素材但没画出来）。用 12 px 的 Tabler 字形，放在右侧。

**浅色菜单**（DDesktopMenu，用于桌面右键、任务栏设置菜单）〔派生自 DTK dstyle〕。

- 白 × 0.9 底，圆角 `radiusRow` = 4，阴影见 §1.6。
- 文字 `#303030`；悬停整行 `accent` 底、白字；禁用为黑 × 0.3。
- 有勾选和子菜单。在光标处弹出，超出屏幕时向内收。

### 3.4 启动器（dde-launcher）

由 `appLauncher.mode` 控制：`"fullscreen"`（默认，对应 schema 中 `fullscreen=true`）或 `"mini"`。

#### 3.4.1 全屏模式

- 覆盖整个屏幕。背景为模糊壁纸（§1.8）。点击空白处关闭；Esc 关闭；直接打字即开始搜索。
- 布局（`fullscreenframe.cpp`、`appsmanager.h:50-51`）：
  - 顶部留 30 px（任务栏在顶部时再加上任务栏高度），然后是**搜索行**。
  - 搜索行（`searchwidget.cpp:81-103`）：左边距 30 → 分类切换按钮（22 px）→ 伸缩 → 搜索框（**宽 290，水平居中**，底色 `strong`，圆角 5，左右内边距 25 / 20，白字）→ 伸缩 → 切换到小窗口按钮 → 30 → 设置按钮 → 30 → 电源按钮（打开 §3.8）→ 右边距 30。按钮图片用原版多态素材（§1.9）。
  - 搜索行下方 20 px（`APPS_AREA_TOP_MARGIN`）是应用网格。网格左右各留 **180 px**（屏幕宽 ≤ 1366 时 130 px，`calculate_util.cpp:47-54`）；任务栏在底部时，网格底部留 60 px。
  - 启动器窗口覆盖整个屏幕（包括任务栏占用的区域），任务栏保持显示在启动器之上。
- 网格（`calculate_util.cpp:104-145`）：
  - 单元宽度预算：屏幕宽 ≤ 1440 时 170 px，否则 200 px；间距 10 / 14。列数 = (屏幕宽 − 2×左右留白) ÷ 宽度预算；实际单元边长 = (容器宽 − 间距×列数×2) ÷ 列数。**单元是正方形**，行高不随容器高度拉伸（`calculate_util.cpp:104-145`）。
  - 图标边长 = 单元尺寸 × `appLauncher.iconRatio`（默认 0.5，范围 0.2–0.6，Ctrl+± 调整）。
  - 标签：12 px 白字，最多两行，超出用 `…` 截断，带投影（§1.5）。
  - 悬停或选中：黑色压暗块（`rgba(0,0,0,0.41)`），圆角 10。
  - 新安装的应用：标签左侧显示 10 px 的 `accent` 圆点。
- 两种显示方式（`display-mode`）：
  - `free`：所有应用平铺，纵向滚动（不分页）。
  - `category`：左侧分类导航栏（屏幕宽 > 1366 时 180 px，否则 130 px）。
    - 11 个分类：网络、社交、音乐、视频、图像、游戏、办公、阅读、编程、系统、其他。
    - 每个按钮高约 42，22 px 图标加文字。文字白 × 0.6 / 0.8（悬停）/ 1.0（选中）。悬停时整列放大到 1.2。
    - 右侧每个分类有一行标题（高 50）：文字后跟一条 1 px 渐隐线（白 × 0.3 → 0）。滚动时，当前分类的标题吸附在网格顶部。
- 滚动：`OutQuad` 动画，滚动条隐藏。
- 非应用类结果（计算器、剪贴板、表情、命令、窗口、会话、设置搜索）：在网格上方显示成**分组列表**，行样式同 §3.4.2，宽度与搜索框对齐、最大 600 〔派生〕。剪贴板预览放在列表右侧的暗色卡片里。

#### 3.4.2 小窗口模式（mini）

- 尺寸：高 **502**，宽 = 320（左侧窗格）+ 右栏（约 160）（`windowedframe.cpp:158,169`）。
- 紧贴任务栏，间距 1 px。高效模式下贴在屏幕角落；时尚模式下与任务栏起始边对齐。
- 背景 `maskDark`。描边 `rgba(255,255,255,0.1)`。圆角 5；高效模式下只有贴近任务栏的那个角是 10。
- 左侧窗格，从上到下：
  1. 10 px 间距
  2. 搜索框（宽 290）
  3. 10 px 间距
  4. 1 px 分隔线
  5. 4 px 间距
  6. 应用列表（行高 **36**；图标 24 px 放在 x=10；文字从 x=48 开始，过长时右侧截断；悬停底色 `hover`，圆角 4，缩进 1 px）
  7. "所有应用 ⇄ 分类"切换按钮（悬停/选中底色 `hover`，圆角 4；按下时文字变 `accent`）。应用列表态显示"分类"+ 20 px 进入箭头；分类视图（分类列表或分类内）显示"返回"。点击循环：全部应用 → 分类列表 → 点分类进分类内 → 返回分类列表（`windowedframe.cpp` `onSwitchBtnClicked`）
  8. 15 px 间距
- 右栏：
  - 左边缘一条 1 px 竖线（白 × 0.1）。
  - 顶部先留 30 px，然后是 **60×60 圆形头像**（`avatar.cpp:42`），左对齐。
  - 中部：常用位置按钮（计算机、视频、音乐、图片、文档、下载），**纯文字**、无图标（`miniframerightbar.cpp:61-67` 只传 `tr("Computer")` 等文本）；字号 max(基础字号 px + 2, **14 px**)（`miniframebutton.cpp:43-48`）；悬停/键盘选中时显示选中底（白 × 0.1，圆角 4）。DDE 还有第 7 个 "Manual" 项，仅当系统装有 `dman` 时显示（`miniframerightbar.cpp:57`）；nosDshell 没有手册应用，不显示。
  - 底部：先是时间（**40 px**，白色，`datetimewidget.cpp:35`），下面一行日期；再下面横排"设置"和"电源"两个按钮，文字加左侧图标（原版 `settings.svg` / `power.svg`，`miniframerightbar.cpp:95-96`）。
  - 右上角：24×24 的全屏切换按钮，用原版 `fullscreen_{normal,hover,press}.png`。
  - 内边距 (18, 0, 12, 18)（`miniframerightbar.cpp:144`）。
- 列表里的分类项：文字白 × 0.6；选中时文字 `accent`，底色 `rgba(21,21,21,0.2)`，圆角 4。

### 3.5 控制中心（dde-control-center）

来源：`gxde-control-center/src/frame/*`。

#### 3.5.1 外框

- **宽 408 px，高度占满屏幕，贴住屏幕右边**（`frame.h:53`、`frame.cpp:517-523`）。左侧阴影 20、黑 × 0.5；直角。
- 背景 `maskDark`。从右侧滑入，`motionEnter`（300 ms OutCubic）。
- 帧左侧的区域由控制中心自己的 scrim 压暗〔演进〕：原版没有遮幕，但我们的全屏透明层会让背后的窗口贴着帧边缘透出文字。scrim 在贴帧处最重（`Style.edgeSheetScrimOpacity`，黑 × 1.0）、向内渐降到 `edgeSheetScrimOpacityMin`（黑 × 0.25）——贴帧的可读文字压死，远处背幕仍透气。它跟随滑入时的帧左缘，不盖住帧本身；点击外部仍走共享的 click-outside 关闭。
- 点击外部关闭；按 Esc 时，如果在子页面就先返回上一级，否则关闭。
- Noctalia 原有的 `controlCenter.position` 设置不再起作用：控制中心永远在右侧。任务栏在右侧时，控制中心排在任务栏内侧。

#### 3.5.2 首页

从上到下（`mainwidget.cpp`）：

1. **头部**，高 140，内边距 (40, 0, 0, 10)。
   - 左上：头像（圆形）。
   - 时钟：46 px，Light，白色，`HH:mm`。
   - 日期：长日期格式，白色。
   - 右侧：铃铛按钮（32×32，可切换），用于在"模块网格"和"通知页"之间切换。
2. **更新提示条**（有更新时出现）：底色 `idle`，悬停 `hover`。
3. **中部**，可滚动，有两个页面，由铃铛切换：
   - **模块页**：先排已启用的 Noctalia 卡片（天气、媒体、系统监控、日历），每张卡片底色 `idle`、圆角 5、内边距 10–20；然后是**模块网格**。网格 3 列，每个格子缩进 5、圆角 5，默认 `idle`、悬停 `hover`；格子里是 24 px 图标加文字。
   - **通知页**：通知历史列表。
     - 每条：浅色气泡的暗色版本——白字，底色 `strong`，圆角 5。
     - 顶部"全部清除"按钮：底色 `idle`，内边距 4。
     - 列表为空时居中显示"没有系统通知"。
     - 删除一条时，它沿宽度方向收起。
4. **快捷控制面板**（底部，`quick_control/*`），分页显示，页与页之间用分页指示器切换（高 40；当前页的圆点为 `onShell` × 0.8，其余 × 0.3）。所有页共享同一个页面槽高（`quickControlPanelHeight`），翻页时新页沿行进方向滑入淡入（`motionPanel`），圆点在深色帧上呈白色、浅色帧上自动翻为深色：
   - **基础页**：音量和亮度两条滑块（两端各有 24 px 图标），下面一排快捷开关。
   - **快捷开关**：每个 **70×60**，图标靠下对齐，距底部 20 px。开启时，背后画一块白 × 0.2 的底，圆角 6，下边距 5。原 Noctalia 的 `controlCenter.shortcuts` 全部放到这里。
   - **Wi-Fi 页、蓝牙页、显示页、VPN 页**：列表行高 36，样式同 §3.5.4；列表限制在页面槽内，超出时滚动。

Noctalia 卡片的对应关系：

| Noctalia 卡片 | 控制中心位置 |
|---|---|
| ProfileCard | 头部 |
| ShortcutsCard | 快捷开关 |
| AudioCard、BrightnessCard | 快捷控制面板的基础页 |
| WeatherCard、MediaCard、SystemMonitorCard、CalendarCards | 模块页顶部的卡片 |

#### 3.5.3 设置页（原 Settings 面板）

- DDE 15 的设置页是**一整页"所有设置"**（`settingswidget.cpp:90`），不是一次只显示一个模块：所有模块按顺序纵向排在同一个滚动区里，每个模块以"模块头"开头。从首页模块网格点某个模块进来，等于打开"所有设置"并滚动到该模块。
- 进入设置页后，控制中心外框不动，但**首页的头部（头像/时钟）和底部快捷控制面板都隐藏**，整个外框高度只给两栏（`frame.cpp:127-137`，参照 `references/1.jpg`）：
  - **左栏**：56 px 宽的导航条（`frame.h:54`）。按钮整体**垂直居中**（上下各一段伸缩），按钮间距 20（`navigationbar.cpp:102-110`）。每个按钮左右外边距 10、上下内边距 5、圆角 4；悬停底色白 × 0.2，选中白 × 0.3（`dark.qss` `NavigationBar DImageButton`）。图标用原版 24 px 的 `nav_<模块>_normal.svg`（默认）/ `nav_<模块>.svg`（选中）（§1.9）；上游没有的扩展模块（任务栏/启动器/控制中心/通知/桌面挂件/系统监视/插件/高级）用 `Assets/Nav/` 下同规格自绘素材（24 px、白色、normal 态内嵌 0.2 透明度），不混用其他图标族。悬停时向左弹出暗色箭头提示框（Wayland 下底色黑 × 0.8，`navigationbar.cpp:96-99`）。
  - **右栏**：内容区，宽 352。
- 导航与滚动联动：
  - 点导航按钮 → 内容区平滑滚动到该模块头，`OutQuint` **1400 ms**（`contentwidget.cpp:51,106-112`）。
  - 用户滚动停下后 → 选中项更新为视口中第一个顶部可见的模块（`settingswidget.cpp:342-380`）。
- 模块头（`modulewidget.cpp`）：左边距 11，24×24 的模块图标（与导航选中态同一个 `nav_<模块>.svg`），接大号标题（LargeLabel，白色），上下内边距 5（`modulewidgetheader.cpp`）。模块之间留 1 个分组间距。
- 内容区顶部：返回按钮（24×24 圆角 4 的方块，底色白 × 0.2），居中标题"所有设置"（14 px / 500），再下面 15 px 是一条分隔线。内容可滚动，滚动条隐藏。
- 二级页（NextPageWidget 进入）：新页面从右侧推入，旧页面向左推出，`motionPanel`（300 ms InOutCubic）；位移过程中按距离同步淡出。二级页的标题换成该页名称，返回按钮回到"所有设置"。
- 性能：所有模块一次性展开代价较大。允许按顺序异步加载（`Loader.asynchronous`），先加载目标模块及其前后各一个，其余空闲时补齐；未加载的模块用估计高度占位，加载完成后保持当前目标模块的头部位置不跳动。
- 模块顺序与对应（DDE 原有顺序见 `navigationbar.cpp:39-85`）：

| DDE 模块 | 承载的 Noctalia 设置 Tab |
|---|---|
| 账户 accounts | General（头像、用户名） |
| 显示 display | Display（亮度、夜灯） |
| 个性化 personalization | ColorScheme、Wallpaper、UserInterface |
| 任务栏 dock | Bar、Dock（合并）。该模块暴露的就是 §3.1.1 设置菜单的五项——模式、位置、大小、状态、插件开关，外加插件分组和多屏覆盖。原 Noctalia 的 `bar.*`/`dock.*` 细节设置（密度、间距、指示器、点击动作等）DDE 不暴露，收进"高级"组 |
| 启动器 launcher | Launcher |
| 控制中心 | ControlCenter |
| 网络 network | Connections / Wi-Fi |
| 蓝牙 bluetooth | Connections / Bluetooth |
| 声音 sound | Audio |
| 通知 notifications | Notifications、Osd |
| 时间日期 datetime | Region（语言、位置、天气） |
| 电源 power | Idle、SessionMenu、LockScreen |
| 键盘 keyboard | General / Keybinds |
| 桌面挂件 | DesktopWidgets |
| 系统监控 | SystemMonitor |
| 插件 | Plugins |
| 高级 | Hooks、以及第 2 节表格里标为"DDE 中没有"的那些开关 |
| 系统信息 systeminfo | About |

- 原来的子 Tab 不再用横向标签栏，改为**分组**（SettingsGroup，每组带组标题）。内容较多的子页，用"下一页"行（NextPageWidget）进入二级页。
- `ui.settingsPanelMode = "window"` 继续可用：在一个居中的 DDialog 风格窗口里显示同样的两栏结构（总宽 = 56 + 640）。默认值为 `"controlCenter"`。

#### 3.5.4 设置项控件（dcc::widgets）

- **SettingsGroup**：一组行纵向排列，行与行之间留 1 px 缝隙（透出下面的蒙版，形成分隔效果）。整组外缘：第一行上方两角、最后一行下方两角为圆角 5。
- **SettingsItem**：行底色 `strong`（`rgba(238,238,238,0.2)`）。可交互的行悬停时为 `checked`（0.3）。出错时画 2 px 的 `alert` 色描边。
- **SettingsHead**：高 24，左右内边距 (20, 10)。标题 DemiBold、白色。右侧可放"编辑"文字按钮（`accentAlt`）。
- **标准行**：高 **36**，左右内边距 (20, 10)。
  - 下一页行：标题，右侧是数值（白 × 0.8），再右侧是一个 `›` 箭头。
  - 开关行：标题，右侧是开关。
- **开关**（DSwitchButton）〔派生自 DTK〕：外形 40×22 的胶囊（开关是唯一允许用胶囊形的控件）。关闭时底色白 × 0.2；开启时底色 `accent`；滑块为白色圆点，直径 18。切换动画 150 ms。
- **滑块**（DSlider）：
  - 整个控件高 35，滑槽只有 2 px：已填充部分为 `accent`，未填充部分为白 × 0.2。
  - 滑块按钮是 12 px 白色圆点 〔派生〕。
  - 下方可加刻度注释（`DCCSliderAnnotated`），文字白 × 0.6。
- **文本输入**：高 30 〔派生〕，底色 `field`，圆角 5，白字。获得焦点时画 1 px `accent` 描边；出错时描边为 `alert`。
- **下拉框**：外观同文本输入，右侧有 ▾；弹出的列表用暗色菜单（§3.3），**不带箭头**。
- **按钮**（DDE 的 RoundedButton 样式）：
  - 圆角 15 的胶囊（这是第二处允许胶囊形的地方），底色白 × 0.2。悬停白 × 0.5，按下 `accent`。
  - 推荐操作按钮：文字为 `accent`。
- **单选 / 复选**（OptionItem）：整行可点，选中时右侧显示 `accent` 色的 ✓。DDE 不使用圆形单选框。
- **分隔线**：1 px，前景 × 0.15（`separator` 令牌）。
- **行高系数**〔演进〕：行高类令牌（`detailRowHeight`/`settingsRowHeight`/`launcherMiniRowHeight`/`dialogButtonHeight`/`sliderBasicHeight`/`settingsFieldHeight`）整体乘 `ui.rowHeightScale`（0.9–1.2，默认 1）。写死行高的组件不受控，新代码一律走令牌。
- **表面令牌边界**：设置页里的行、列表、嵌板一律来自叠加阶梯（`overlay`）或蒙版（`maskShell`）。方案染色只经由令牌层进入组件——**禁止**组件直接用 `mSurface`/`mSurfaceVariant`/`mOutline` 这类 Material 实色做行或卡片的填充：它们是**不透明**色（方案要供 GTK/终端模板用），跳过令牌的透明度处理后会在玻璃面上糊成实块。`m*` 实色只允许出现在两处：配色方案预览等"数据本身即颜色"的展示面，以及徽章/状态点的语义色。
- **列表页**（Wi-Fi 网络、蓝牙设备、插件、配色模板这类"可选多项"清单）：每一项就是一个 SettingsItem 行；选中/已连接态用右侧 `accent` ✓ 与状态文字表达，**不给整行换底色**；进行中用行内转圈；行内展开区（密码、详情）用 `overlay("field")` + `radiusItem` 嵌板，行尾接一个可点的"添加/新建"行。
- **堆叠子页**：`NTabView.stacked` 时每个子页 = 一个 NHeader + 一个 SettingsGroup。组头与它的组之间只有 1 px 缝，组与组之间 15 px——间距全部落在"上一组末行与下一组头"之间，头与组之间不再额外留白。
- **行内可展开的编辑器**：行本身（clickable + 右侧 chevron）负责开合，展开内容直接挂在行组内、跟随组缝排列，不自包实色容器。

### 3.6 通知气泡（dde-osd notification）

来源：`gxde-session-ui/dde-osd/notification/*`。

- **表面**：背景 `maskTransient`（默认 auto 跟随模式，规格见 §1.2；`light` 形态下为不透明 `#F8F8F8`），描边 `borderTransient`，圆角 8，阴影见 §1.6。
- 尺寸：基准 **300×70**。正文较长时允许增高，但最多显示 3 行。
- 位置：**屏幕右上角**，距离屏幕边缘 20 px（这是 DDE 15 原版行为，`bubblemanager.cpp` 的 `getY()`）。
  - 任务栏在顶部时，气泡排在任务栏下方；控制中心打开时，气泡排在控制中心左侧。
  - `notifications.location` 仍然可改；GXDE 默认的"右下角"作为一个可选项提供。
- 布局：
  - 应用图标 48×48，位于 (11, 11)。
  - 正文从 x=70 开始，宽 220；有动作按钮时宽 150。
  - 标题 `onTransient`、Medium；正文 `onTransientBody`；超出按行截断。
- 动作按钮：竖排在右侧，宽 70。文字 `transientAction`（浅色面上 = `accentAction`）；悬停时变为白字配按钮文字色实底。按钮之间用 1 px `overlayTransient("hover")` 分隔线。
- 动效：出现用 `motionBubbleIn`，消失用 `motionBubbleOut`（向右滑出）。
- 时长：普通通知 5000 ms；低优先级沿用 Noctalia 设置；紧急通知不自动消失。
- 堆叠：**默认同一时刻只显示一条**，其余排队（DDE 行为）。`notifications.maxVisible`（默认 1）可以调大，调大后多条气泡纵向堆叠，间距 10。
- 如果新通知的 `replacesId` 与已有通知相同，就原地更新那条气泡的内容。
- 吐司（Toast）：同样的浅色气泡，没有动作按钮；高度随内容；屏幕上方居中显示 〔派生〕。

### 3.7 OSD（dde-osd）

来源：`gxde-session-ui/dde-osd/container.cpp`、`common.cpp`。

- **方块**：背景 `maskTransient`（默认 auto 跟随模式，规格见 §1.2；`light` 形态下为不透明 `#F8F8F8`），圆角 10，阴影见 §1.6，描边 `borderTransient`。
- 尺寸 **140×140**。
- 位置：水平居中，方块底边距离屏幕底边 **180 px**。`osd.location` 仍然可以修改，但默认值改为 `"bottom_center"`。
- 内容：
  - 图标居中：只有图标时距顶 40，下面有文字时距顶 25，下面有进度条时距顶 30。图标着 `onTransient`（`light` 形态下为深色），字号 `osdIconSize`（48 pt ≈ 原版 64 px SVG 的墨迹量，`icons/OSD_*.svg`）。
  - 进度条：**80×4**，距顶 110，圆角 2。滑槽 `onTransientTrack`，已填充部分 `onTransient` 实色。
  - 音量超过 100% 时，在滑槽 2/3 处画两条 1×5 的刻度线（`onTransientTick`）。
- 键盘布局 OSD：竖向列表，宽度 = max(文字宽, 200) + 30，行高 = 字高 + 10，当前行底色 `overlayTransient("hover")`。
- 锁定键 OSD（大写/数字锁定）：只显示图标和文字。
- 出现和消失用 `motionOsdIn` / `motionOsdOut`。显示 1000 ms（`osd.autoHideMs` 默认改为 1000）。

### 3.8 关机界面（dde-shutdown）

来源：`gxde-session-ui/dde-shutdown/*`、`widgets/rounditembutton.cpp`。

- 覆盖整个屏幕，背景为模糊壁纸。
- 按钮横排一行，**垂直居中**，按钮间距 10。按钮顺序：关机、重启、待机、休眠、锁定、切换用户、注销；再加 Noctalia 独有的"重启到 UEFI"。按 `sessionMenu.powerOptions` 过滤和排序。
- 每个按钮（RoundItemButton）：
  - 尺寸 **140×140**。图标 **75×75**，图标下方 10 px 是文字（白色，可换行）。
  - 悬停或选中：黑色压暗块，圆角 10。不可用时整体透明度 0.5。
- 打开时默认选中"锁定"。
- 键盘：← / → 移动选中，Enter 执行，Esc 取消。Noctalia 的数字快捷键（1–7）保留，数字显示在按钮文字后面，颜色白 × 0.6。
- 点击空白处取消。
- 倒计时（`sessionMenu.enableCountdown`）：在按钮行下方 40 px 处显示一行白色文字，例如"将在 N 秒后关机"。按任意键取消倒计时。
- 有程序阻止关机（inhibitor）时，按钮行换成警告视图：列出程序名和原因；下面是"仍然关机"（`accent` 文字）和"取消"两个按钮。
- `sessionMenu.position`、`largeButtonsStyle`、`showHeader` 等 Noctalia 原有布局选项，都放到"高级"下；默认值对应上面的 DDE 布局。

### 3.9 锁屏（dde-lock）

来源：`gxde-session-ui/dde-lock/*`、`session-widgets/*`、`widgets/*`。

- 背景：模糊壁纸（`general.lockScreenBlur` 默认改为启用）。
- 窗口底部有一条高 132 的区域，上下各留 33 px 边距：
  - **左下**：时间，68 px Light 白色，左对齐，左边距 48。时间下方是日期，16 px，格式 `yyyy-MM-dd dddd`。
  - **右下**：一排控制按钮，间距 26，右侧留 60：
    - 媒体控制（MPRIS，可选）
    - 键盘布局
    - 切换用户
    - 电源。电源按钮会在锁屏内打开 §3.8 的按钮行；此时密码区隐藏。
- 中央，从上到下：
  - 头像：**100 px 圆形**，无描边。
  - 用户名：16 px 白字，在头像下方 25 px。
  - 用户名下方 20 px 是密码框：**280×36**，底色 `field`，圆角 6，白字。右侧嵌着解锁图标按钮。
  - 这一整块的垂直位置，以"屏幕高度减去 132 px 底部区域"后的剩余空间为准居中。
- 密码错误：密码框描边变为 1 px `alert`；框下方弹出一个白底提示（文字 `alert`），并带一个指向密码框的箭头。
- 大写锁定开启时，密码框内左侧显示一个提示图标。
- 认证进行中：在密码框内显示一个白 × 0.35 的加载动画。
- 指纹（`allowPasswordWithFprintd`）：密码框里的占位文字显示"验证指纹或输入密码"。
- Noctalia 锁屏上的天气、电池、倒计时等附加信息：以白 × 0.8 的小号文字放在时钟右侧；默认关闭。
- Noctalia 的紧凑锁屏布局（`general.compactLockScreen`）在 DDE 中没有对应物：字段保留为兼容数据但不生效，不提供设置项。

### 3.10 壁纸选择〔派生〕

- 参考仓库中没有 dde-desktop 的壁纸选择器，以下按 DDE 15 的总体规则设计。
- 一条贴住屏幕底边的横条，背景 `maskDark`，高约 160。
- 缩略图 16:9、宽 160，间距 10，横向滚动。
  - 当前壁纸：外圈 2 px `accent` 描边。
  - 悬停的缩略图：在下方叠出"当前外观 / 另一外观 / 都设置"三个按钮（按钮样式同 §3.5.4）。本 shell 没有独立的锁屏壁纸目标——`LockScreenBackground` 复用桌面壁纸的预模糊缓存，`WallpaperService.changeWallpaper` 的外观槽只有 `"light"`/`"dark"` 两个取值（`WallpaperService.qml:422-424`）——所以三按钮落在亮/暗外观槽上，结构与原版"仅桌面/仅锁屏/都设置"一致。若将来引入锁屏壁纸写入路径，再改回原三按钮语义。
- 顶部一行（目录、Wallhaven 来源、搜索）按 §3.5.4 的控件样式绘制。

### 3.11 对话框（DDialog）

- 暗色：背景 `maskDark`，圆角 8，阴影 20。
- 宽 380（polkit 对话框的最大宽度，`AuthDialog.cpp:277`），内容多时最大 640。
- 左上 48 px 图标，标题 Medium，正文白 × 0.8。
- 底部按钮行横跨对话框全宽，按钮之间用 1 px 白 × 0.1 的分隔线隔开；推荐操作按钮的文字为 `accent`。
- 首次设置向导：模糊壁纸背景，中间是上述对话框（宽 640），底部用分页圆点表示步骤，右下角是"下一步"按钮。
- （可选）Polkit 认证：Quickshell 提供 Polkit 服务时，按 `gxde-polkit-agent/AuthDialog.cpp` 实现。包含 48 px 应用图标、有多个身份时显示身份下拉框、高 24 的密码框；密码错误时输入框显示 `alert` 状态，并在其下方弹出错误提示。

### 3.12 桌面挂件

- DDE 15 没有桌面挂件，这里按 DDE 的通用规则处理：卡片背景 `maskDark`，圆角 8，不加阴影。文字规格同 §1.5。
- 时钟挂件采用控制中心时钟的样式（46 px Light）。
- 拖拽时只用白 × 0.1 的描边表示可放置区域，不要发光效果。

### 3.13 状态栏〔nosd 扩展〕

- DDE 15 本体没有状态栏；本条是借 Noctalia 的 bar 管线提供的可选扩展，定位类似 macOS 的菜单栏（显示系统信息与全局挂件，不承担窗口任务列表）。
- **仅时尚模式可用**：高效模式下任务栏本身就是通栏条，状态栏不再出现；切换模式时自动失效/恢复，不需要用户重选。
- 开关：`bar.enabled`（默认关）。位置：`bar.position`（默认 `top`），独立于 `dock.position`；显示器选择走 `bar.monitors`（空 = 全部）。显示模式走 `bar.displayMode`（`always_visible` / `auto_hide`，沿用 `bar.autoHideDelay` / `bar.autoShowDelay` / `bar.showOnWorkspaceSwitch`）。
- 挂件内容：`bar.widgets` 三段式布局（默认左侧启动器/时钟/系统监视器/活动窗口/迷你媒体，中间工作区，右侧托盘/通知/电量/音量/亮度等）。
- 语义拆分：`getBarPositionForScreen()` 指**bar 窗口所在边**（时尚+状态栏时 = `bar.position`，否则 = 任务栏边）；`getTaskbarPositionForScreen()` 恒指任务栏/dock 边（启动器定位、屏覆盖编辑器、避让判断用它）。挂件弹层跟随其宿主表面：dock 区挂件弹层用任务栏边，bar 区挂件弹层用状态栏边。
- 状态栏与 dock 允许同边（dock 悬浮居中会叠在状态栏上方），建议错开摆放。
- 自动隐藏时状态栏收进屏幕边缘，贴边悬停触发区唤出；常驻时 `BarExclusionZone` 为它保留空间（同任务栏规则）。
- 视觉：沿用 §3.5 的面板体系（`Color.maskShell` 底、无阴影、圆角按 `bar.barType`）；与任务栏同屏时不额外加描边或发光。

---

## 4. 工具：`nosd-blur`（Rust）

- 作用：对应 deepin 的 `com.deepin.daemon.ImageBlur`，为全屏界面生成**预模糊壁纸**。原因：QML 的 `MultiEffect` 最大只能模糊 64，强度不够；每帧全屏实时模糊也太费资源。
- 位置：`tools/nosd-blur/`（Cargo 项目）。
- 命令行：`nosd-blur <src> <dst> --width W --height H [--sigma S]`。
  - 处理流程：按 cover 方式缩放并居中裁切 → 做近似高斯的三次 box blur → 写出 PNG 或 JPEG。
  - 进程退出码 0 表示成功。
- 调用方式：由 `ImageCacheService` 调用。
  - 缓存键 = 源路径 + 修改时间 + 尺寸 + sigma 的哈希；缓存目录为 `Settings.cacheDir + "blur/"`。
  - 找不到 `nosd-blur` 时，退回 `MultiEffect` 实时模糊，并输出一次警告日志。
- sigma：屏幕短边的 3%（1080p 约为 32）〔派生〕；`wallpaper.blurSigma` 为正数时改用该固定值〔演进〕。deepin 原版的 `image-blur-helper` 参数没有包含在参考仓库中。

### 4.1 `nosd-helpers wl-probe`

- 作用：探测当前 Wayland 合成器公布的全局接口，供 §1.2 判断"合成器是否支持模糊"。QML 侧拿不到注册表，Quickshell 在不支持时只打印一行警告。
- 命令行：`nosd-helpers wl-probe`，向 stdout 输出一行 JSON：`{"compositor_blur": true|false, "globals": ["wl_compositor", ...]}`；`compositor_blur` 为真当且仅当存在 `ext_background_effect_manager_v1`。连不上 Wayland 时退出码非 0。
- 调用方式：shell 启动时调用一次，结果存进 `CompositorService.blurSupported`；`Color.blurActive` = 设置开启 且 `blurSupported`。工具缺失或执行失败时按"支持"处理（保持旧行为），并输出一次 `Logger.w`。

---

## 5. 配色方案

- 新增预设方案 `Assets/ColorScheme/Deepin/Deepin.json`，并设为默认（`colorSchemes.predefinedScheme = "Deepin"`）。
  - 暗色：`mPrimary #2CA7F8`、`mOnPrimary #FFFFFF`、`mSecondary #01BDFF`、`mOnSecondary #FFFFFF`、`mTertiary #0087FF`、`mOnTertiary #FFFFFF`、`mError #F9704F`、`mOnError #FFFFFF`、`mSurface #181818`、`mOnSurface #FFFFFF`、`mSurfaceVariant #2A2A2A`、`mOnSurfaceVariant #B4B4B4`、`mOutline #3A3A3A`、`mShadow #000000`、`mHover #2CA7F8`、`mOnHover #FFFFFF`。
  - 浅色：强调色相同；`mSurface #F8F8F8`、`mOnSurface #303030`、`mSurfaceVariant #EBEBEB`、`mOnSurfaceVariant #6B6B6B`、`mOutline #D5D5D5`、`mShadow #000000`。
  - 方案中的颜色**一律不透明**，因为模板（GTK、终端）要直接使用这些颜色，尚未改造的组件也会把 `mSurfaceVariant` 当作实色来画。DDE 的半透明表面只从 §1.2 和 §1.3 的令牌获得。
- **表面令牌读取配色方案的表面角色**〔演进：原为只看明暗模式〕：蒙版取 `mSurface`、弹出层取 `mSurfaceVariant`、描边取 `mOutline`、壳上前景和叠加阶梯取 `mOnSurface`、`alert` 取 `mError`、禁用文字按 MD3 规则 = `onSurface` × 0.38。切换方案或壁纸取色时，表面色调、文字色相、状态层、错误色全部随方案走——这是方案染色可定制性的完整落点。Deepin 方案的这些角色被刻意设成 DDE 15 的值（`#181818`/`#2A2A2A`/`#3A3A3A`/`#FFFFFF`/`#F9704F`），所以默认观感不变。例外仍是固定签名：壁纸面的恒白阶梯、强制反向模式时的瞬时经典值、浅色菜单的固定浅色调色板（`popupLight*`）、分隔槽的刻线对、以及 §6 的强调色行为。
- **`ui.accentOverride`**（默认空）〔演进〕：非空且为合法颜色时，`Color.mPrimary` / `mSecondary` / `mTertiary` / `mHover` 四个强调色角色一律取覆盖色（`Color.qml` 里方案值存 `_​*Raw`，公开 m* 令牌随覆盖解析），各 `mOn*` 对应色按覆盖色亮度取白或 `#303030`；`accent` / `accentAlt` / `accentAction` / `onAccent` 语义令牌仍是 m* 的别名，所以直接读 `mPrimary` 的组件（进度环、滑块、勾选态）同样跟随。`mError` 与表面系令牌不受影响；GTK/终端模板读方案 JSON 生成、不经 `Color.qml`，照常按方案出。副作用：设置页里"当前方案"预览条显示的是生效色（即覆盖色），各方案的候选色板仍显示方案自带颜色。
- 模板功能（GTK、终端等配色文件的生成）照常使用当前方案的完整颜色。

---

## 6. 设置与兼容

- 新增或修改设置时，四处同步改：
  - `Assets/settings-default.json`
  - `Commons/Settings.qml`（JsonAdapter）
  - 新建迁移文件 `Commons/Migrations/MigrationNN.qml`，并登记到 `MigrationRegistry`，同时递增 `settingsVersion`
  - 运行 `Scripts/test/build-settings-search-index.py`
- 主要默认值变化：

| 设置 | 新默认值 |
|---|---|
| `dock.mode` | `fashion` |
| `dock.position` | `bottom` |
| `dock.iconSize` | 36 |
| `dock.hideMode` | `keep-showing` |
| `appLauncher.mode` | `fullscreen` |
| `appLauncher.displayMode` | `free` |
| `appLauncher.iconRatio` | 0.5 |
| `ui.panelBackgroundOpacity` | 0.4 |
| `ui.settingsPanelMode` | `controlCenter` |
| `ui.panelsAttachedToBar` | `false` |
| `osd.location` | `bottom_center` |
| `osd.autoHideMs` | 1000 |
| `notifications.location` | `top_right` |
| `notifications.maxVisible` | 1 |
| `general.showScreenCorners` | `false` |
| `general.lockScreenBlur` | 启用 |
| `colorSchemes.predefinedScheme` | `Deepin` |
| `bar.enabled` | `false`（可选状态栏，§3.13） |
| `ui.transientSurface` | `"auto"`（`light`/`dark`/`auto`，§1.2）〔演进〕 |
| `ui.transientOpacity` | `1.0`（0.3–1.0，瞬时面不透明度，§1.2）〔演进〕 |
| `ui.borderEmphasis` | `1.0`（0–2，描边强度，§1.2）〔演进〕 |
| `general.shadowStrength` | `1.0`（0–2，阴影强度，§1.6）〔演进〕 |
| `ui.rowHeightScale` | `1.0`（0.9–1.2，行高系数，§3.5.4）〔演进〕 |
| `ui.accentOverride` | `""`（合法颜色时覆盖强调色系，§5）〔演进〕 |
| `wallpaper.blurSigma` | `0`（0 = 自动 = 短边 3%，正数为固定 px，§4）〔演进〕 |

- `ui.settingsPanelMode`：设置面板固定为控制中心模式，选择器已移除；字段仅作兼容数据保留（Migration72 会把旧值钉回 `controlCenter`）。
- 旧配置的迁移：
  - `bar.widgets` → `dock.plugins`
  - `bar.position` → `dock.position`
  - 原来启用了 Bar 的用户 → `dock.mode = "efficient"`
  - `bar.barType` 的 `framed` / `floating` → 保留数值，但不再生效
- 迁移不能丢失用户数据。用不上的旧字段原样保留，不删除。

### 6.1 上游功能移除清单

以下 Noctalia v4 能力被有意移除，逐项记录理由（对应 AGENTS.md 的业务保真规则：删除上游功能必须有明确依据并登记于此）：

| 移除项 | 理由 |
|---|---|
| `Services/Noctalia/UpdateService.qml` 应用内更新检查、`Panels/Changelog` 更新日志弹窗、`general.showChangelogOnStartup` | nosDshell 经 Guix 打包分发，更新统一走系统包管理器；应用内更新检查会引导用户绕过包管理。版本信息仍在"关于"页展示 |
| `Services/Noctalia/TelemetryService.qml` 遥测 | 隐私考量，fork 不向外部服务上报使用数据 |
| `Services/Noctalia/GitHubService.qml`、`SupporterService.qml`、About 页的 Contributors/Supporters 子页 | 服务于上游 noctalia 项目的贡献者与赞助展示；fork 不应继续以该名单代表自己。配色方案下载不依赖它们（SchemeDownloader 直连 colorschemes 仓库） |
| Talia 天气吉祥物（`weatherTaliaMascotAlways` 等） | noctalia 品牌资产，随重命名移除 |
| `Panels/NotificationHistory` 独立弹窗 | 并入控制中心通知页（§3.5.2），键盘操作模型已随 `NotificationHistoryList` 保留 |
| `~/.config/noctalia` → `~/.config/nosdshell` 旧配置目录自动搬迁 | 不做。nosDshell 是独立 shell 身份而非 noctalia 的就地升级；MigrationNN 管线负责 nosdshell 自身配置的键级演进 |

---

## 7. 禁止清单

以下做法与 DDE 15 冲突，评审时一律退回：

- 胶囊形外观（开关和圆角按钮除外）、超过 10 px 的圆角、Material 风格的彩色表面、水波纹、按压时的缩放、弹簧或回弹动画。
- 弹出层和栏融合在一起、反向圆角、外圆角、框架式栏（framed bar）——仅保留为默认关闭的兼容选项。
- 用彩色区分状态（例外：活动项 `accent`、请求注意 `attention`、错误 `alert`）。
- 加粗（Bold / ExtraBold）；全大写的标题；字间距不为 0 的正文。
- 在一个界面里同时出现两个强调色；用渐变给表面着色。
- 复制 `references/` 的素材或代码却不留出处：没有放进 `Assets/DDE/<仓库>/`、缺少 `NOTICE`、提交说明里没有写来源路径。
- 用 Tabler 字形或 QML 近似重画参考仓库里已有原件的 DDE 专属素材（见 §1.9）。
- 在组件里写死颜色、尺寸或时长，绕过令牌。
