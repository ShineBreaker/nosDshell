# CODING_STANDARDS — nosDshell 代码约定

QML 约定多数继承自 Noctalia、配置文件里看不出来，所以在这里写成文字。**视觉与交互仍以 [`DESIGN.md`](./DESIGN.md) 为唯一依据**；要写工具见 [`TOOLS.md`](./TOOLS.md)，要取证见 [`DEBUGGING.md`](./DEBUGGING.md)。

## 令牌优先

- 颜色从 `Color.*` 取，尺寸、圆角、时长从 `Style.*` 取；DDE 专用的表面和叠加色用 `Color.maskDark`、`Color.overlay(level)` 这类语义令牌。组件内部只做布局。
- 新数值若 `Commons/Style.qml` / `Commons/Color.qml` 里没有令牌，先去 `references/` 找出处、把它加进令牌文件，最后才在组件里使用。`DESIGN.md` 的禁用清单把「在组件里写死颜色、尺寸或时长」列为禁止项——本节是它的正面形式。
- `references/` 的引用格式是 `仓库/路径:行号`（权威见 `DESIGN.md` §1）。

## 设置项四处同步

新增或修改一个设置，四处同时改（权威清单见 `DESIGN.md` §6）：

1. `Assets/settings-default.json`
2. `Commons/Settings.qml`
3. 新的 `Commons/Migrations/MigrationNN.qml`，登记到 `Commons/Migrations/MigrationRegistry.qml`，并递增 `settingsVersion`（当前值读 `Commons/Settings.qml` 的 `settingsVersion` 属性）
4. 跑 `python3 Scripts/test/build-settings-search-index.py` 重建设置搜索索引

迁移时旧字段原样保留。`lefthook.yml` 声明了 pre-commit 里的格式化与索引重建，但本机 hook 未生效（`lefthook` 不在 PATH，`core.hooksPath` 下没有 pre-commit），所以第 4 步和下面的格式化都要自己跑。

## 界面文字

全部用 `I18n.tr("key")`。新增的 key 至少写进 `Assets/Translations/en.json` 和 `zh-CN.json`。

## 日志

用 `Logger.d/i/w/e("模块名", ...)`——QML 代码里没有 `console.log`。`Logger.d` 受 `debug.enabled` 门控，验证环境没开调试时它不输出（见 [`DEBUGGING.md`](./DEBUGGING.md)）。

## 面板与任务栏挂件

面板通过 `PanelService` 注册和打开，任务栏挂件通过 `BarWidgetRegistry` 注册；新增的面板或挂件沿用同一套注册机制。

## `modelData` 按稳定字段比对

JS 对象数组进 `Repeater` / `ListView` 的 model 会被 QVariant 包装，`modelData` 拿到的是副本，与原数组元素 `===` 恒 false——选中态和按引用查下标会静默失效（不报错，只是不亮）。一律按稳定字段比（`modelData.id === x.id`）；需要把对象存下来时，先归一化回原数组元素。已踩坑：`SettingsModuleView` 的 rail 点击与高亮。

## 格式化与注释

- 改完的文件跑 `Scripts/dev/qmlfmt.sh <路径>`（缩进、行宽和版本相关的参数都写死在脚本里；直呼 `qmlformat` 会绕过脚本的版本分支）。
- 现有注释保留；新代码只在不显而易见的地方加一行注释。