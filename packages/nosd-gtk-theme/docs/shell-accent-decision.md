# Cinnamon / GNOME Shell 取色方案决策记录

> 决策人：Chief｜日期：2026-11-13｜依据文档：[shell-accent-scheme.md](shell-accent-scheme.md)（Researcher，含 St 源码能力矩阵与全部证据）
> 状态：已定稿，进入实施

## 决策 1：shell 取色走「生成时注入」（方案 B）

「保持静态」被否定的硬依据：St 解析器（GNOME Shell 与 Cinnamon 同源 libcroco）**不支持 `@define-color` 与 CSS 变量**（`st-theme-node.c` 计数均为 0），`@` 引用会让所在规则整块退化——`1a7cc23` 已用 217+152 处失效引用实证过，回滚于 `8fb2990`。

**注入机制**：四个 shell css 文件末尾各加一行 `@import url("nosd-accent.css")`。St 的 `add_matched_properties()` 支持 `AT_IMPORT_RULE_STMT`（相对导入文件目录解析、递归合并），且 `lookup_color` 从属性数组末尾往前找 = 后声明胜出；缺文件时静默跳过（`-1` 标记），失效模式安全退化为不跟随。

**安装位置**：主题按**用户目录安装**（`make install PREFIX=$HOME/.local` → `~/.local/share/themes/`）——GNOME Shell 与 Cinnamon 的用户主题查找路径都覆盖此目录，覆盖文件可写、零提权；与阶段 4 的 Guix home-service 打包天然契合。系统级安装（`PREFIX=/usr`）下注入不可用，退化为静态跟随，可接受。

**nosd-accent.css 生成**：由 nosDshell 模板（TemplateRegistry 新增 cinnamon/gnome-shell 两条目）输出到用户主题目录；覆盖文件由脚本从主题 css 扫描含 accent 字面值（`#5294E2`/`#5294e2`/`#2679db`，大小写不敏感）的声明派生，不手抄选择器，避免主题升级漂移。随包分发一个只含注释的占位 `nosd-accent.css`。

**不做**：不用 `-st-accent-color`（GNOME 9 值枚举 ≠ nosd M3 连续色，会割裂）；Cinnamon 无任何 accent 原语，只能靠字面值覆盖。

## 决策 2：深色 `accent_*` 阴影族 9 条走 C1（方案侧派生）

在 `nosDshell/tools/nosd-theme/src/scheme.rs` 新增 `derive_accent_family(primary)`：按 Researcher 校准的 ΔH/ΔS/ΔL 常数派生 9 个命名色写进 scheme JSON，模板只引用 `{{colors.accent_*.default.hex}}`。

- 亮度用**余量模型**（`L' = L + (1−L)·t`），不用加性——浅 accent（L≥50%）下 `light_hover`/`on_bg_dim`/`disabled` 会塌成纯白；
- 在 accent=`#106daa` 下必须逐位复现 9 个原值，写成回归单测；
- 不扩模板 filter DSL（`shift_hue`/`tint` 不存在，扩张面大）；不在 GTK 侧找函数（GTK4 无 `shade()`），生成侧算好字面值注入。

## 决策 3：checker 加 shell 目录 `@` 引用禁令

`scripts/check-tokens.py` 增加规则：`cinnamon/`、`gnome-shell/` 目录下 css 出现 `@xxx` 颜色引用或 `@define-color` 即报错（`@import`/`@keyframes` 等合法 at-rule 白名单放行）。`1a7cc23` 漏网正是这个盲区。

## 已知未验证项（阶段 4/真机跟进）

- `@import` 放文件末尾在真机 St 上的层叠行为（源码推断成立，非契约）；
- Cinnamon 用户/系统同名主题目录优先级；
- 注入后 Cinnamon/GNOME Shell 真机换色截图（容器无 shell 会话，环境阻塞，如实记录）。
