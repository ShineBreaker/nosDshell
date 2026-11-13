# Cinnamon / GNOME Shell 取色方案（阶段 3 决策依据）

> 范围：`deepin/{cinnamon,gnome-shell}` 与 `deepin-dark/{cinnamon,gnome-shell}` 四个主题文件如何跟随 nosd 调色板。
> 附带：GTK 侧深色 `accent_*` 阴影族 9 条字面值的派生方案（Chief 阶段 3 前置调研项）。
> 作者：Researcher｜日期：2026-11-13｜基线：`nosd-app-themes` HEAD `8fb2990`（已回滚 `1a7cc23` 对两个深色 shell 文件的改动；回滚后两文件 `@` 引用计数 **0**，字面值集合与浅色完全一致）

## 状态

**partial** —— 调研结论与推荐方案已定；两条未闭环：
① 容器内未安装 Cinnamon / GNOME Shell，全部结论来自源码直读 + 计数，**未做真机渲染验证**；
② libcroco 回退到 core grammar 后规则块的最终形态（整块声明丢失 vs 仅该声明丢失）未能实测，见「未能核实清单」。

## 执行摘要

一句话：**St 吃不了 `@define-color`，也不吃 CSS 变量，但吃 `@import`（相对路径、后声明胜出）——所以「保持静态」不可行，「生成时注入」是唯一能跟随 nosd 调色板的路**。

三条硬结论：

1. **St 对 `@define-color` 零支持**。GNOME Shell 的 `src/st/st-theme-node.c` 与 Cinnamon 的同名文件中，`define-color` 出现次数都是 **0**；`@define-color … ;` 会被 libcroco 解析成通用 at-rule，随后被 `add_matched_properties()` 的 `AT_RULE_STMT` 分支直接丢弃——不报错、不影响后续规则，但**完全无效**。
2. **`@accent_bg_color` 这类引用会让所在规则退化**。libcroco 的 term 解析器没有 at-keyword 分支，声明解析失败，整个规则回退到 core grammar 重解析——净效果是该块的颜色（很可能连同该块其余声明）丢失。今天 `1a7cc23` 在深色两个文件里引入 217 + 152 处这样的引用，**shell 主题当前是坏的**（Chief 已决定先回滚止血）。
3. **注入路径成立**：St 的 `st-theme.c` 显式处理 `AT_IMPORT_RULE_STMT`（`_st_theme_resolve_url()` 按导入文件所在目录解析相对路径，递归合并）；`st_theme_node_lookup_color()` 从属性数组**末尾往前**查找，即**后声明胜出**——把覆盖文件 `@import` 在主题 css 末尾即可覆盖前面的字面值。

## 信息来源

| 来源 | 类型 | 日期 | 可靠性 |
|---|---|---|---|
| `GNOME/gnome-shell` @ main，`src/st/st-theme-node.c`（135,497 B） | 官方源码 | 2026-11-13 拉取 | 高（一手） |
| 同上 `src/st/st-theme.c`（33,091 B）、`src/st/st-theme-context.c` | 官方源码 | 同上 | 高 |
| 同上 `src/st/croco/cr-parser.c`（146,515 B，vendored libcroco）、`cr-om-parser.c`、`cr-declaration.c` | 官方 vendored 源码 | 同上 | 高 |
| `GNOME/gnome-shell` 标签 `46.0` / `47.0` / `48.0` 的 `st-theme-node.c` | 官方源码（版本对照） | 同上 | 高 |
| `GNOME/gnome-shell` @ main，`data/theme/gnome-shell-sass/_default-colors.scss`、`_colors.scss` | 官方主题源码 | 同上 | 高 |
| `GNOME/gnome-shell-extensions` @ main，`extensions/user-theme/{util.js,extension.js}` | 官方源码 | 同上 | 高 |
| `linuxmint/cinnamon` @ master，`src/st/st-theme-node.c`（121,760 B）、`src/st/st-theme.c` | 官方源码 | 同上 | 高 |
| 同上 `js/ui/themeManager.js`、`js/ui/main.js` | 官方源码 | 同上 | 高 |
| 本仓 `1a7cc23` 及其父提交的 `deepin-dark/{cinnamon,gnome-shell}/*.css` | 本仓 git | 2026-11-13 | 高 |
| `nosDshell` `tools/nosd-theme/src/{renderer.rs,color.rs}`、`Services/Theming/{TemplateRegistry,TemplateProcessor}.qml` | 本团队源码 | 2026-11-13 | 高 |

