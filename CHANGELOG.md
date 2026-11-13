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

### 待办 / 开放项

- 步骤 2/3：kvconfig 更多几何参数 + SVG 圆角改造（进行中，子任务）。
- 步骤 4：SVG accent → `nosd.svg.tpl` 模板 + nosDshell `TemplateRegistry` 注册（渲染到 `~/.config/Kvantum/nosd/nosd.svg`）。
- 步骤 5：GTK 变量化（进行中，两个子任务分别做 deepin / deepin-dark）。
- 步骤 7：GTK 变量化完成后 `build-deb` 真机验证；`icons/` 并入（deepin-icon-theme 尚未入仓）。
- 步骤 8：上游 PR 暂缓（等本机跑稳定再谈）。
- 图标主题：`qt6ct.conf icon_theme=Papirus-Dark` 未动；`deepin-icon-theme` 并入后切 `deepin`。
