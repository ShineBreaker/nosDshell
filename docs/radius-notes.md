# DDE 1–3px 微圆角考据（radius-notes）

- 对象：`nosd-theme` 的 GTK 3/4 主题（`deepin/`、`deepin-dark/`）里那 160 条 `border-radius` 漂移
- 上游：https://github.com/GXDE-OS/deepin-gtk-theme ，本次核对版本 `b7eef58`（2026-10-12 "add: Arch build"）
- 本仓基线：`e1e223b`（radius 调和前）
- 日期：2026-11-13

## 状态

partial

结论（1–3px 从哪来、意图是什么、归位是否违背上游）已经由上游 git 历史 + DTK/Adwaita 源码双向核对得出，可复核。未闭环两项：GXDE/deepin 没有公开的设计规范文档说明圆角取值理由（只能从代码反推）；未做真机像素级截图比对（属 Reviewer 的截图验收范围）。

## 执行摘要

1–3px 微圆角不是 DTK 的 `PM_FrameRadius` 像素对齐 hack，也不是 DDE 设计令牌的落地产物：它们是 **2016-06-23 移植 Adwaita 3.20 时，把 Adwaita 的圆角整体收缩（5/7/3 → 4/4/2.5）后留下的手写字面值**，此后十年没再动过（2017 只做过一次全文件格式化）。上游没有 SCSS、没有生成管线、没有一行注释解释半径取值。因此"归位到 4/5/6/8/10"**不违背上游的设计意图**——上游的意图只是"比 Adwaita 更紧"，而 4/5/6/8/10 是同一意图在 Qt/DDE 应用层的另一套刻度；但它确实会改变两处真实视觉（notebook 页签、对话框动作区），且对话框那组必须三处同改，否则会造出"按钮 8px 圆角 + 窗口底边 0px"的新矛盾。

## 信息来源

| 来源 | 类型 | 日期 | 可靠性 |
|---|---|---|---|
| deepin-gtk-theme 仓库历史（`git clone` 后 `git log -L` / `git blame`，HEAD `b7eef58`） | 官方（上游代码） | 2026-10-12 | 高，可复现 |
| commit `e3a5e9d` "add gtk3.20 support"（deepinzhangshuang） | 官方（上游代码） | 2016-06-23 | 高 |
| commit `5e84c3c` "add 3.18 theme."（leaeasy） | 官方（上游代码） | 2015-10-12 | 高 |
| commit `6140502` "formating all css files"（shule1987） | 官方（上游代码） | 2017-06-19 | 高 |
| Adwaita `gtk-contained.css`（GNOME gtk tag 3.18.0 / 3.20.0 / 3.22.0，raw.githubusercontent.com） | 官方（上游代码） | 2016-03 / 2016-09 | 高 |
| dtkwidget `src/widgets/dstyle.cpp`（6.7.53） | 官方（DTK 源码） | 2026-11-10 | 高 |
| dtkgui `src/plugins/platform/xcb/dxcbplatforminterface.cpp`（6.7.53） | 官方（DTK 源码） | 2026-11-10 | 高 |
| gxde-desktop-schemas `schemas/com.deepin.xsettings.gschema.xml`（4.0.8） | 官方（GSettings schema） | 2026-10-17 | 高 |
| 本仓 `nosDshell/DESIGN.md` §1.4（引用 DDE 应用源码行号） | 内部文档（二手汇编） | — | 中：结论可用，但它是从 DDE 应用源码摘的，不是官方设计规范 |
| 网络搜索 | 媒体/社区 | 2026-11-13 | 低：本次 bing 后备通道返回结果与主题无关（见"风险与限制"），未采信任何搜索结果 |

复现路径（全部只读，不依赖网络以外的东西）：

```bash
git clone https://github.com/GXDE-OS/deepin-gtk-theme.git /tmp/dgt && cd /tmp/dgt
git show e3a5e9d:deepin/gtk-3.0/gtk.css | grep -c 'border-radius: 2.5px'   # 4
git show 5e84c3c:Deepin/gtk-3.0/gtk-widgets.css | grep -o 'border-radius:[^;]*' | sort | uniq -c
git blame -L 3049,3049 --date=short -- deepin/gtk-3.0/gtk.css               # 6140502 2017-06-19
# DTK 侧
git clone --depth 1 https://github.com/linuxdeepin/dtkwidget.git
sed -n '1645,1665p' dtkwidget/src/widgets/dstyle.cpp
```