> 检索通道说明：本轮 `web_search` 再次被污染（返回日本 navitime/翻译站，与主题无关），按既定做法**放弃搜索、直接读上游源码**。所有结论均可由上表 URL 复现。

## 关键发现

### 1. St 完全不认 `@define-color`（GNOME Shell 与 Cinnamon 皆然）

- `grep -c "define-color" src/st/st-theme-node.c` → GNOME Shell **0**，Cinnamon **0**。
- `@define-color x #5294E2;` 在 libcroco 里走 `cr_parser_parse_atrule_core()`：接受 `ATKEYWORD_TK` 开头，prelude 后遇 `;` 即 `goto done` 返回 `CR_OK`——**不报错**，但 `st-theme.c` 的 `add_matched_properties()` 对 `AT_RULE_STMT` 是 `default: break`，**不产生任何效果**。
- 对照：GTK 的 `@define-color` 是 GTK CSS provider 的私有扩展，St 从未实现。仓库里 `1a7cc23` 的提交说明本身也写了「cinnamon/gnome-shell 跳过：St 解析器不支持 @define-color」——但 diff 实际改了深色两个文件，说明说明与改动不一致。

### 2. `@name` 引用会让所在规则退化（不是「只是颜色变透明」）

解析链路（`cr_om_parser_simply_parse_buf` 入口，St 的 `parse_stylesheet()` 用的就是它）：

1. `cr_parser_parse_ruleset()` → 声明解析走 `cr_parser_parse_declaration()` → `cr_parser_parse_expr()` → `cr_parser_parse_term()`。
2. `cr_parser_parse_term()` 的 token 分支只认 NUMBER/FUNCTION/STRING/IDENT/URI/RGB/HASH/UNICODERANGE，**没有 at-keyword 分支**，落到 `else { status = CR_PARSING_ERROR; }`。
3. 声明失败 → 规则整体失败 → `cr_parser_parse_stylesheet()` 里**回退到 `cr_parser_parse_ruleset_core()`** 用 core grammar 重解析同一块。
4. core grammar 的 `cr_parser_parse_value_core()` 反而**接受** `ATKEYWORD_TK`（`value ::= [ any | block | ATKEYWORD S* ]+`），只是**不生成 term**。

净效果：`background-color: @x` 的值变成空、`border: 1px solid @x` 的 term 列表只剩 `1px solid`。St 侧 `do_border_property()` 的 `color_set` 保持 `FALSE`，`node->border_color` 停在默认 `TRANSPARENT_COLOR`（`st-theme-node.c` 约 2004 行）；`background-color` 则因 `decl->value == NULL` 走不到有效颜色。

⚠️ 这段是**源码推断**：core grammar 回退后规则块的最终形态（整块声明丢失 / 仅该声明丢失 / 值 NULL 触发 St 的 `get_color_from_term(NULL)`）我未能实测，三种都比「正常工作」糟，见「未能核实清单」。结论不变：**这类语法在 St 上必须零容忍**。

### 3. St 支持 `@import`，且后声明胜出（注入方案的地基）

