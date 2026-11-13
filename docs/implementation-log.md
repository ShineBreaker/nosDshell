# 实施日志

本文件是 `PLAN-app-theme-unification.md` 的逐步实施记录：每步做了什么、验证方式、
遇到的岔路与遗留项。面向使用者的版本变更见 [CHANGELOG.md](../CHANGELOG.md)。

记录保留当时的判断与实测数据，不随结论更新而改写；已被推翻的结论就地标注，
便于回溯为什么改道。

## 2026-11-13

### 步骤 1 · 配置切换与接管验证（完成）

- `~/.config/qt6ct/qt6ct.conf`、`qt5ct.conf`：`style=Fusion → kvantum`、`color_scheme_path` 归位 `nosdshell.conf`、`stylesheets` 清空（去除 697 行 rounded.qss）。
- `~/.config/Kvantum/kvantum.kvconfig`：`theme=Orchis → nosd`；`~/.config/Kvantum/nosd` 软链到本仓库 `kvantum/nosd/`。
- Guix 侧：`Guix-configs/source/config.org` 的 home 包列表追加 `"kvantum"`（部署走 `blue home`，未执行；此前 kvantum 只在 store，不在 profile，`lib/qt6/plugins/styles/libkvantum.so` 对普通 Qt 应用不可见）。
- 验证：`QT_PLUGIN_PATH=<kvantum>:<qt6ct>` + `QT_QPA_PLATFORMTHEME=qt6ct` 起 `kvantumpreview`，Kvantum 风格正常渲染（截图证据 `/tmp/kvantum-test.png`，未留档）。**结论：Kvantum 能经 qt6ct 接管 Qt 控件绘制。**
- 已知限制：qt5ct 侧 kvantum 引擎包无 Qt5 插件输出（Guix `kvantum` 只给 `lib/qt6/plugins/styles/`），qt5ct `style=kvantum` 对 Qt5 应用是空操作，仅 Qt6 生效；Qt5 应用暂回落 qt5ct palette。

### 步骤 6 · 仓库骨架（完成）

- `kvantum/nosd/`：`nosd.kvconfig` + `nosd.svg`（基线 KvAdapta）。
- `tokens.toml`：DESIGN.md §1.4 半径（4/5/6/8/10）、边框、控件几何、默认 accent 的机器可读声明。
- `scripts/check-tokens.py`：GTK 硬编码颜色、border-radius 漂移、kvconfig [GeneralColors]、Style.qml 半径一致性检查；基线 3080 处漂移待消。
- Makefile：`install` = `install-gtk` + `install-kvantum`（装到 `share/Kvantum/nosd`）。
- 失效 CI 全删（`backup-to-gitlab`、`call-*`、OBS `workflows.yml`、`program-builder` GXDE reusable）；新增 `.github/workflows/release.yml`：tag → tar.gz + dpkg-buildpackage → softprops/action-gh-release。
- `debian/`：`Source: nosd-theme`、Provides/Replaces/Conflicts `deepin-gtk-theme`；`debian/changelog` 加 `nosd-theme (0.1.0-1)`。
- `rpm/`：`deepin-gtk-theme.spec → nosd-theme.spec`，`%{_datadir}/Kvantum/nosd/` 入包。
- `arch/PKGBUILD`：`nosd-theme-git`，`optdepends` 加 kvantum。
- `git remote add upstream https://github.com/GXDE-OS/deepin-gtk-theme.git`。
- kvconfig：`[GeneralColors]` 全删（继承 QPalette）；focus/press accent 文本色静态 `#0c458e`（palette 无法驱动 text.*.color，且与 SVG 静态 accent 对齐）；`scroll_width` 9→8；author/comment 换 nosd 名。

### 步骤 4 · Kvantum SVG 颜色静态化 + 模板（完成颜色，圆角进行中）

- `nosd.svg` 静态 accent：`#00bcd4/#007e8c/#005a64/#00c867 → #0c458e`（41 处），`#4db6ac → #a9caf1`（8 处）；中性色不动。
- `nosd.svg.tpl`：同文件占位符版（`{{colors.primary.default.hex}}` ×41、`{{colors.primary_container.default.hex}}` ×8），已复制进 `nosDshell/Assets/Templates/kvantum-nosd.svg`。
- `nosDshell/Services/Theming/TemplateRegistry.qml`：新增 `kvantum` entry，输出 `~/.config/Kvantum/nosd/nosd.svg`；`activeTemplates` 默认空 = 不主动写，需要 nosDshell 用户开。
- 遗留：圆角改造（步骤 3）在子任务进行；`b74aff` 菜单阴影紫暂留（视觉验证后定去留）。