## 关键发现

1. **微圆角来自 2016 年的 Adwaita 3.20 移植，且是"整体收缩"而非"像素对齐"。**
   - 2015-10-12 `5e84c3c`（3.18 移植）的基数是 **3px**（51 处），与 Adwaita 3.18 的 3px 基数一致；窗口是 `3px 3px 0 0`。
   - 2016-06-23 `e3a5e9d`（3.20 移植）把基数换成 **4px**（36 处），窗口 `4px 4px 0 0`，同时出现 `2.5px`（4 处）、`1.5px`、`1px`、`20px`、`100px`。同期的 Adwaita 3.20 基数是 **5px**、窗口 **7px**、滑块槽 **3px**、键帽 **5px**、日历选中 **3px**。
   - 也就是说：Adwaita 3.20 → deepin 3.20 是 5→4、7→4、3→2.5、5→2.5、3→1.5，全线缩小 20%–50%。这是"让 GTK 应用看起来像 DDE"的整体收紧，与 DTK 的 6/8 无关（数值也对不上）。
   - 来源：`git show e3a5e9d:deepin/gtk-3.0/gtk.css`；Adwaita `https://raw.githubusercontent.com/GNOME/gtk/3.20.0/gtk/theme/Adwaita/gtk-contained.css`

2. **上游没有生成管线，圆角是手写字面值，没有任何注释或提交信息解释取值。**
   - 仓库里没有 `.scss/.sass`（`git log --all -- '*.scss'` 为空），`Makefile` 只做 `cp -r deepin/`，无替换脚本。
   - `CHANGELOG.md`、`README.md` 全文没有 "radius"/"圆角" 字样。
   - 因此任何"上游刻意用 1px 是为了对齐 1px 描边"之类的说法都无法从上游得到证实——只能从 CSS 结构反推（见第 4 条）。

3. **`border-radius` 行号的 blame 会误导，必须看内容。**
   - 20 条里的绝大多数 `git blame` 指向 `6140502`（2017-06-19 "formating all css files"，单次改动 18795 行），但**数值在 2016 年的导入里就已经是这个值**（已用 `git show e3a5e9d:...` 逐条验证：`scale trough` 2.5px、`calendar:selected` 1.5px、`notebook tab` 1px 1px 0 0、`messagedialog` 0 0 3px 0、`.keycap` 2.5px、`entry.search` 20px、`.help_button` 100px、`decoration` 4px 4px 0 0 全部在 2016 年已存在）。
   - 结论：这批值是"移植时的既定值"，2017 年之后 GXDE/deepin 侧再未对它们做过任何设计性调整（2022–2026 的 CSS 提交 `0c1a4b3`、`ad50fb4`、`81d3660` 均未触及 `border-radius`）。

4. **少数微圆角有几何自洽的解释，但都不构成"必须保留"的理由。**
   - `scale trough/highlight/fill: 2.5px`：槽高约 5px（`scale { min-height: 15px }` + `padding: 3px`，2.5px 恰为半高），写法是"半高即胶囊"。同一块里 `-gtk-outline-radius: 4.5px` 与 `border-radius: 2.5px` 不一致，说明这个数不是算出来的，是抄改留下的。
   - `notebook tab: 1px 1px 0 0`：Adwaita 3.20 的页签**没有**圆角（方页签）；deepin 加 1px 是为了"页签在 1px 描边的 notebook 框上不露出直角毛刺"，属装饰性微调，不是对齐计算。
   - `messagedialog action area: 0 0 3px 0`：Adwaita 3.20 是窗口 `7px`、对话框内层背景底角 `9px`、动作区按钮 `0`；deepin 改成窗口 `4px`、背景底角 `3px`、按钮底角 `3px`。这是"内层曲面跟随窗口角"的语义，但**上游自己就没对齐**（4px 的窗口配 3px 的内层，而窗口底边是 0）。
   - 来源：`deepin/gtk-3.0/gtk.css`（`git show HEAD:` 行号 3049/3082/3089、2474–2519、3526–3547、4047、188、5082）。

