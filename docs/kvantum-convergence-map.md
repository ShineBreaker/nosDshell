# Kvantum → deepin GTK 收敛映射表（施工图）

> 用途：把 `kvantum/nosd/`（KvAdapta 底子）收敛到 `deepin/`+`deepin-dark/`（DDE 视觉）的同一张脸。
> 读者：Worker（照表改 `nosd.svg.tpl` 与 `nosd.kvconfig`）。
> 依据：`nosDshell/DESIGN.md` §1.1–§1.6（令牌权威）、`tokens.toml`（形状/几何机器可读值）、`deepin/gtk-3.0/gtk.css`（GTK 实测值）、`tools/nosd-theme/src/theme.rs`（可用占位符全集）。
> 作者：Researcher｜日期：2026-11-13｜基线：`nosd-theme` HEAD `c97d13b`

## 状态

**ready** —— 映射表完整，可直接施工。三条结构性前置（§四）必须先做，否则改了也不生效。
两处需要 Worker 用 `kvantumpreview` 实测标定，已在表里标「待标定」。

## 一、差距总览

| 层面 | 现状 | 差距 |
|---|---|---|
| 颜色 | SVG 里 47 个唯一 hex，占位符只有 **2 个**（`primary` ×41、`primary_container` ×8） | 其余 ~45 个是 KvAdapta 浅色硬编码；**单一 SVG 兼两模式，深色模式下也是浅色面** |
| kvconfig 颜色 | 5 处 `text.focus.color=#0c458e`、若干 `#000000b4`/`white` | **kvconfig 不在模板管线**，accent 永远停在 `#0c458e` |
| 几何 | `scroll_width`/`check_size`/`menu_shadow_depth`/`tooltip_shadow_depth` 已对齐 tokens | 滑块、进度条、分隔条、按钮/输入框内边距仍是 KvAdapta 默认 |
| 形状 | `svg-round.py` 已把角部按 id 前缀收敛（button 5 / menu 6 / tooltip 6 / itemview 4 / menuitem 4 / tab 10 / focus 4） | **已对齐**，本表不动形状 |
| 底色设计 | KvAdapta 的 titlebar/menubar 是**深色**（`#222d32`） | DDE 的 titlebar 是窗口色（浅色 `#f9fcff`）——**这是设计差异，不是色值替换** |

## 二、颜色映射表

### 2.1 目标令牌（右列取值来源）

占位符语法 `{{colors.<name>.default.hex}}`，`default` 自动解析为当前明暗模式——**一个 SVG 同时服务浅深两套**。可用名字来自 `theme.rs` 的 48 键（节选）：

`surface`、`surface_container_lowest/low/container/high/highest`、`on_surface`、`surface_variant`、`on_surface_variant`、`outline`、`outline_variant`、`primary`、`on_primary`、`primary_container`、`on_primary_container`、`error`、`on_error`、`shadow`、`inverse_surface`、`inverse_on_surface`、`tertiary`、`secondary`。

GTK 侧同名对应（供交叉核对）：

| M3 键 | GTK `@define-color` | 用途 |
|---|---|---|
| `surface` | `@window_bg_color` | 窗口/控件面 |
| `surface_container_lowest` | `@view_bg_color` | 输入框、视图底 |
| `surface_container_low` | `@card_bg_color` | 表头、卡片 |
| `surface_container` | `@popover_bg_color` | 菜单/弹出层 |
| `surface_container_high` | —（DDE 用 overlay 阶梯） | 悬停/选中底 |
| `on_surface` | `@window_fg_color` | 主文本 |
| `on_surface_variant` | `@placeholder_text_color` / `alpha(@window_fg_color,.6)` | 次级文本 |
| `outline_variant` | `@borders` | 发丝描边 |
| `outline` | —（焦点用 `@accent_bg_color`） | 强描边 |
| `primary` | `@accent_bg_color` | accent |
| `primary_container` | —（滑块/进度填充） | accent 弱化 |
| `on_primary` | `@accent_fg_color` | accent 上的文字 |
| `error` | `@error_bg_color` | 错误 |