### 步骤 5 · GTK 变量化（完成，待视觉验收）

- `deepin/` + `deepin-dark/`：gtk3/gtk4 四变体 + window-controls×2 + gtk4-compat×2 全部收敛到 `@define-color`。
  - 定义块结构：基元字面值 → `/* nosd 颜色默认值 */` 34+ 语义变量（与 `nosd.css` 同名）→ `/* 兼容旧变量名 */` 全量旧名链式别名（0 删除）。
  - 修复存量 typo 引用：`@base_Color → @base_color`、`@hightlight_color → @borders`、`@border → @borders`。
  - 补 `theme_unfocused_selected_bg/fg_color` 别名对齐 nosd.css（deepin/ 4 文件 + deepin-dark/ 4 文件 + gtk4-compat×2）。
- `deepin/cinnamon/cinnamon.css` + `deepin/gnome-shell/gnome-shell.css`：**跳过**。St/Cinnamon 解析器不支持 `@define-color`，要统一走生成时注入（阶段 B 决策项）。
- checker 结果：`check-tokens.py` 非 border-radius 告警 **0**；160 条 border-radius 漂移遗留（DDE 1–3px 微圆角 vs DESIGN 4/5/6/8/10 令牌，待 radius 调和步骤统一处理）。
- 语义近似点（视觉验收时复核）：accent 蓝色谱系摊平为 accent_bg/fg（hover/active 层次消）；`#BAC3CF` 当 borders 也当 disabled 文字底（`alpha(@borders,0.55)`）；`rgba(92,97,108)` → `alpha(@window_fg_color,*)`。
- 残留清理（用户手动）：`git stash` 里 `pre-retransform`、`dark-var-migrate-broken`、`v2` 三个中间版备份，确认成品后可 `git stash drop`；`../_dark_var_migrate.py` 工作区脚本可删。

### 步骤 5 续 · GTK border-radius 调和（完成）

- 152 处 DDE 1–3px 微圆角归位到令牌集合，覆盖 8 个文件（`deepin/`、`deepin-dark/` × `gtk-3.0`、`gtk-4.0` × `gtk.css`、`gtk-dark.css`），每文件 19 处；逐处按选择器块定位替换，不是全局字符串替换。
- 归位依据（DESIGN.md §1.4 语义，非机械就近）：

| 选择器 | 旧值 | 新值 | 令牌 | 依据 |
| --- | --- | --- | --- | --- |
| `entry.search` | 20px | 5px | radiusItem | 搜索框=5；20px 胶囊违反「不要胶囊形」 |
| `spinbutton:not(.vertical):dir(rtl) button.up` | 4px 0 0 3px | 4px 0 0 4px | radiusRow | 外角已 4，接缝角 3→4 统一 |
| `spinbutton.vertical button.up` | 4px 3px 0 0 | 4px 4px 0 0 | radiusRow | 同上 |
| `.inline-toolbar` | 0 0 3px 3px | 0 0 4px 4px | radiusRow | 附着工具栏底角归行控件档 |
| notebook tab（top/bottom/right/left） | 1px / 0 0 1px 1px / … | 对应角 4px | radiusRow | 附着 tab 取最小非零令牌 |
| `scale trough` / `highlight` / `fill` | 2.5px | 5px | radiusItem | 细轨道按高度钳制，取控件档 5；`scale.fine-tune` 同轮一起归位，两者不是互为依据 |
| `.app-notification` | 0 0 2px 2px | 0 0 8px 8px | radiusWindow | 通知=8，与 CSD 窗口底角一致 |
| `calendar:selected` | 1.5px | 4px | radiusRow | 日格是行式可选单元 |
| `messagedialog…button`（last/first/only-child） | 3px 角 | 8px 角 | radiusWindow | 对话框 `dtk-window-radius`=8，按钮底角随窗口 |
| `.keycap` | 2.5px | 4px | radiusRow | 行内小徽标 |
| `.gedit-search-slider` | 0 0 2px 2px | 0 0 5px 5px | radiusItem | 搜索语义=5 |
| `.nautilus-window .floating-bar` | 4px 2px 0 0 | 4px 4px 0 0 | radiusRow | 统一 4；贴边角由 `.bottom.*` 置 0 |