5. **DTK 侧的"官方半径"是 6/8，不是 4/5/6/8/10。**
   - `dtkwidget/src/widgets/dstyle.cpp:1650` `PM_FrameRadius` → `DSizeModeHelper::element(6, 8)`（紧凑模式 6、普通模式 8；`element(t1,t2)` = compact ? t1 : t2，见 `include/util/dsizemode.h:18`）。控件圆角走这个值。
   - `dstyle.cpp:1660` `PM_TopLevelWindowRadius` → **18**，被 `DArrowRectangle`（带箭头弹出层，`darrowrectangle.cpp:253`）和 `DFloatingWidget`（`dfloatingwidget.cpp:157,239`）使用。这是当前 DTK 6.7.53 的值，比 DESIGN §1.4 给"带箭头弹出层"的 6px 大得多。
   - `dstyle.cpp:1647` `PM_FocusBorderWidth` → 2（对比 tokens.toml 的 `focus_width = 1.5`，两者也不同源）。
   - 顶层窗口圆角另有一条通路：xsettings `dtk-window-radius`（`gxde-desktop-schemas/schemas/com.deepin.xsettings.gschema.xml:384`，`<default>8</default>`），由 dde-daemon 发布、dtkgui 以 `DTK/WindowRadius` 读取（`dxcbplatforminterface.cpp:179`），写入走 `:703`。
   - 所以 DDE 自己就有两套口径：**控件 6/8（DTK 样式）+ 窗口 8（xsettings）+ 箭头弹出层 18（DTK 6.x）**。DESIGN §1.4 的 4/5/6/8/10 是把 DDE 应用源码（launcher/dock/control-center 等）里出现的半径归档成 5 档，不是 DTK 的常量表。

6. **GTK 主题与 DTK 之间没有任何数值耦合。**
   - 上游 CSS 里没有引用 `dtk-window-radius`、没有读取 xsettings 的脚本，窗口圆角纯粹由 CSS 的 `decoration { border-radius: 4px 4px 0 0 }` 决定。
   - 也就是说：nosd 主题下 GTK 应用（Firefox、GNOME 系）窗口角 4px，Qt/DDE 应用窗口角 8px，**这个跨工具包差异今天就存在**，不是本次调和造成的，也不会被本次调和消除。

## 对比与矩阵

### 时间线

| 时间 | 事件 | 基数 | 窗口角 | 滑块槽 | 键帽 | 日历选中 |
|---|---|---|---|---|---|---|
| 2015-10-12 | `5e84c3c` 3.18 移植（leaeasy） | 3px | `3px 3px 0 0` | 3px | 3px | 3px |
| 2016-06-23 | `e3a5e9d` 3.20 移植（deepinzhangshuang） | **4px** | **`4px 4px 0 0`** | **2.5px** | **2.5px** | **1.5px** |
| 2017-06-19 | `6140502` 全文件格式化 | 不变 | 不变 | 不变 | 不变 | 不变 |
| 2022–2026 | GXDE 期 CSS 提交 3 次 | 不变 | 不变 | 不变 | 不变 | 不变 |
| 同期 Adwaita 3.20 | GNOME 官方 | 5px | `7px 7px 0 0` | 3px | 5px | 3px |

### 20 条漂移的逐条对照（`deepin/gtk-3.0/gtk.css`，`git show HEAD:` 行号；其余 7 个文件同构）