### 2.2 SVG 色值逐条映射（47 个唯一 hex）

「次数」= 在 `nosd.svg.tpl` 中出现次数（`grep -o '#[0-9a-fA-F]\{6\}'`）。

**面 / 底（L > 88%）**

| 现值 | 次数 | 当前元素证据 | → 目标 |
|---|---|---|---|
| `#f5f5f5` | 6 | `button`、button 内部路径 | `surface` |
| `#fafbfc` | 5 | `header`、`lineedit`、`combo`、`slidercursor` | `surface_container_low` |
| `#fbfbfc` | 2 | 路径 | `surface_container_low` |
| `#f6feff` | 1 | 路径 | `surface_container_low` |
| `#f2f3f8` | 1 | `dial`（旋钮面） | `surface_container_low` |
| `#f5f6f7` | 1 | `dock` | `surface` |
| `#f0f0f0` | 1 | 路径 | `surface_container` |
| `#e9ebed` | 1 | `header` | `surface_container` |
| `#e7ebed` | 3 | 路径 | `surface_container` |
| `#e4e7ea` | 2 | 路径 | `surface_container` |
| `#e8e9ea` | 9 | `menuitem`、`menuitem-toggled` ×8 | `surface_container_high`（DDE 菜单悬停是 accent，见 §2.4 备注） |
| `#e5e7e7` | 2 | `slidercursor` | `surface_container_low` |
| `#d7edec` | 1 | `progress-pattern`（进度条纹） | `primary_container` |

**描边 / 灰阶（L 66–88%）**

| 现值 | 次数 | 当前元素证据 | → 目标 |
|---|---|---|---|
| `#dee0e1` | 2 | `focus`、`focus-top0` | `primary`（DDE 焦点环是 accent，不是灰） |
| `#cfd3d5` | 4 | 路径（按钮/菜单描边） | `outline_variant` |
| `#dcdedf` | 3 | `lineedit-normal`、`combo-normal`、`tree-minus` | `outline_variant` |
| `#d2d2d2` | 2 | 路径 | `outline_variant` |
| `#dcdcdc` | 1 | `dock` | `outline_variant` |
| `#c2c5c7` | 1 | `scrollbarslider` | `outline_variant` |
| `#c8c8c8` | 3 | `progress-pattern-disabled` ×2、路径 | `outline_variant` |
| `#acb1bc` | 1 | `splitter` | `outline_variant` |
| `#a4a9ac` | 1 | `scrollbarslider` | `outline` |
| `#a6abae` | 1 | `combo-focused` | `outline` |

**文本（L 8–55%）**

| 现值 | 次数 | 当前元素证据 | → 目标 |
|---|---|---|---|
| `#323232` | 2 | `spin-plus` | `on_surface` |
| `#505050` | 4 | 路径 | `on_surface` |
| `#5a5a5a` | 3 | `slider-tick` | `on_surface_variant` |
| `#5a616e` | 1 | 路径（进度条分隔） | `on_surface_variant` |
| `#646464` | 1 | 路径 | `on_surface_variant` |
| `#6e6e6e` | 1 | 路径 | `on_surface_variant` |
| `#7b7b7b` | 3 | 路径 | `on_surface_variant` |
| `#7d7d7d` | 1 | `toolbar` | `on_surface_variant` |
| `#828282` | 3 | 路径、`flat-spin-up` | `on_surface_variant` |
| `#8c8c8c` | 1 | 径向渐变 | `on_surface_variant` |
| `#000931` | 1 | `arrow-down` | `on_surface_variant` |
| `#141414` | 1 | `rect7888`（`opacity:0`） | **删除**（不可见辅助元素） |

**深面 / 阴影（KvAdapta 的暗部）**