- 豁免（`tokens.toml` 新增 `[radius.exempt]`，checker 按「选择器 + 值」双匹配跳过，每条必带理由）：
  - `.help_button` 100px ×8（gtk3/gtk4 × 浅/深）：帮助按钮的胶囊形，属 DESIGN §1.4「正圆除外」类，令牌集合无此档。
- checker：160 → 0（`python3 scripts/check-tokens.py .` → `全部一致`）。
- 反证：把 `.help_button` 的值改成 3px、把 100px 挪到 `.overlay-bar`，checker 均照常报错 → 白名单不是按值放行。
- 渲染验证：gtk3/gtk4 widget-factory 在 Xvfb :99 加载浅/深四组，无 GTK CSS 解析告警；截图中心像素 `#f9fcff`（浅，`window_bg_color`）/`#1f2326`（深，`base_color`）命中主题令牌，确认主题实际生效而非回退。
- 遗留：浅/深 widget-factory 截图逐张对照 DESIGN.md 的视觉验收由 Reviewer 出图。

### 步骤 5 续 · checker 盲区修复与长写圆角调和（完成）

前一轮的「0 告警」只覆盖简写 `border-radius:`。本轮把 checker 换成 CSS 块扫描器，补齐盲区后重新归零。

- **checker 扩面**（`scripts/check-tokens.py`）：
  - 覆盖 `border-top-left-radius` / `border-top-right-radius` / `border-bottom-left-radius` / `border-bottom-right-radius` 四条长写，按属性名逐条判定，不与简写正则重复计数。
  - 覆盖 `-gtk-outline-radius`：它是派生值（形状半径 + 焦点环外扩），外扩量取同规则的 `outline-offset`，缺省用 `[radius.outline].offset = 2`；`50%` / `100%` 正圆胶囊不参与判定。派生规则能直接抓出「形状改了、焦点环没跟上」的漂移。
  - 豁免匹配由子串改为「逗号分隔后逐项精确相等」：`.help_buttonx`、`.help_button:hover` 不再被 `.help_button` 前缀放行。
  - 新增 `--stats` 输出分类计数，便于每轮报数。
- **起点统计**（扩面后首次运行）：简写 801 条、长写 304 条、`-gtk-outline-radius` 20 条，**220 处漂移**。
- **归位 260 处**（8 个文件 × 32–33 处），逐条按「选择器首项 + 属性 + 旧值」精确命中，不做全局替换：

| 选择器 | 旧值 | 新值 | 令牌 | 依据 |
| --- | --- | --- | --- | --- |
| `#content_frame` | 上角 2px | 8px | radiusWindow | 关机/重启对话框上半帧；对话框=8 |
| `#buttonbox_frame` | 下角 3px | 8px | radiusWindow | 同一对话框下半帧，上下同半径才成完整圆角卡片 |
| `messagedialog.csd.background` | 下角 3px | 8px | radiusWindow | 与 decoration、动作区按钮统一，按钮不再戳出框底 |
| `messagedialog.csd decoration` | 4px | 8px | radiusWindow | 同上；简写值本是令牌，checker 不报，属语义修正 |
| `colorswatch.{top,bottom,left,right}` | 2.5px | 5px | radiusItem | 色块网格外角按格子档 |
| `colorswatch.* overlay` | 2px | 4px | radiusRow | overlay 自带 1px 描边，内嵌半径 = 外层 − 1，网格不会「一半圆一半方」 |
| `.linked.vertical > *:first/last-child` | 3px / 0px | 4px | radiusRow | 3px 就近归位；0px 见下条 |
| `.linked:not(.vertical) > *:first/last-child` | 0px / 3px | 4px | radiusRow | 同上 |
| `scale trough` 的 `-gtk-outline-radius` | 4.5px | 7px | 派生 | 形状已 5px，焦点环 = 5 + outline-offset 2；4.5 是 2.5px 时代残留 |
| `.help_button` | `border-radius: 100px` | 删除 | — | 死代码，见下 |