- `st-theme.c` 的 `add_matched_properties()` 有 `case AT_IMPORT_RULE_STMT:` 分支：解析导入文件并**递归**收集匹配属性；解析失败的文件会被打上 `-1` 标记避免反复重试（导入不存在的文件是安全的）。
- `_st_theme_resolve_url()`：无 scheme 时 `g_file_resolve_relative_path(parent_of(importing_file), url)` —— **相对路径按导入文件所在目录解析**。
- `st_theme_node_lookup_color()`：`for (i = node->n_properties - 1; i >= 0; i--)` —— **从后往前**找，等价于标准 CSS 层叠（后声明胜出）。
- Cinnamon 的 `src/st/st-theme.c` 同样有 `AT_IMPORT_RULE_STMT` 处理分支。

### 4. St 不支持 CSS 变量（`var(--x)`）

`grep -c "var(--"` → GNOME Shell **0**，Cinnamon **0**。St 的颜色取值只有：`inherit` / `transparent` / 字面 hex/rgb / `rgba()` / `st-transparentize()` / `st-mix()` / `st-lighten()` / `st-darken()` / `-st-accent-color` / `-st-accent-fg-color`。

### 5. GNOME Shell 47+ 有原生 accent 与派生函数；Cinnamon 一个都没有

| 能力 | GNOME Shell 46.0 | GNOME Shell 47.0 | GNOME Shell 48.0 | Cinnamon master |
|---|---|---|---|---|
| `-st-accent-color` | ✗（0 处） | ✓（2 处） | ✓（2 处） | ✗（0 处） |
| `st-mix()` | ✗ | ✓ | ✓ | ✗ |
| `st-lighten()` / `st-darken()` | ✗ | ✓ | ✓ | ✗ |

- GNOME Shell 的 accent 来自 `St.Settings` 的 `accent-color` 属性，`st-theme-context.c` 的 `update_accent_colors()` 把它映射成 9 个**预设**之一（BLUE/TEAL/GREEN/YELLOW/ORANGE/RED/PINK/PURPLE/SLATE）。
- 上游自己的主题就是这么写的：`_default-colors.scss` 里 `$accent_color: if($variant=='light', -st-accent-color, st-mix(-st-accent-color, $light_1, 60%));`。
- **但这对 nosd 没用**：nosd 的 accent 是壁纸生成的 M3 连续色，而 GNOME 的 `accent-color` 只有 9 个枚举值，映射进去必然失真；Cinnamon 更是完全没有。

### 6. 主题查找路径（决定注入文件写到哪里）

| 桌面 | 查找顺序 | 源码依据 |
|---|---|---|
| GNOME Shell（User Themes 扩展） | `~/.themes` → `$XDG_DATA_HOME/themes`（即 `~/.local/share/themes`）→ 各 `XDG_DATA_DIRS/themes` | `user-theme/util.js` `getThemeDirs()` |
| Cinnamon | `$XDG_DATA_HOME/themes/<name>/cinnamon` → `~/.themes/<name>/cinnamon` → `XDG_DATA_DIRS/themes/<name>/cinnamon` | `js/ui/themeManager.js` 第 26–40 行 |

即：**系统目录（`/usr/share/themes`，`make install` 的默认 `PREFIX=/usr`）写不了；用户目录（`~/.themes`、`~/.local/share/themes`）可写**。这一点直接决定方案成本。

### 7. 回归案例：`1a7cc23` 把深色 shell 弄坏了（「保持静态」的反面教材）

| 文件 | `1a7cc23` 改动行数 | `@` 引用总数 | `background-color: @x` | `color: @x` | `border…: @x` |
|---|---|---|---|---|---|
| `deepin-dark/gnome-shell/gnome-shell.css` | 470 | 217 | 54 | 118 | 30 |
| `deepin-dark/cinnamon/cinnamon.css` | 341 | 152 | 35 | 80 | 24 |

