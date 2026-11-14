# nosd-kvantum-theme

nosDshell 的 Kvantum Qt 控件主题（`nosd`），与 GTK 组件
[`nosd-gtk-theme`](../nosd-gtk-theme)、shell 的
[`Commons/Style.qml`](../nosdshell/Commons/Style.qml) 共用
[`spec/tokens.toml`](../../spec/tokens.toml) 的形状令牌。

## 内容

| 路径 | 内容 |
| --- | --- |
| `nosd/nosd.kvconfig` | Kvantum 主题配置（含 `[GeneralColors]` 契约） |
| `nosd/nosd.svg` | 控件 SVG 素材 |
| `nosd/*.tpl` | 模板源——nosDshell 把壁纸调色板代入占位符，写出 `~/.config/Kvantum/nosd/` |
| `tools/svg-round.py` | SVG 圆角参数化工具 |

## 安装

```sh
make install          # 装到 $PREFIX/share/Kvantum/nosd（PREFIX 默认 /usr）
```

Qt 应用侧：安装 `kvantum` 包，`~/.config/qt5ct/qt5ct.conf` 与
`~/.config/qt6ct/qt6ct.conf` 设 `style=kvantum`，
`~/.config/Kvantum/kvantum.kvconfig` 写 `theme=nosd`。
Qt5 需要发行版提供 Kvantum 的 Qt5 插件（Guix 等只打 Qt6 插件的发行版
退回 qt5ct 调色板）。

## 打包

分发在 [`nosd-pkgs`](https://github.com/nosDshell/nosd-pkgs)：
`guix install nosd-kvantum-theme` 或 flake 的同名包。

## 发版

独立组件发版：tag `nosd-kvantum-theme-v<version>`，见仓根
[`docs/adr/0001`](../../docs/adr/0001-monorepo.md) 与
`tools/release/build.py`。