- **`.help_button` 死代码确认**：8 个文件里均为两段同特异性声明——前段 `border-radius: 100px`，后段无条件 `border-radius: 0`，后者胜出，渲染值一直是 0。删前段声明、保留同块 `padding: 3px 9px`；`tokens.toml` 的 `[radius.exempt]` 随之清空（机制保留，当前无在册条目）。
- **linked 组 0/3 互换是上游继承的复制错误**：`deepin/gtk-3.0/gtk.css`、`deepin/gtk-4.0/gtk.css` 是「横向 3px / 纵向 0px」，其余 6 个文件正相反；`upstream-dgt` 里同样是这两文件互换。横向 `.linked` 组外角被置 0 会出现突兀直角，故 8 文件统一到 4px。**这是本轮唯一超出「就近令牌」的改动（0 → 4），理由记录于此。**
- **对话框底角决策**：`decoration` / `background` / 动作区按钮三值原为 4 / 3 / 8，统一到 §1.4 的对话框半径 8；动作区 `first-child` 左下、`last-child` 右下、`only-child` 双下角均为 8。
- `docs/radius-notes.md`：Researcher 的上游考据（半径历史、DTK 侧 6/8/18、长写盲区）随本轮入库。
- 验证：
  - `python3 scripts/check-tokens.py --stats .` → `简写 801 / 长写 304 / outline 20`，`漂移 0`，`check-tokens: 全部一致`；`make check` 同。
  - 反证（临时夹具）：长写 3px 报错、`-gtk-outline-radius` 4.5px 报错、`.help_buttonx` 与 `.help_button:hover` 均报错、登记过的 `.help_button` 100px 放行、`outline 7px` 与 `50%` 放行。
  - 8 个 GTK3/GTK4 CSS 经 `Gtk.CssProvider` 解析，0 条 parsing-error（`XDG_DATA_DIRS` 需带 `/usr/share`，否则 GSettings schema 缺失会中断）。
  - 12 个 CSS 括号平衡；`python3 -m py_compile scripts/check-tokens.py` 通过。
  - 取色器色块网格渲染：网格外角圆角、内部格保持直角（角像素 `cell1` 抗锯齿混合 vs `cell2` 纯色），嵌套半径生效。
- 遗留：CSD 对话框圆角在无头 Xvfb 里无法可视化——没有合成器时 GTK3 退化为方角实色框（已试 xfwm4，缺 Xfconf 起不来）。本轮以静态层叠核验代替（`messagedialog.csd` 三处半径按源序均为 8，无后续覆盖），最终视觉确认交 Reviewer 在有合成器的桌面出图。

### 步骤 5 续 · checker 收尾（完成）

- `iter_decls` 的 `}` 分支补 flush：规则可写成 `border-radius: Xpx}`（不带分号），旧实现在收块时直接清空缓冲，最后一条声明被整个丢弃。当前 8 个文件无此写法（`grep 'radius:[^;]*}'` 为空），属潜在洞，本轮补掉。
- 声明偏移改为取首个非空白字符，报出的行号与实际行对齐。
- 反证（无分号夹具）：旧版 4 条只抓到 1 条（带分号那条），新版 4 条全抓到，行号 3/4/5/7 与 `grep -n` 一致；真实仓库仍 0 告警，统计数字不变（简写 801 / 长写 304 / outline 20）。

### 步骤 5 续 · 深色 accent 跟随修复（完成）

阶段 2 视觉验收挖出的真 bug：深色主题换调色板后 accent 不跟随。

- **根因**：`deepin-dark` 把字面值放在 `active_color` 上，`accent_bg_color` 反向引用它（`gtk.css`：`accent_bg_color @active_color`）或同为字面值（`gtk-dark.css`：两者都是 `#14364d`）。覆盖层（`~/.config/gtk-{3,4}/nosd.css`）只重定义 `accent_bg_color`，碰不到 `active_color`，于是 `theme_selected_bg_color`、`selected_bg_color`、`wm_button_active_bg`、`osd_*` 这些挂在 `active_color` 下的全部停在旧蓝。浅色没这问题：`deepin` 里 `active_color @accent_bg_color`，方向是对的。
- **修法**：4 个文件 `active_color` 改为 `@accent_bg_color`；`gtk.css` 两个文件把字面值挪到 `accent_bg_color`（不挪就成自引用环）。深色原有 accent 值不变（`gtk.css` 仍是 `#106daa`，`gtk-dark.css` 仍是 `#14364d`）。
- `osd_hover_color` / `osd_active_color` 同样写死（`#639fe5` / `#4189df`），一并改为 `@accent_bg_color`。
- `theme_selected_bg_color` 在两个 `gtk.css` 里也是字面值 `#106daa`（`gtk-dark.css` 已是 `@active_color`），选中态主色会不跟随，改为 `@accent_bg_color`。
- `nosDshell` 侧双保险：`Assets/Templates/gtk3.css`、`gtk4.css` 补 `active_color` / `osd_hover_color` / `osd_active_color` 三条别名定义。
- 验证：`check-tokens.py` 全部一致；`@define-color` 引用图无环、无未定义引用；两份模板渲染后经 GTK3/GTK4 `Gtk.CssProvider` 解析 0 error；`nosDshell` 的 `Scripts/dev/lint.sh --changed` 通过。
- **运行时验证**（比截图更硬）：加载 `GTK_THEME=deepin-dark` 后在应用层覆盖 `accent_bg_color = #ff00ff`，用 `gtk_style_context_lookup_color` 读实际解析值，`accent_bg_color` / `active_color` / `theme_selected_bg_color` / `selected_bg_color` / `osd_active_color` / `osd_hover_color` / `wm_button_active_bg` 七项在 GTK3 与 GTK4 下全部为 `#ff00ff`（修复前 `theme_selected_bg_color` 仍为 `#106daa`）。
- 遗留：深色独有的 `accent_*` 阴影家族（`accent_hover_color`、`accent_active_color`、`accent_light_*` 等 9 条）仍是字面值。要跟随需要按 accent 派生明暗，GTK3 用 `shade()`、GTK4 没有等价函数，本轮不动，登记待决。