| 现值 | 次数 | 当前元素证据 | → 目标 |
|---|---|---|---|
| `#222d32` | 3 | `titlebar-normal`、`menubar-normal-*`、`<g>` 组 | `surface` ★**设计差异**：KvAdapta 深色标题栏 → DDE 浅色标题栏 |
| `#263238` | 1 | `scrollbarslider` 内部 | `on_surface_variant` |
| `#1e282d` | 9 | tooltip 阴影/提示切片 | `shadow`（只取 alpha） |
| `#b74aff` | 4 | `menu-shadow-hint-*` | `shadow`（只取 alpha，颜色无意义） |

**彩色**

| 现值 | 次数 | 当前元素证据 | → 目标 |
|---|---|---|---|
| `#0cb400` | 1 | `circle1775`（状态点） | `tertiary`（DDE 无 success 令牌，GTK 侧是 `@success_color #73d216`） |
| `#ff7a00` | 1 | `circle1793` | `secondary`（GTK 侧 `@warning_color #F27835`） |
| `#008dd4` | 1 | `circle1822` | `primary` |
| `#00c3dc` | 1 | `path1591` | `primary_container` |
| `#f44336` | 2 | `rect5112`、`rect5118` | `error` |
| `#f04a50` | 1 | `path4851` | `error` |
| `#ff4e41` | 1 | `rect1568` | `error` |
| `#ff0a0a` | 1 | `circle6090` | `error` |

### 2.3 kvconfig 文本色

| 字段 | 现值 | 出现 | → 目标 |
|---|---|---|---|
| `text.normal.color` | `#000000b4`（70% 黑） | 21 | `alpha(on_surface, 0.70)` 等价：`{{colors.on_surface.default.hex}}b4` |
| `text.normal.color` | `#00000096`（59% 黑） | 4 | `{{colors.on_surface.default.hex}}96` |
| `text.normal.color` | `#000000c8`（78% 黑） | 10 | `{{colors.on_surface.default.hex}}c8` |
| `text.normal.color` | `#000000aa` / `#0000007d` | 2 | 同上按 alpha 映射 |
| `text.normal.color` | `#c8c8c8` | 1 | `alpha(on_surface, 0.38)`（M3 disabled） |
| `text.focus.color` | `black` | 11 | `on_surface` |
| `text.press.color` | `#000000b4` | 8 | `on_surface` |
| `text.toggle.color` | `white` | 8 | `on_primary` |
| `text.normal.color` | `#ffffffb4` / `#ffffffa0` | 5 | 仅 titlebar/toolbar 组；titlebar 改浅色后应为 `on_surface` |
| `text.focus.color` | `#0c458e` | 5 | `primary` ★需 kvconfig 进模板管线（§四.2） |

> **Kvantum 的 8 位 hex 是 `#RRGGBBAA`（alpha 在后）**，不是 Qt 的 `#AARRGGBB`：现有 `#ffffffb4` 若按 alpha 在前解析会变成「不透明淡黄」，显然是错的。所以「颜色 + alpha」可以拼成 `{{colors.on_surface.default.hex}}b4`——模板只做字符串替换，拼出来仍是合法的 8 位 hex。

### 2.4 两处不能只换色值的地方

1. **菜单悬停**：KvAdapta 用浅灰 `#e8e9ea`（`menuitem-toggled`），DDE 用 **accent 底 + 白字**（DESIGN §1.1「菜单悬停」）。所以 `menuitem-toggled-*` 应改 `primary`，同时 `[MenuItem] text.toggle.color` 必须改成 `{{colors.on_primary.default.hex}}`——它现在没有单独设置，继承自 `[PanelButtonCommand]` 的 `text.toggle.color=white`。**白色只在浅色模式的 accent 上成立**（M3 浅色 `on_primary` 是白），深色模式 primary 是 tone 80 的浅色，`on_primary` 是深色——写死 white 会在深色下变成「浅底白字」，对比度崩掉。
2. **焦点环**：KvAdapta 灰环 `#dee0e1`，DDE 是 accent 环（`@accent_bg_color`，宽度 1.5px）。改 `primary` 后，`focus` 切片的 1px 厚度仍小于 GTK 的 1.5px——**待标定**（见 §三）。