- 上游 `b7eef58` 的这两个文件里 `@define-color` 与 `@` 引用均为 **0**；全部是本仓 `1a7cc23` 引入。
- **浅色 `deepin/cinnamon/cinnamon.css` 与 `deepin/gnome-shell/gnome-shell.css` 未被 `1a7cc23` 触及**（`git show --stat 1a7cc23 -- deepin/cinnamon deepin/gnome-shell` 无输出），仍是字面值，**未受此回归影响**。
- 止血已完成：`8fb2990` 回滚后两文件 `@` 引用归零；`deepin` 与 `deepin-dark` 的 shell 字面值集合 `diff` 结果完全一致（`#5294E2` 54、`#ffffff` 45、`#5c616c` 33、`#BAC3CF` 20 等）。**回滚后的状态即「方案 A 保持静态」的实证形态：语法正确、但 accent 永远停在 `#5294E2`。**

## 对比与矩阵：两案影响面

| 维度 | 方案 A：保持静态（现状/回滚后） | 方案 B：生成时注入（覆盖文件 + `@import`） |
|---|---|---|
| 换调色板后 accent 是否跟随 | **否**（永远是 `#5294E2`） | **是** |
| 需要改 nosd-app-themes 的文件 | 0（回滚即可） | 4 个 css 各加 1 行 `@import` + 1 个随包分发的空 `nosd-accent.css` |
| 需要改 nosDshell | 0 | 2 个模板条目（cinnamon / gnome-shell 覆盖文件） |
| 写文件的位置 | — | 主题目录同级的 `nosd-accent.css`，**必须用户可写** |
| 系统级安装（`PREFIX=/usr`）下能否工作 | 能（但完全不跟随） | **不能**，除非走 root/helper 提权 |
| 漂移风险 | 无 | 低：覆盖文件由主题 css 派生生成，不手抄选择器 |
| 失效模式 | 静默不跟随 | 覆盖文件缺失 → `@import` 静默跳过（St 对坏导入打 `-1` 标记，不报错）→ 退化为方案 A |
| 已验证 | — | 注入链路（`@import` + 后声明胜出）源码级确认，未真机验证 |

**结论：选方案 B**，但落地前提是主题装在**用户可写目录**。三种落点，按推荐排序：

1. **用户目录安装（推荐）**：`make install PREFIX=$HOME/.local`（`share/themes/...` → `~/.local/share/themes/...`，Cinnamon 与 GNOME Shell 都在查找路径里）。生成器直接写 `~/.local/share/themes/<theme>/{cinnamon,gnome-shell}/nosd-accent.css`。零提权、零 helper。与阶段 4 的 Guix home-service 打包天然契合。
2. **系统安装 + 用户覆盖层**：主题在 `/usr/share/themes`，`~/.themes/<同名>` 只放 `cinnamon/cinnamon.css`（把原文件 `@import` 系统路径）+ 生成的 `nosd-accent.css`，资源目录用软链指回 `/usr/share/themes/<同名>/*-assets`。可行但多一层软链维护，Cinnamon 的查找顺序（XDG_DATA_HOME 先于 `~/.themes`）需要实测确认优先级。
3. **系统安装 + root 写**：最差，需 pkexec/helper，且升级主题会覆盖。不推荐。

## 推荐实现路径（方案 B）

### B1. nosd-app-themes 侧（一次性，静态）

四个文件末尾各加一行（幂等、缺文件安全）：

```css
/* nosd 调色板覆盖层；由 nosDshell 模板生成，缺失时本行静默失效 */
@import url("nosd-accent.css");
```

- 文件：`deepin/cinnamon/cinnamon.css`、`deepin/gnome-shell/gnome-shell.css`、`deepin-dark/cinnamon/cinnamon.css`、`deepin-dark/gnome-shell/gnome-shell.css`
- 同时随包分发一个只含注释的 `nosd-accent.css` 占位（避免首次使用时 404 语义的困惑，虽然 St 不报错）
- 注意：`@import` 在 CSS 规范里要求位于所有规则之前，**但 St 的实现是按语句顺序遍历、无此限制**（`add_matched_properties()` 对 import 与 ruleset 一视同仁）。放末尾是刻意的——为了「后声明胜出」。**这一条建议真机验证一次**。

### B2. nosDshell 侧（每次换色）

