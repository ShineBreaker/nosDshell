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

### 待办 / 开放项

- 步骤 3：SVG 圆角改造（子任务进行中）。
- 步骤 7：`build-deb` 真机验证；`icons/` 并入（deepin-icon-theme 尚未入仓）。
- 步骤 8：上游 PR 暂缓。
- 图标主题：`icon_theme=Papirus-Dark` 未动。
- 视觉验收：kv + gtk3/gtk4 截图对照 DESIGN.md。
- Cinnamon/GNOME Shell 取色管线方案（生成时注入 vs 保持静态）。
