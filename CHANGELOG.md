# nosd-theme 实施日志

实施对象：`PLAN-app-theme-unification.md`。按步骤顺序记录每步结果与遗留。

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

### 待办 / 开放项

- 步骤 3：SVG 圆角改造（子任务进行中）。
- 步骤 7：`build-deb` 真机验证；`icons/` 并入（deepin-icon-theme 尚未入仓）。
- 步骤 8：上游 PR 暂缓。
- 图标主题：`icon_theme=Papirus-Dark` 未动。
- 视觉验收：kv + gtk3/gtk4 截图对照 DESIGN.md。
- Cinnamon/GNOME Shell 取色管线方案（生成时注入 vs 保持静态）。