### 步骤 2 · Kvantum 侧取色跟随验收（完成）

- **环境**：容器内原本没有 Kvantum（`/gnu/store` 未挂载为空、pacman 也没有），补装 `kvantum` + `qt6ct`。验收用隔离的 `XDG_CONFIG_HOME`，主题目录取仓库 `kvantum/nosd` 的副本，不写仓库本体。
- **链路**：调色板 `primary` → `nosd.svg.tpl` 的 41 个 `{{colors.primary.default.hex}}` 与 8 个 `{{colors.primary_container.default.hex}}` → `~/.config/Kvantum/nosd/nosd.svg` → Kvantum 绘制控件。
- **A/B**：同一套控件，只改调色板 `primary`。基线 `#0c458e`（与仓库静态 SVG 同值），覆盖 `#ff00ff`。切换态按钮边缘像素 `(12,69,142)` = `#0c458e` → `(255,0,255)` = `#ff00ff`；六个页签（按压式按钮 / 工具按钮 / 单选复选 / 下拉调节输入 / 滑块滚动条进度 / 容器）的整图差异区域均非空，按钮组、单选复选组变化最明显。
- **说明**：模板渲染由脚本按 `TemplateRegistry` 的同名占位符替换完成，没有跑 nosDshell 的 QML 渲染器（容器里没有 shell 会话）。替换的占位符、输出路径与 `TemplateRegistry` 的 kvantum 条目一致，所以验证的是链路本身，不是渲染器实现。
- **截图**（`screenshots/`，未入库，与 Reviewer 的验收图同样处理）：`kvantum-<页签>-light-{baseline,accent-magenta}.png` 共 12 张，并排对比 `kvantum-accent-ab-{buttons,inputs,radios}.png` 3 张。
- **遗留**：容器内新装的 `kvantum`/`qt6ct` 属环境补充，不进仓库依赖；`accent_*` 阴影家族仍字面值（见上一节）。

### 步骤 5 续 · St 回归止血：深色 cinnamon/gnome-shell 回滚为字面值（完成）

- **根因**：`1a7cc23` 把 `deepin-dark/cinnamon/cinnamon.css`（341 行）与 `deepin-dark/gnome-shell/gnome-shell.css`（470 行）也转成了 `@define-color` + `@accent_bg_color` 引用，但 St（Cinnamon / GNOME Shell 的 CSS 引擎）不认 `@define-color`：`background-color: @x` 整条声明被丢弃，`border: 1px solid @x` 保留宽度、丢掉颜色，边框变透明。该提交说明里写的是「cinnamon/gnome-shell 跳过」，实际 diff 里改了，属说明与改动不一致。
- **处理**：两个文件恢复到 `1a7cc23^`（`git checkout 1a7cc23^ -- <两文件>`）。后续没有任何提交动过这两个文件，且该提交对它们几乎全是颜色转换（非颜色改动只有空行和一处 `box-shadow`），整文件恢复不会带回别的回退。
- **现状**：`@define-color` 0 处、`@` 颜色引用 0 处，字面值恢复（cinnamon 145 个 hex、gnome-shell 201 个）。
- **浅色未受影响**：`deepin/cinnamon/cinnamon.css`、`deepin/gnome-shell/gnome-shell.css` 在 `1a7cc23` 里 numstat 为空（没被改），一直是字面值，0 处 `@` 引用。
- **护栏**：回滚后全仓 `@define-color` 只出现在 `gtk-3.0/` 与 `gtk-4.0/` 下（12 个文件），St 消费的 `cinnamon/`、`gnome-shell/` 目录为 0 —— 这条可以直接作为以后改色的检查项。
- **计数口径**：我按每个 `@name` token 数，回滚前是 cinnamon 186 处、gnome-shell 251 处；Researcher 报的是 152 / 217，口径不同（可能只数特定属性），结论一致：改完之后是 0。
- **待阶段 3**：生成时注入方案（St 支持 `@import`，后声明胜出）。