1. 新增两个模板条目（`Services/Theming/TemplateRegistry.qml`），输出到用户主题目录：
   - `~/.local/share/themes/deepin/cinnamon/nosd-accent.css`
   - `~/.local/share/themes/deepin-dark/gnome-shell/nosd-accent.css`（含 `deepin` 浅色与 `deepin-dark` 深色两条，按 `default-mode` 取）
2. 模板内容：把主题 css 里**含 accent 字面值的声明**原样重声明一遍，值换成 `{{colors.primary.default.hex}}` 及其派生。覆盖文件很小（见下表），不必整表复制。

### B3. 需要映射的字面值（实测计数）

| 字面值 | 语义 | 浅色 shell | 浅色 cinnamon | 深色（回滚后同浅色） | 映射 |
|---|---|---|---|---|---|
| `#5294E2` | accent 主色 | 54 | 41 | 54 / 41 | `{{colors.primary.default.hex}}` |
| `#5294e2`（小写） | 同上 | 2 | 1 | 2 / 1 | 同上（同一替换，注意大小写） |
| `#2679db` | accent 加深（同色相，L −10%） | 4 | 1 | 4 / 1 | 派生：`lighten:-10`（校准精确，见下） |

即覆盖文件约 **60 条（shell）/ 43 条（cinnamon）** 声明，量级可控；且可由脚本从主题 css 自动派生，避免手抄选择器。

## 附：深色 `accent_*` 阴影族 9 条的派生方案（GTK 侧）

### 结论先行

**这 9 条不是从 `#106daa` 按固定比率派生的**——它们是 2016 年移植时带进来的、分属三个不同色相族的字面值，与 accent 的色相（203.8°）并不一致：

| 名字 | 值 | H | S | L | 相对 `#106daa` 的 ΔH / ΔS / ΔL |
|---|---|---|---|---|---|
| `accent_bg_color` | `#106daa` | 203.8° | 82.8% | 36.5% | 基准 |
| `accent_standalone_color` | `#4DADD4` | 197.3° | 61.1% | 56.7% | −6.43 / −21.71 / +20.20 |
| `accent_hover_color` | `#76c0de` | 197.3° | 61.2% | 66.7% | −6.46 / −21.62 / +30.20 |
| `accent_active_color` | `#2e96c0` | 197.3° | 61.3% | 46.7% | −6.51 / −21.45 / +10.20 |
| `accent_light_color` | `#a9caf1` | 212.5° | 72.0% | 80.4% | +8.73 / −10.80 / +43.92 |
| `accent_light_hover_color` | `#e5effb` | 212.7° | 73.3% | 94.1% | +8.96 / −9.46 / +57.65 |
| `accent_light_active_color` | `#7eafe9` | 212.5° | 70.9% | 70.4% | +8.76 / −11.93 / +33.92 |
| `accent_disabled_color` | `#b1cff2` | 212.3° | 71.4% | 82.2% | +8.54 / −11.37 / +45.69 |
| `accent_border_color` | `#577ba7` | 213.0° | 31.5% | 49.8% | +9.23 / −51.30 / +13.33 |
| `accent_on_bg_dim_color` | `#cbdff6` | 212.1° | 70.5% | 88.0% | +8.33 / −12.30 / +51.57 |

- 内部确实有规律：`standalone/hover/active` 是一族（H 197.3°、S 61.2%、L 46.7/56.7/66.7 步长 10），`light_*` 是一族（H 212.5°、S 71–73%）。但**两族的色相都不是 accent 的 203.8°**，所以「按比率从 accent 派生」在数学上不成立。
- 出处：`git log -S accent_hover_color -- deepin-dark/` 只有本仓 `1a7cc23`（把原有字面值收敛成 `@define-color`）；这些字面值本身来自上游 `e3a5e9d`（2016-06-23，"add gtk3.20 support"），此后从未改动。上游 `b7eef58` 里 `#76c0de` 仍以内联字面值出现 6 次。