## 三、几何映射表

GTK 实测值取自 `deepin/gtk-3.0/gtk.css`（浅色；深色同值）。

| kvconfig 字段 | 现值 | GTK 对应 | 目标 | 依据 |
|---|---|---|---|---|
| `scroll_width` | 8 | `tokens [controls] scroll_width` | **8 ✓ 已对齐** | tokens |
| `check_size` | 14 | `tokens [controls] check_size` | **14 ✓** | tokens |
| `menu_shadow_depth` | 5 | `tokens [shadow] menu` | **5 ✓** | tokens |
| `tooltip_shadow_depth` | 6 | `tokens [shadow] tooltip` | **6 ✓** | tokens |
| `slider_width`（槽厚） | 2 | `scale trough` border-radius 5 / 高 5px | **5** | gtk.css:3136-3140 |
| `slider_handle_width` | 18 | `scale slider` min-width 15 | **15** | gtk.css:3122-3125 |
| `slider_handle_length` | 15 | `scale slider` min-height 15 | **15 ✓** | 同上 |
| `tickless_slider_handle_size` | 16 | 同上 | **15** | 同上 |
| `progressbar_thickness` | 4 | `progressbar` 无显式高度；OSD 3px | **待标定**（量 GTK 进度条实际厚度） | gtk.css:3296-3304 |
| `splitter_width` | 4 | `separator` 1px | **1** | gtk.css:3477-3480 |
| `layout_spacing` | 6 | GTK 容器 spacing 6 | **6 ✓** | gtk.css 多处 |
| `layout_margin` | 9 | GTK 窗口/对话框 margin | **待标定**（量 DDialog 内容边距） | — |
| `[PanelButtonCommand] frame.top/bottom` | 4 / 4 | `button` padding 2px + border 1px | **2 / 2**（边框由 SVG 画，padding 2） | gtk.css:424-432 |
| `[PanelButtonCommand] frame.left/right` | 4 / 4 | `button` padding 6px | **6 / 6** | 同上 |
| `[PanelButtonCommand] text.margin.top/bottom` | 2 / 4 | 已含在 padding | **0 / 0** | 同上 |
| `[PanelButtonCommand] frame.expansion` | 14 | GTK 无对应（SVG 边框外扩） | **待标定**（保持 14 或按实测降到 6） | — |
| `min_height=+0.3font` | +0.3font | `button` min-height 22px | **22px 等效**（9pt ≈ 12px → 0.3font ≈ 3.6px，需实测总高） | gtk.css:425 |
| `[LineEdit] frame.top/bottom` | 2 / 2 | `entry` padding 2px | **2 / 2 ✓** | gtk.css:265-270 |
| `[LineEdit] frame.left/right` | 2 / 2 | `entry` padding 8px | **8 / 8** | 同上 |
| `spin_button_width` | 24 | GTK spinbutton 按钮宽 | **待标定** | — |
| `toolbar_interior_spacing` | 2 | GTK toolbar 间距 | **待标定** | — |
| 圆角（SVG 切片） | button 5 / menu 6 / tooltip 6 / itemview 4 / menuitem 4 / tab 10 / focus 4 | tokens `radiusRow 4 / radiusItem 5 / radiusPopup 6 / radiusWindow 8 / radiusLarge 10` | **已对齐，不动** | `scripts/svg-round.py` |

> 「待标定」五项共 5 个数字，建议 Worker 用 `kvantumpreview` 与一个 GTK 对照窗口并排截图量像素，一次定完，写回本表。

## 四、三条结构性前置（不做则改色不生效）

