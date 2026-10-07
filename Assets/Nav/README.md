# Assets/Nav — 设置导航栏自绘图标

nosDshell 原创的导航图标，按 DDE 15 原版 `nav_<m>.svg` 的同一规格绘制：

- 24×24 viewBox，白色（#FFFFFF）填充/描边，薄线 ≈1–1.5 px
- `nav_<id>.svg` = 选中态（全不透明度）
- `nav_<id>_normal.svg` = 默认态（`fill-opacity="0.2" stroke-opacity="0.2"`，
  与上游 `_normal` 文件内嵌的 0.2 一致）

## 为什么不是 Assets/DDE/

`Assets/DDE/` 只放**原样复制**的上游素材（每个来源仓库一份 NOTICE，见
DESIGN §1.9）。这 8 个图标对应的模块是 Noctalia 扩展出来的、DDE 15 控制
中心里不存在的设置项（任务栏/启动器/控制中心/通知/桌面挂件/系统监视/
插件/高级），上游没有原画可抄——混入 Tabler 描边图标会让导航栏出现两套
粗细体系。本目录是同规格的自绘补齐，版权归本仓库（GPL-3.0）。

## 新增模块时

1. 在 `Assets/Nav/` 放 `nav_<id>.svg` + `nav_<id>_normal.svg` 两个文件；
2. 模块条目加 `"ddeIcon": "<id>"`；
3. `ControlCenterModules.qml` 的 `nosdNavIcons` 名单里登记 `<id>`。

未登记的 ddeIcon 会按上游路径拼 URL，找不到文件时 rail 静默回退 Tabler。