### 精确复现：HLS 加性偏移（逐位一致）

用「ΔH 旋转 + ΔS 加性 + ΔL 加性」模型，在 accent = `#106daa` 时 **9 条全部逐位复现原值**（已用 Rust `color.rs` 同款 HSL 公式与 `py_round` 模拟验证，非近似）：

```text
accent_standalone_color     shift_hue:-6.4  saturate:-21.7  lighten:+20.2  → #4dadd4  ✓
accent_hover_color          shift_hue:-6.5  saturate:-21.6  lighten:+30.2  → #76c0de  ✓
accent_active_color         shift_hue:-6.5  saturate:-21.5  lighten:+10.2  → #2e96c0  ✓
accent_light_color          shift_hue:+8.7  saturate:-10.8  lighten:+43.9  → #a9caf1  ✓
accent_light_hover_color    shift_hue:+9.0  saturate:-9.5   lighten:+57.6  → #e5effb  ✓
accent_light_active_color   shift_hue:+8.8  saturate:-11.9  lighten:+33.9  → #7eafe9  ✓
accent_disabled_color       shift_hue:+8.5  saturate:-11.4  lighten:+45.7  → #b1cff2  ✓
accent_border_color         shift_hue:+9.2  saturate:-51.3  lighten:+13.3  → #577ba7  ✓
accent_on_bg_dim_color      shift_hue:+8.3  saturate:-12.3  lighten:+51.6  → #cbdff6  ✓
```

### 但加性模型在浅 accent 下会溢出（必须换模型）

用真实调色板值试算（`Deepin` 预设深色 primary = `#2CA7F8`，L≈57%；M3 深色 primary 通常是 tone 80，L≈75%）：

| accent | `accent_light_hover`（+57.6） | `accent_on_bg_dim`（+51.6） | 结果 |
|---|---|---|---|
| `#106daa`（L 36%） | 94.1% | 88.0% | 正常 |
| `#0c458e`（L 30%） | 88% | 82% | 正常 |
| `#ff00ff`（L 50%） | **100% → `#ffffff`** | **100% → `#ffffff`** | 塌成纯白 |
| `#7fb069`（L 55%、S 31%） | **100%** | **100%** | 塌成纯白 |

浅色 accent 下 `light_hover` / `on_bg_dim` / `disabled` 会一起塌到纯白（选中行上的滑块变白底白），这是**必须避免**的。

**改用「余量模型」**（同样在 accent=`#106daa` 时逐位精确）：

- 变亮：`L' = L + (1 − L) · t`，`t = (L_target − L₀) / (1 − L₀)`
- 变暗：`L' = L · (L_target / L₀)`
- 饱和：`S' = S · (S_target / S₀)`
- 色相：`H' = H + ΔH`

在 L=50% 的 accent 下 `light_hover` 得 95.4%（不再溢出），L=55% 得 95.7%。校准常数与上表同源，只是把「加性」换成「按余量/比率」。

**可直接照抄的校准常数**（`accent = #106daa` 校准，已验证 9 条逐位复现）：

| 名字 | ΔH | S 比率（S'/S） | L 模式 | L 常数 |
|---|---|---|---|---|
| `accent_standalone_color` | −6.43 | 0.73779 | tint | 0.31790 |
| `accent_hover_color` | −6.46 | 0.73888 | tint | 0.47531 |
| `accent_active_color` | −6.51 | 0.74091 | tint | 0.16049 |
| `accent_light_color` | +8.73 | 0.86961 | tint | 0.69136 |
| `accent_light_hover_color` | +8.96 | 0.88571 | tint | 0.90741 |
| `accent_light_active_color` | +8.76 | 0.85585 | tint | 0.53395 |
| `accent_disabled_color` | +8.54 | 0.86271 | tint | 0.71914 |
| `accent_border_color` | +9.23 | 0.38041 | tint | 0.20988 |
| `accent_on_bg_dim_color` | +8.33 | 0.85139 | tint | 0.81173 |