| # | 选择器 | 上游值 | Adwaita 3.20 | 语义 | 现映射 | 评估 |
|---|---|---|---|---|---|---|
| 1 | `entry.search` | 20px | 无此选择器 | 头部搜索框（胶囊） | 5px（radiusItem） | 合理。DESIGN §1.4 明确"搜索框 5px"，且 §4 明确不要胶囊形 |
| 2 | `spinbutton:not(.vertical):dir(rtl) button.up` | `4px 0 0 3px` | `3px 3px 0 0` | 数值框上下按钮外角 | `4px 0 0 4px` | 合理，顺手修掉上游 4/3 混用 |
| 3 | `spinbutton.vertical button.up` | `4px 3px 0 0` | `3px 3px 0 0` | 同上 | `4px 4px 0 0` | 合理 |
| 4 | `.inline-toolbar` | `0 0 3px 3px` | 无 radius | 内联工具条底角 | `0 0 4px 4px` | 合理 |
| 5–8 | `notebook > header.{top,bottom,right,left} > tabs > tab` | `1px 1px 0 0` 等 | **无 radius（方页签）** | 页签外角 | `4px 4px 0 0` 等 | **视觉改动最大的一处**：近方页签变 4px 圆角。语义上 4 是 radiusRow（列表行/导航），页签没有更近的档；需截图确认不与 notebook 1px 描边框咬合出缝 |
| 9–11 | `scale trough/highlight/fill` | 2.5px | 3px | 滑块槽 | 5px | 低风险：槽高约 5px，GTK 会把半径钳到高度一半，渲染结果与 2.5px 等同（钳制行为属 GTK 实现规则，本次未渲染实测） |
| 12 | `.app-notification` | `0 0 2px 2px` | 无此选择器 | 应用通知气泡 | `0 0 8px 8px` | 合理（radiusWindow=通知气泡） |
| 13 | `calendar:selected` | 1.5px | 3px | 日历选中格 | 4px | 合理（无更近语义档，4=radiusRow） |
| 14–16 | `messagedialog.csd .dialog-action-area button{:last-child,:first-child,:only-child}` | `0 0 3px 0` 等 | 动作区按钮 `border-radius: 0` | 对话框动作区底角 | `0 0 8px 0` 等 | **需配套**：`decoration` 底角是 0、`messagedialog.csd.background` 底角仍是 3px（见下节），单独把按钮抬到 8px 会戳出框底 |
| 17 | `.keycap` | 2.5px | 5px | 键帽 | 4px | 合理 |
| 18 | `.gedit-search-slider` | `0 0 2px 2px` | 无此选择器 | gedit 搜索条（弹出层） | `0 0 5px 5px` | 可接受；按弹出层语义用 6（radiusPopup）更贴 DESIGN |
| 19 | `.nautilus-window .floating-bar` | `4px 2px 0 0` | 无此选择器 | 文件管理器浮动条 | `4px 4px 0 0` | 合理 |
| 20 | `.help_button` | 100px | 无此选择器（Granite） | 帮助按钮胶囊 | 豁免 | 合理，但注意同文件 `5275` 行还有一条 `.help_button { border-radius: 0 }` 覆盖它——被豁免的 100px 其实是死代码，可考虑直接删 |

### 对话框三处必须同组

| 位置 | 上游 | 现状态 | 语义应取 |
|---|---|---|---|
| `decoration`（窗口框） | `4px 4px 0 0` | `4px 4px 0 0`（未改） | 按 DESIGN「对话框 = dtk-window-radius = 8」→ 应为 `8px 8px 0 0` |
| `messagedialog.csd.background`（内层背景底角） | `3px`（长写 `border-bottom-*-radius`） | `3px`（未改） | 跟随窗口底角，即 8 或 0 |
| `.dialog-action-area button` 底角 | `0 0 3px 0` | `0 0 8px 0`（已改） | 跟随窗口底角 |

上游这组本身就没对齐（4px 窗口 + 3px 内层 + 3px 按钮），是从 Adwaita 的 7px/9px/0 收缩时留下的。现方案只动了第三处，等于把"内层跟随窗口"的意图落实了一半。

### checker 的盲区：长写圆角属性

`scripts/check-tokens.py` 的正则是 `border-radius\s*:`，**只匹配简写**，`border-bottom-left-radius` 这类长写完全不在检查范围。每个 gtk css 文件里有 38 条长写圆角，8 个文件合计 304 条，其中 2px（80）、3px（64）、2.5px（64）都在令牌集合外：