### 阶段 3 · Cinnamon / GNOME Shell 取色注入（实施完成，真机待验）

决策见 `docs/shell-accent-decision.md`、依据见 `docs/shell-accent-scheme.md`。

- **注入点**：`deepin{,-dark}/{cinnamon,gnome-shell}/*.css` 四个文件末尾各加 `@import url("nosd-accent.css");` 与说明注释；同目录各放一份只含注释的占位 `nosd-accent.css`（随包分发，没有 nosDshell 时主题保持静态 accent）。
- **安装**：`Makefile` 新增 `install-user`（`PREFIX=$(HOME)/.local`）。覆盖文件只有装在用户主题目录才写得进去；`PREFIX=/usr` 时生成器无权限，St 侧退化为静态。
- **checker**：新增规则——`cinnamon/`、`gnome-shell/` 下出现任何 `@xxx`（`@import`/`@keyframes`/`@media` 等 at-rule 白名单之外）即报错，注释里的提及不算。反证：把 `1a7cc23` 的两个文件放进夹具 → **435 处漂移**，正是当时漏网的形态。
- **生成器**：`nosDshell/tools/nosd-theme` 新增 `shell_accent` 模块与 `--shell-accent-out/--theme-css/--accent` 三个参数。扫描主题 css，把含 `#5294E2`/`#5294e2`/`#2679db` 的规则**原样重声明**，值换成当前 accent 与 `L−10%` 派生色；选择器由扫描得出，不手抄。
  - 实测（accent 覆盖为 `#ff00ff`）：gnome-shell 51 条规则、cinnamon 31 条，选择器集合与主题 css 完全一致，输出残留原字面值 0，括号平衡。
- **深色 accent 阴影族**：`scheme.rs` 新增 `derive_accent_family(primary)`（色相偏移 + 饱和比率 + 亮度余量），9 条在 `#106daa` 下逐位复现原值；`inject_accent_family` 在 main 出口统一注入，predefined scheme 与图片取色两条路径共用。单测另覆盖 `#ff00ff`/`#2ca7f8`/`#7fb069` 不塌白。
- **模板与注册表**：`Assets/Templates/gtk{3,4}.css` 补 9 条 `accent_*` 引用；`TemplateRegistry` 新增 `shell-cinnamon`、`shell-gnome` 两条目，`post_hook` 调用生成器写两个主题目录。
- **未验证（环境阻塞，如实记录）**：`TemplateRegistry` 的 QML 条目没有运行时验证（容器无 shell 会话）；`@import` 放文件末尾在真机 St 上的层叠行为是源码推断，非契约。

### 阶段 4 · 打包与发布链路验证（完成，含两处环境替代）

- **deb**：`dpkg-buildpackage` 在 Arch 容器里被 `debhelper` 挡住（`dpkg-checkbuilddeps: unmet build dependencies: debhelper`，Arch 无该包）。改用等价构建：`make install DESTDIR=<stage>`（即 `dh_auto_install` 会做的事）+ `dpkg-deb --build`，control 字段按 `dh_gencontrol` 的规则补齐（`${misc:Depends}` 展开为空、Version 取 changelog、Maintainer 取源段）。产物 270 KB / 1917 文件。
- **rpm**：`rpmbuild -bb`（本地造 `nosd-theme-0.1.0.tar.gz` 源包）出包 567 KB / 1996 文件。
- **arch**：`makepkg -f --nodeps` 出 `nosd-theme-git-0.1.0-1-any.pkg.tar.zst` 652 KB；用 `pacman -U --root /tmp/archroot` 装进干净 root（不是装进当前系统），1917 文件落位 `/usr/share/themes/{deepin,deepin-dark}` 与 `/usr/share/Kvantum/nosd`，pacman DB 有记录。
- **落位与生效验证**：
  - 三个包内都有 4 个 `nosd-accent.css` 占位；包内 `deepin/cinnamon/cinnamon.css` 末尾 `@import url("nosd-accent.css");` 在。
  - 从 deb 解出的树直接当 `XDG_DATA_DIRS` 跑 gtk3-widget-factory：浅色中心像素 `#f9fcff`、深色 `#1f2326`，无 CSS 解析告警。
  - 同一棵树作为 Kvantum 主题跑 kvantumpreview：切换按钮边缘 `#0c458e`，主题真实生效。
