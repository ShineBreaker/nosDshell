# 更新日志

本文件记录 nosd-app-themes 面向使用者的变更。逐步实施过程、验证数据与当时的判断见

[docs/implementation-log.md](docs/implementation-log.md)。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，

版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.2.0] - 2026-11-14

### 变更

- *GTK 复选/单选/开关改为调色板跟随的矢量实现*：GTK 3/4 全部皮肤（`deepin`、
  `deepin-dark` 的 `gtk.css` 与 `gtk-dark.css`）不再引用烘焙了旧蓝色 accent 的 PNG
  素材（`checkbox-*`、`radio-*`、`switch-*`）。指示器改为 CSS 盒体几何
  （`background-color` + `border`）配 `-gtk-recolor` 字形（新增
  `check-symbolic.svg`、`dash-symbolic.svg`、`radio-dot-symbolic.svg`），颜色全部走
  `@define-color` 变量，随 shell 模板注入的 `nosd.css` 动态跟随 accent。选中/悬停
  （`menuitem`、`modelbutton`、`row:selected`、`.view:selected`、`infobar`）与禁用态
  一并覆盖；`.view.content-view` 选择角标改为 accent 底 + `accent_fg` 对勾。
- *开关改 CSS 绘制*：`switch` 的灰轨与滑块用 `background-color`/`border-radius`
  画成，新增 `switch_trough_color`、`switch_knob_color` 两个可覆盖变量；`:checked`
  走 `accent_bg_color` 轨道 + 深色滑块，对齐 deepin 原版素材与 Kvantum 侧样式。
- *Kvantum 复选/单选与 GTK 收敛到同一形态*：`nosd.svg(.tpl)` 中
  `checkbox-checked-normal`、`checkbox-tristate-{normal,focused}`、
  `radio-checked-normal` 由「accent 实心底 + 反白字形」改为「中性描边框 +
  accent 字形」，与 GTK 侧（及 deepin 原素材的深色版）一致；`item-checkbox` 等
  菜单指示器保持「面底 + accent 字形」不变。

### 修复

- *GTK 取色覆盖被旁路*：`deepin-dark/` 默认值块中旧变量名持字面值、语义名反向
  引用，导致 `nosd.css` 注入的语义变量到不了选择器。默认值块重写为语义名持值、
  旧名（`fg_color`/`bg_color`/`base_color`/`theme_*`/`wm_*` 等）全部别名化，
  动态取色对 GTK 3/4 各皮肤全链路生效。
- *标题栏颜色脱离契约*：`headerbar`/`titlebar` 原走契约外的 `@toolbar_color`
  并残留 `border-color: blue` 字面量，深色下出现异色条与蓝边；改为
  `@headerbar_bg_color`/`@headerbar_backdrop_color`/`@borders`。
- *弹出层语义与 shell 不对齐*：GTK `popover.background` 由
  `shade(@base_color,0.8)` 改为 `@popover_bg_color`；Kvantum `menu-normal` 由
  `surface` 改为 `surface_container`。GTK/Qt 菜单与弹出层现在取同一语义色
  （shell `surface_container` 层级）。
- *`deepin-dark` 静态白卡*：`card_bg_color`/`card_fg_color` 残留浅色值，无
  `nosd.css` 时深色主题出现白卡；改为 `@view_bg_color`/`@view_fg_color`。
- *模板漂移*：仓库 Kvantum 模板与 `nosDshell/Assets/Templates/` 中副本恢复
  逐字节一致（含指示器收敛与 `menu-normal` 变更）。

## [0.1.0] - 2026-11-13

首个以 `nosd-app-themes` 名义发布的版本，替代 `deepin-gtk-theme`。

### 新增

-  *Kvantum Qt 主题* `kvantum/nosd/`：`nosd.kvconfig` 与 `nosd.svg`，基于 KvAdapta
  形制，按 DDE 15 的平面设计重绘配色与圆角。
-  *模板源* `nosd.svg.tpl`、`nosd.kvconfig.tpl`：把 SVG 的图形颜色与 kvconfig 的
  全套调色板角色改为 Material 3 占位符，由 nosDshell 渲染壁纸取色后写入
  `~/.config/Kvantum/nosd/`。
-  *Cinnamon / GNOME Shell 取色注入点* ：两个桌面环境的皮肤文件末尾以
  `@import url("nosd-accent.css");` 引入覆盖文件，随包分发只含注释的占位版。