- 当前 9 条全部是「变亮」（L 目标 > accent L），所以全走 `tint`；`ratio`（`L' = L · k`）留给将来可能需要变暗的派生色。
- 计算式：`H' = H + ΔH`；`S' = clamp(S · s_ratio, 0, 1)`；`L' = clamp(L + (1 − L) · t, 0, 1)`。
- 常数文件：`.agents/workfile/researcher/tmp/accent_consts.json`（本机留档，可复算）。

**跨亮度行为（余量模型，无塌白）**：

| accent | `light_hover` | `on_bg_dim` | `disabled` | `hover` |
|---|---|---|---|---|
| `#106daa`（L36%，校准基准） | `#e5effb` | `#cbdff6` | `#b1cff2` | `#76c0de` |
| `#0c458e`（L30%） | `#e2e9fb` | `#c5d4f6` | `#a9bef1` | `#67a7dc` |
| `#ff00ff`（L50%） | `#fee9fb` | `#fbd3f6` | `#fabcf1` | `#e38bee` |
| `#2ca7f8`（L57%） | `#edf4fd` | `#dae9fb` | `#c8def9` | `#9ed6ed` |
| `#a9caf1`（L80%） | `#f7f9fd` | `#f0f4fb` | `#e8eefa` | `#d7e7f3` |

对比加性模型在 L≥50% 时直接输出 `#ffffff`（塌白），余量模型到 L=80% 仍是可区分的近白色阶——这是选余量模型的实测理由。

### 实现路径二选一

| 方案 | 做法 | 代价 | 风险 |
|---|---|---|---|
| **C1（推荐）方案侧派生** | 在 `tools/nosd-theme/src/scheme.rs` 里新增 `derive_accent_family(primary)`，把 9 个名字直接写进 scheme JSON；模板里只写 `{{colors.accent_hover.default.hex}}` | ~40 行 Rust + 单测（用上表 9 个原值做回归断言） | 需改 Rust 二进制；但不动模板 DSL |
| C2 模板侧 filter 链 | 在 `Assets/Templates/gtk{3,4}.css` 里写 `{{colors.primary.default.hex \| shift_hue:… \| saturate:… \| lighten:…}}` | 需先给 renderer 补 filter：`shift_hue`（`color.rs` 里已有 `shift_hue()` 函数但**未暴露为 filter**）、`tint`（按余量变亮）、`shade`、`scale_saturation`，约 4×5 行 | 模板 DSL 扩张，matugen 兼容面变大；余量模型没有现成 filter |

- 现状：`renderer.rs` 的 `SUPPORTED_ORDER` 只有 `auto_lightness, darken, desaturate, grayscale, invert, lighten, saturate, set_alpha, set_blue, set_green, set_hue, set_lightness, set_red, set_saturation` + `blend`/`harmonize`（仅旋转色相）。**没有相对色相偏移，也没有按余量变亮**。
- 若只想先止血：C2 只补 `shift_hue`，用加性模型（浅 accent 下 3 条塌白），**不推荐**；C1 或 C2 全量才能既跟随又不塌。
- 与阶段 2 的结论一致：GTK4 没有 `shade()`，所以**不要**在 GTK 侧找函数，一律在生成侧算好字面值注入。

## 风险与限制

