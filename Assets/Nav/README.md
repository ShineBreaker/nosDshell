# Assets/Nav：设置导航条的模块图标

这里放控制中心/设置模块的导航图标，命名 `nav_<模块 id>.svg`，模块 id 与
`Modules/Panels/ControlCenter/ControlCenterModules.qml` 里的条目一一对应。

图标来源是 [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
（GPL-3.0，与本仓库相同）的 `24x24/symbolic/` 单色图标，复制进来作为运行时
主题解析的垫底：渲染端先在当前图标主题里找模块 `symbolicIcons` 候选的
`*-symbolic` 变体，找不到再用这里的文件（`ControlCenterModules.navIconUrl`）。
两边都出自 Papirus 同一套绘制规范，任何主题下图标家族都一致。

每个文件对应的 Papirus 原名：

| 模块 id | Papirus 源文件（`24x24/symbolic/`） |
| --- | --- |
| accounts | `apps/system-users-symbolic.svg` |
| advanced | `categories/applications-engineering-symbolic.svg` |
| bluetooth | `devices/bluetooth-symbolic.svg` |
| controlcenter | `apps/gnome-control-center-symbolic.svg` |
| datetime | `apps/preferences-system-time-symbolic.svg` |
| desktopwidgets | `apps/org.gnome.Settings-multitasking-symbolic.svg` |
| display | `apps/preferences-desktop-display-symbolic.svg` |
| dock | `apps/preferences-ubuntu-panel-symbolic.svg` |
| keyboard | `apps/preferences-desktop-keyboard-symbolic.svg` |
| launcher | `actions/view-app-grid-symbolic.svg` |
| network | `places/network-workgroup-symbolic.svg` |
| notifications | `apps/preferences-system-notifications-symbolic.svg` |
| personalization | `apps/preferences-desktop-appearance-symbolic.svg` |
| plugins | `actions/extension-symbolic.svg` |
| power | `apps/org.gnome.Settings-power-symbolic.svg` |
| sound | `apps/org.gnome.Settings-sound-symbolic.svg` |
| systeminfo | `status/dialog-information-symbolic.svg` |
| systemmonitor | `apps/utilities-system-monitor-symbolic.svg` |

## 新增模块时

1. 从 Papirus `24x24/symbolic/` 选一个语义贴合的 `*-symbolic` 图标，复制为
   `Assets/Nav/nav_<id>.svg`，在上表登记原名。
2. 在模块条目里写 `"symbolicIcons": [<按优先序的主题名，不带 -symbolic 后缀>]`，
   第一个候选应当与打包文件同名，这样主题缺失时看到的就是同一个图。