- **`make install-user`**：`HOME=/tmp/fakehome` 实跑，落 `~/.local/share/themes/{deepin,deepin-dark}/{cinnamon,gnome-shell,...}` 与 `~/.local/share/Kvantum/nosd/`，4 个占位齐全——这是 St 取色注入唯一可写的安装形态。
- **release.yml 修整**（对照 PLAN §6.5「deb / rpm / tar.gz 三样」）：
  - 补 `build rpm` 步骤（原工作流只产 tar.gz + deb，缺 rpm）。
  - tar 步骤改用 `git archive`：原来 `tar` 整个目录会把 `arch/pkg/` 等本地构建产物打进发布包（本地实测发现），`git archive` 只取受版本控制的文件。
  - 去掉 `dpkg-buildpackage` 后面的 `|| true`：原来构建失败也会继续发布，可能发一个空 dist。
- **release.yml 终审两处必修**（`a5a623e`）：apt 清单补 `debhelper`（debian/control 的 Build-Depends，否则去 `|| true` 后构建直接 unmet）；rpm 版本改为 `sed` 写 spec `Version:` 字面量——`--define "version"` 覆盖不了 spec 内置宏，`VERSION=9.9.9` 本地全链路模拟产出 `nosd-theme-9.9.9-1.noarch.rpm` 验证。
- **未做（如实记录）**：没有推 tag，所以 GitHub Actions 本体未跑；`dpkg-buildpackage` 原命令因缺 debhelper 未执行（用等价构建替代）。

### 阶段 5 · Kvantum 收敛到 deepin GTK（施工中）

依据 `docs/kvantum-convergence-map.md`（`437ad42`）。目标是同一张脸，不是只对 accent。

- **SVG 全色板化**：`nosd.svg.tpl` 的 47 个六位硬编码 hex 全部换成 M3 占位符（13 类：`surface` / `surface_container` / `surface_container_low` / `on_surface` / `on_surface_variant` / `outline` / `outline_variant` / `primary` / `primary_container` / `error` / `shadow` / `tertiary` / `secondary`），残留 hex 归零。
- **施工图漏了三位 hex**：tpl 里还有 57 处 `fill:#fff` 与 1 处 `fill:#666`，映射表的统计口径是 `#[0-9a-fA-F]{6}`，三位写法没进表。首次按「字形→`on_surface`」映射时按钮出现黑边（白色高光描边被染成深灰），改为**全部 → `surface`**、`#666` → `on_surface_variant` 后正常。这条已回写进本节，映射表本身未改（属 Researcher 文档，交由下一轮修订）。
- **三条设计差异已落实**：`#222d32` 深色标题栏 → `surface`（DDE 标题栏是窗口色）；`menuitem-toggled` 的浅灰悬停 → `primary`（DDE 菜单悬停是 accent 底）；`#dee0e1` 灰焦点环 → `primary`。
- **静态 `nosd.svg`**：用 deepin 浅色调色板（`@window_bg_color #f9fcff`、`@accent_bg_color #2ca7f8`、`@window_fg_color #303030` 等）经模板渲染生成，随包分发时不再是 KvAdapta 配色。
- **kvconfig 进模板管线**：新增 `nosd.kvconfig.tpl`（39 处颜色占位符），静态版同源渲染；`nosDshell/Assets/Templates/kvantum-nosd.kvconfig` + TemplateRegistry 新增 `kvantum-config` 条目输出 `~/.config/Kvantum/nosd/nosd.kvconfig`——原先 5 处 `text.focus.color=#0c458e` 永远停在旧 accent 的问题消解。
- **文本色**：`#000000xx` / `#ffffffxx` / `black` / `white` 全部改为 `on_surface`（带原 alpha 后缀）或 `on_primary`；`[MenuItem]` 补 `text.toggle.color={{colors.on_primary...}}`，深色下「浅底白字」的崩点消除。
- **几何**（映射表已明确项）：`slider_handle_width` 18→15、`tickless_slider_handle_size` 16→15、`splitter_width` 4→1、`[PanelButtonCommand]` frame 4/4/4/4→2/2/6/6 且 text.margin 上下 2/4→0/0、`[LineEdit]` frame 左右 2→8。
- **未做（如实记录）**：
  - `slider_width` 未改：映射表给的目标 5px 依据是 `scale trough` 的 `border-radius: 5px`，那是圆角不是厚度（Reviewer 指出），并入待标定组。
  - 5 项待标定（`progressbar_thickness`、`layout_margin`、`spin_button_width`、`toolbar_interior_spacing`、`frame.expansion`）未量像素，保持原值。
