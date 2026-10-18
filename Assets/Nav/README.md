# Assets/Nav：设置导航条的自绘图标

这里是 nosDshell 自己绘制的导航图标，规格与 DDE 15 原版的 `nav_<模块>.svg` 相同：

- 24×24 viewBox，白色（`#FFFFFF`）实心剪影为主，图形占画布约 20 px（坐标 2–22），镂空和间隙不窄于 1.5 px，不用 1 px 线框（见 `DESIGN.md` §1.9）。
- `nav_<id>.svg` 是选中态，完全不透明。
- `nav_<id>_normal.svg` 是默认态，写 `fill-opacity="0.2" stroke-opacity="0.2"`，与上游 `_normal` 文件内嵌的 0.2 一致。

## 为什么不放在 Assets/DDE/

`Assets/DDE/` 只放从上游原样复制的素材，每个来源仓库配一份 NOTICE（见 `DESIGN.md` §1.9）。这里的图标对应 Noctalia 扩展出来、DDE 15 控制中心里没有的模块，上游没有原图可以复制。如果改用 Tabler 描边图标，导航条上会出现两套线宽。所以按同一规格自绘补齐，版权归本仓库（GPL-3.0）。

## 新增模块时

1. 在 `Assets/Nav/` 放 `nav_<id>.svg` 和 `nav_<id>_normal.svg` 两个文件。
2. 在模块条目里加 `"ddeIcon": "<id>"`。
3. 在 `Modules/Panels/ControlCenter/ControlCenterModules.qml` 的 `nosdNavIcons` 名单里登记 `<id>`。

没有登记的 `ddeIcon` 会按上游素材路径拼出 URL，找不到文件时导航条会静默改用 Tabler 图标。