| 选择器（`deepin/gtk-3.0/gtk.css`） | 值 | 说明 |
|---|---|---|
| `colorswatch.*` / `colorswatch.* overlay` | 2.5px / 2px | 取色器色块，16 条 |
| `#content_frame` | 2px | 内嵌内容框 |
| `#buttonbox_frame` | 3px | 按钮盒框 |
| `messagedialog.csd.background` | 3px | 对话框内层底角 |
| `.nemo-window .primary-toolbar widget.raised.linked…` | 3px | Nemo 工具栏按钮组 |
| `headerbar:first-child:backdrop` | 4px | 已合规 |

所以"160 → 0 告警"只覆盖了简写那一半；剩下 304 条长写要不要一起归一，是阶段 1 需要明确的口径（见"建议后续"）。

## 风险与限制

- **搜索通道不可用**：本次 `web_search` 走 bing 后备通道，返回的是与主题无关的新闻（微软宕机、deepin 官网首页），未采信任何搜索结果；所有结论均来自 `git clone` + 源码直读，可离线复核。
- **没有官方设计文档**：GXDE/deepin 没有公开说明"为什么是 4px/2.5px"。本文件的"意图"是从代码差异反推的（Adwaita 3.20 → deepin 3.20 的全线收缩），不是引用设计规范。
- **DTK 18px 是当前版本口径**：`PM_TopLevelWindowRadius = 18` 出自 dtkwidget 6.7.53（2026-11-10）。旧版 DDE 的箭头弹出层是 6px（DESIGN §1.4 引的是应用源码），两者不冲突但要区分：这是**版本差异**，不是 1–3px 微圆角问题。若哪天要跟当前 DTK 对齐，10px 上限的令牌表需要重新讨论。
- **未做渲染实测**：滑块槽"5px 等效 2.5px"依赖 GTK 的半径钳制规则，属实现行为推断，需 Reviewer 的 widget-factory 截图确认。
- **跨工具包差异不会被消除**：GTK 窗口角与 Qt 窗口角不同源，本次调和只统一了 GTK 内部，GTK 4px vs Qt 8px 的窗口角差异仍在。

## 未能核实清单

- **GXDE/deepin 官方圆角规范**：试过仓库 README/CHANGELOG 全文检索（无 "radius/圆角"）、web_search（通道被污染）。结论只能从代码反推。要闭环需 GXDE 团队的设计文档或 issue，目前公开渠道没有。
- **`e3a5e9d` 移植时是否有口头/邮件层面的收缩理由**：提交信息只有 "add gtk3.20 support"，无 Change-Id 之外的说明；旧仓库（deepin 时代 Gerrit）的评审记录未找到公开镜像。
- **`.help_button` 100px 是否真的会渲染成胶囊**：同文件后段有 `border-radius: 0` 覆盖，实际生效值为 0；未起应用实测。
- **1px notebook 页签在 1px 描边框上的真实像素效果**：需截图比对，属 Reviewer 范围。

## 建议后续

1. **对话框整组一起改**（给 Worker/Reviewer 的具体动作）：`decoration`、`messagedialog.csd.background`（长写 `border-bottom-*-radius`）、`.dialog-action-area button` 三处取同一个值。要么全 8（按 DESIGN「对话框 = dtk-window-radius = 8」），要么全 4（按 radiusRow 保守方案）；现在的"窗口 4 / 内层 3 / 按钮 8"是三种值。
2. **checker 补长写属性**：把正则扩成 `border(-(top|bottom)-(left|right))?-radius`，再决定 304 条长写是归一还是进 `[radius.exempt]`。否则"0 告警"这个验收口径不完整。
3. **截图重点看三处**：notebook 页签（1px→4px 改动最大）、对话框底角（8px 按钮 vs 0px 框底）、取色器色块（长写 2.5/2px 未动，与已归一的相邻控件是否出现"一半圆一半方"）。
4. **`entry.search` 保持 5px**：DESIGN §4 明确不要胶囊形，20px 不应进豁免表。
5. **`.help_button` 的 100px 可直接删**（被后段 0 覆盖的死代码），豁免条目留着也无害。