1. **未真机验证**：容器无 Cinnamon / GNOME Shell / gjs，全部结论为源码直读。`@import` 放文件末尾是否被 St 接受、Cinnamon 用户主题目录优先级、覆盖文件的实际渲染效果，都需要一次真机或至少 St 解析器单测。
2. **`@import` 位置**：CSS 规范要求 `@import` 在所有规则之前；St 实现上无此限制（按语句顺序处理），但这是实现细节，非契约。若真机发现末尾 import 被忽略，退路是把 `@import` 放文件**开头**并把覆盖文件做成「整表替换」（此时层叠由 import 顺序决定，需实测）。
3. **生成器写盘权限**：系统级安装（`PREFIX=/usr`）下无法写覆盖文件。要么改用户目录安装，要么接受「系统安装时取色不跟随」。
4. **覆盖文件与主题漂移**：若覆盖文件是手抄的选择器列表，主题升级会静默失配。推荐由脚本从主题 css 派生（扫描含 `#5294E2` 的声明，原样重声明）。
5. **大小写**：`#5294E2` 与 `#5294e2` 同时存在（shell 2 处、cinnamon 1 处），替换要大小写不敏感。
6. **9 条阴影族只在深色主题定义**（浅色 `deepin/gtk-3.0/gtk.css` 里没有这 9 个名字），派生只需产出深色侧；若将来浅色也要，别复用同一组校准常数。
7. **`-st-accent-color` 不要用**：它跟的是 GNOME 的 9 值枚举，不是 nosd 的 M3 调色板；混用会出现「面板跟随 GNOME、菜单跟随 nosd」的割裂。

## 未能核实清单

| 条目 | 试过什么 | 为什么没确认 |
|---|---|---|
| libcroco core grammar 回退后规则块的最终形态（整块声明丢失 / 仅该声明丢失 / `get_color_from_term(NULL)` 空指针） | 读遍 `cr-parser.c` 的 `parse_ruleset`→`parse_declaration`→`parse_term`→core 回退路径、`cr-om-parser.c` 的 property 回调、`cr-declaration.c` 的 `cr_declaration_new`（允许 NULL 值） | 需要编译 vendored libcroco 或真机跑 St；Arch 源里没有 `libcroco` 包，`meson/ninja` 也没装。**三种结果都比「正常工作」糟，不影响「必须回滚」的结论** |
| `@import` 放在 css 末尾能否覆盖前面同选择器的声明 | 读 `add_matched_properties()` 的语句遍历顺序 + `lookup_color` 从后往前查找 | 逻辑上成立，但缺真机验证 |
| Cinnamon 用户主题目录的优先级（`$XDG_DATA_HOME/themes` vs `~/.themes`） | 读 `js/ui/themeManager.js` 第 26–40 行的 dirs 顺序 | 顺序读到了，但「用户目录与系统目录同名时谁生效」未实测 |
| GNOME Shell 47 之前版本的 accent 处理（45 及更早） | 只对照了 46.0 / 47.0 / 48.0 三个标签 | 46.0 已确认无 accent；更早版本无意义（用户不会用） |
| 真机渲染截图 | — | 容器无 Cinnamon / GNOME Shell 会话 |

## 建议后续

1. **（已由 Chief 决定）** Worker 先回滚 `1a7cc23` 对两个深色 shell 文件的所有改动，恢复 `1a7cc23^` 字面值；CHANGELOG 记「St 不支持 @define-color，回滚待阶段 3 注入方案」。
2. **决策点**：确认主题的目标安装位置。若接受用户目录安装（`PREFIX=$HOME/.local`），方案 B 立即可落地；若必须系统安装，需要先定「用户覆盖层」策略（方案 B 落点 2）。
3. **实施顺序**：B1（4 行 `@import` + 占位文件）→ B2/B3（nosDshell 两个模板条目 + 派生脚本）→ 真机验证一次（Cinnamon 6.x + GNOME Shell 47+ 各一张换色前后截图，存 `screenshots/`）。
4. **GTK 侧 9 条**：选 C1（方案侧派生），用上表 9 个原值写回归单测；浅 accent 的塌白问题由余量模型解决，需同时覆盖 `#ff00ff`、`#2CA7F8` 两个用例。
5. **checker 增强**：`scripts/check-tokens.py` 目前只查 GTK 的 `@define-color` 与 hex 字面值。建议加一条规则：`cinnamon/` 与 `gnome-shell/` 目录下的 css **出现 `@` 引用即报错**（这次回归就是 checker 盲区——它把 shell css 的 `@` 引用当成了合法语法）。