1. **tpl 占位符要从 2 个扩到 ~15 个**。当前只有 `primary`（×41）与 `primary_container`（×8）。按 §2.2 至少需要新增：`surface`、`surface_container_low`、`surface_container`、`surface_container_high`、`on_surface`、`on_surface_variant`、`outline`、`outline_variant`、`on_primary`、`error`、`shadow`、`tertiary`、`secondary`。
2. **kvconfig 不在模板管线**。`TemplateRegistry.qml` 的 `kvantum` 条目只渲染 `kvantum-nosd.svg` → `~/.config/Kvantum/nosd/nosd.svg`；`nosd.kvconfig` 由 `make install-kvantum` 装到 `$PREFIX/share/Kvantum/nosd/`，**5 处 `text.focus.color=#0c458e` 永远停在旧 accent**。两条路：
   - **推荐**：给 kvconfig 也加一条模板输出（`~/.config/Kvantum/nosd/nosd.kvconfig`）。用户目录优先于系统目录——SVG 走同一目录已验证生效。
   - 最小改动：删掉这 5 处 accent 字面值，让 Kvantum 回落到 QPalette 的 `Highlight`。
3. **单一 SVG 兼两模式**。`default` 占位符按当前模式解析，所以一份 SVG 就能同时服务浅深——但前提是 §2.2 的 `#222d32`（深色 titlebar）也换成 `surface`，否则深色模式下会出现「浅色按钮 + 深色标题栏」的割裂。

## 五、施工顺序与验收

1. 先做 §四 的三条前置（占位符、kvconfig 管线、titlebar 深色面）。
2. 按 §2.2 逐条替换 SVG 色值 → 生成静态 `nosd.svg`（`nosd.svg` 由 tpl 填充而来，**先改 tpl 再生成**，这是仓库铁则）。
3. 按 §2.3 改 kvconfig 文本色，§三 改几何（5 个待标定值先量再填）。
4. 验收：
   - `python3 scripts/check-tokens.py .` → `全部一致`
   - `kvantumpreview` 六页签截图（浅/深各一组）与 GTK 对照窗口并排，肉眼看「同一张脸」
   - 换调色板 A/B：SVG 与 kvconfig 的 accent **同时**变化（现在只有 SVG 会变）
   - 深色模式下控件面不再是浅灰（当前是 `#f5f5f5` 硬编码）

## 六、风险与限制

- **不能机械替换**：`#222d32`（titlebar）、`#e8e9ea`（菜单悬停）、`#dee0e1`（焦点环）三处是**设计差异**，换色同时要改 kvconfig 的对应文本色，否则出现「灰底白字」这类低对比。
- **SVG 是九切片图集**：改 `fill` 不会破坏切片几何；但 `shadow-hint` 类元素只取 alpha，把颜色换成 `shadow` 后若 alpha 不变则无视觉变化。
- **几何待标定 5 项**：本表给的是 GTK 侧目标，Kvantum 的 `frame.expansion`/`min_height` 是字体相对单位，换算需要一次实测。
- **kvconfig 进管线后**：系统安装（`PREFIX=/usr`）的用户拿不到跟随，与阶段 3 shell 的结论同源——推荐用户目录安装。
- **`#141414` 是 `opacity:0` 的死元素**，直接删，不要映射。

## 七、未能核实清单

| 条目 | 试过什么 | 为什么没确认 |
|---|---|---|
| `progressbar_thickness` / `layout_margin` / `spin_button_width` / `toolbar_interior_spacing` / `frame.expansion` 的 GTK 等效值 | 读 gtk.css 的 progressbar/separator/button/entry 块 | GTK 侧无一对一名，需 `kvantumpreview` 与 GTK 窗口并排量像素 |
| Kvantum 用户目录对 `nosd.kvconfig` 的优先级 | 依据同目录 SVG 已验证生效（`~/.config/Kvantum/nosd/nosd.svg` 被 Worker A/B 读到） | 未单独验证 kvconfig 文件本身 |
| 深色模式当前实际渲染（浅色面硬编码在深色下什么样） | 只读了 tpl 的静态色值 | 容器无 Qt 深色会话截图 |