-  *形状令牌与校验* ：`tokens.toml` 把 `DESIGN.md` §1.4 / §1.2 的半径、描边与控件
  几何抄成机器可读形式；`scripts/check-tokens.py` 校验 GTK CSS、Kvantum 配置与令牌
  三者的一致性。`make check` 为入口。
-  *三套打包* ：`debian/`、`rpm/`、`arch/`；三者落位一致，均提供
  `deepin-gtk-theme`。
-  *`install-user` 目标* ：装到 `~/.local`。Cinnamon 与 GNOME Shell 的取色覆盖文件
  只能写在用户主题目录内，这是它们生效的唯一安装形态。
-  *GitHub Actions 发布流水线* ：打 tag 触发，产出 tar.gz、deb 与 rpm。

### 变更

- 品牌与包名从 `deepin-gtk-theme` 重定为 `nosd-app-themes`，通过
  `Provides/Replaces/Conflicts` 平滑替换原包。
-  *GTK 主题颜色全量收敛* ：`deepin/` 与 `deepin-dark/` 的 GTK 3/4 皮肤中，所有颜色
  字面量改为 `@define-color` 引用。定义块分三层——基元字面值、与 nosDshell
  `Assets/Templates/gtk{3,4}.css` 同名的语义默认值、旧变量名的链式别名。旧名全量
  保留，外部样式表按旧名覆盖的行为不变。
-  *圆角按 `DESIGN.md` §1.4 校准* ：DDE 风格的 1–3px 微圆角统一收敛到令牌集合
  `{4, 5, 6, 8, 10}`，按选择器语义逐处归位。`-gtk-outline-radius` 作为派生值

（形状半径 + 焦点环外扩）一并核对。

- Kvantum 主题的几何向 DDE 靠拢：`scroll_width` 9→8.`splitter_width` 4→1.
  滑块手柄 18→15.`[LineEdit]` 左右内边距 2→8.`[PanelButtonCommand]` 非对称圆角。

### 修复

-  *深色主题 accent 不跟随调色板* ：`deepin-dark` 把字面值挂在 `active_color` 上，
  而覆盖层只重定义 `accent_bg_color`，导致 `theme_selected_bg_color`、
  `wm_button_active_bg`、`osd_*` 整族停在旧蓝。改为 `active_color @accent_bg_color`，
  并把字面值移到 `accent_bg_color`，避免自引用环。
-  *深色页签栏浅灰带* ：`kvconfig` 省略 `[GeneralColors]` 时，Kvantum 的
  `standardPalette()` 只填出现过的角色，未出现的角色回落到 Qt 默认调色板

（`Window` = `#efefef`）。Kvantum 不绘制菜单栏与工具栏底色，露出的正是这条默认值。

  补齐全套 28 个角色后消除。

-  *Cinnamon / GNOME Shell 边框变透明* ：St 不认识 `@define-color`，
  `border: 1px solid @x` 会保留宽度、丢掉颜色。这两个目录的皮肤回滚为字面值，
  取色改由 `@import` 覆盖文件承担。
-  *存量引用错字* ：`@base_Color`、`@hightlight_color`、`@border` 三处拼写错误
  导致的未定义引用。
-  *`.help_button` 死代码* ：两段同特异性声明中前段被后段的 `border-radius: 0`
  覆盖，删除无效声明。
-  *`linked` 组横纵圆角互换* ：两个文件继承了上游的复制错误，横向组外角被置 0，
  统一到 4px。

### 移除

- 上游的 GXDE / linuxdeepin 复用 workflow、OBS 构建配置与 `program-builder`。
- Kvantum 的浮雕式斜面色：四个斜面色拉平为 surface。KvAdapta 依赖它们画立体感，
  而 DDE 是平面设计。

### 已知限制

- GTK 2 主题为静态配色：`gtkrc` 语法没有颜色变量，明暗与取色均不生效。
- Qt 5 需要发行版额外提供 Kvantum 的 Qt5 插件；仅有 Qt6 插件时 Qt5 应用退回
  qt5ct 调色板。
- Cinnamon 与 GNOME Shell 在系统级安装（`PREFIX=/usr`）下为静态 accent。
- 深色主题独有的 `accent_*` 阴影族（`accent_hover_color` 等 9 条）仍为字面值：
  按 accent 派生明暗需要 `shade()` 等效实现，GTK 4 无对应函数。
