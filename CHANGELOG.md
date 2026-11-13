# 更新日志

本文件记录 nosd-app-themes 面向使用者的变更。逐步实施过程、验证数据与当时的判断见

[docs/implementation-log.md](docs/implementation-log.md)。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，

版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)。

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