- **验证**：浅/深两套调色板各渲染一份 SVG+kvconfig，`kvantumpreview` 实测——浅色按钮面 `#e6e8eb`、切换态 `#2ca7f8`、标题栏 `#f9fcff`；深色按钮面 `#2d333a`、切换态 `#106daa`、标题栏 `#1e2329`，深色不再出现浅色控件。`check-tokens` 全部一致、`lint.sh --changed` 通过。

### 阶段 5 续 · 页签栏/菜单栏/工具栏浅色带的根因与修复（完成）

深色截图里页签栏那条浅灰带，先后排除了两个岔路，最后落到 QPalette。

- **根因**（Researcher 源码 + PyQt6 实证）：`Style::polish(QPalette&)` 只有一行 `palette = standardPalette()`，而 `standardPalette()` 只填 `[GeneralColors]` 里出现过的角色。我们的 kvconfig 与 tpl 里 `GeneralColors` 计数是 0，于是 `Window` 停在 QPalette 默认构造值 `#efefef`——正好是量到的那条带子。`PE_PanelMenuBar` 在 Kvantum 里是 `break;`、`PE_PanelToolBar` 是 `return;`，两者根本不画底，露出的就是 `QPalette::Window`。
- **排除的两个岔路**：`respect_DE` 在 1.1.9 里只影响图标尺寸、`iconless_*`、`blurring` 与 KDE 滚轮翻页，不碰颜色；补 SVG `tabBarFrame-*` 切片只影响基线，背景仍无人画，且缺元素会回落 Kvantum 内置默认主题。
- **修复**：`nosd.kvconfig.tpl` 新增 `[GeneralColors]` 全套 27 个角色（`window`/`base`/`alt.base`/`button`/`light`/`mid.light`/`dark`/`mid`/`highlight`/`highlight.text`/`text`/`window.text`/`button.text`/`disabled.text`/`shadow`/`link`/`link.visited`/`tooltip.*`/`progress.*`/`inactive.*`），全部走占位符。四个斜面色 `light`/`mid.light`/`dark`/`mid` 拉平成 `surface`——KvAdapta 靠它们画浮雕，DDE 是平面设计，不拉平颜色对了看起来仍是另一套。
- **旧假设作废**：`tokens.toml` 里「kvconfig 省略 `[GeneralColors]` 走 QPalette」不成立——省略得到的是 Qt 默认调色板，不是 DE 的。给了 `[GeneralColors]` 之后 Kvantum 完全接管 Qt 配色，这正是统一风格要的。
- **验证**（同一份 SVG、同一个 style，只差 kvconfig）：深色 `页签栏/菜单栏/工具栏/内容底` 全部 `(30,35,41)`、按钮 `(45,51,58)`、切换态 `(16,109,170)`；浅色对应 `(249,252,255)` / `(230,232,235)` / `(44,167,248)`。修复前深色页签栏是 `(239,239,239)`。

### 待办 / 开放项

- 步骤 7：`build-deb` 真机验证；`icons/` 并入（deepin-icon-theme 尚未入仓，用户拍板不做）。
- 步骤 8：上游 PR 暂缓（用户拍板不做）。
- 图标主题：`icon_theme=Papirus-Dark` 未动。
- 真机待验：Cinnamon/GNOME Shell `@import` 末尾层叠与换色渲染截图、CSD messagedialog 底角 8px 合成器截图、`TemplateRegistry` QML 条目运行时验证、`install-user` 真机全链路——均为容器无桌面会话的环境阻塞项，到真机窗口补。
- PKGBUILD 建议加 `pkgver()`（`git describe`），版本号三处（debian/spec/PKGBUILD）现靠人工同步。
