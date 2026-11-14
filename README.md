# nosd

nosDshell 生态 monorepo：shell 本体与周边主题集中管理，单一 UI 契约保证
各端界面一致。

## 组件

| 目录 | 组件 | 说明 | 独立发版 tag |
|---|---|---|---|
| `packages/nosdshell` | nosdshell | Noctalia v4 分叉，DDE 15（deepin 15）呈现层的 Quickshell/QML shell | `nosdshell-v*` |
| `packages/nosd-gtk-theme` | nosd GTK 主题 | deepin / deepin-dark，GTK 2/3/4 | `nosd-gtk-theme-v*` |
| `packages/nosd-kvantum-theme` | nosd Kvantum 主题 | Kvantum `nosd` 主题 + 模板工具 | `nosd-kvantum-theme-v*` |
| `packages/fcitx5-theme-nosd` | fcitx5 主题 | deepin-light / deepin-dark 输入法皮肤 | `fcitx5-theme-nosd-v*` |

不在本仓：[`quickshell-nosd`](https://github.com/nosDshell/quickshell-nosd)
（quickshell fork，独立仓）、[`nosd-pkgs`](https://github.com/nosDshell/nosd-pkgs)
（Guix channel + Nix flake 分发）。

## 安装

分发在 nosd-pkgs：

- **Guix**：channel `https://github.com/nosDshell/nosd-pkgs`，`guix install nosdshell`
- **Nix / NixOS**：flake `github:nosDshell/nosd-pkgs`（package / Home Manager / NixOS 模块）
- **手动**：主题组件各有 Makefile（`make -C packages/<组件> install`）；
  shell 直接用 `qs -p packages/nosdshell` 从源码运行

详见各组件 README。

## UI 一致性契约

`spec/tokens.toml` 声明跨组件令牌（圆角 / 边框 / 控件尺寸 / 阴影 / 颜色），
`tools/check-tokens.py` 校验三端实现不漂移：

```sh
python3 tools/check-tokens.py .   # 在 CI 中强制执行
```

改数值的流程：`packages/nosdshell/DESIGN.md`（可读权威）→ `spec/tokens.toml`
→ 各端实现，同提交落地。

## 发版

各组件独立发版：tag `<component>-v<version>` 触发对应流水线
（`.github/workflows/release.yml` → `tools/release/build.py`）。
流程细节见 `packages/nosdshell/docs/RELEASE.md` 与
[`docs/adr/0001`](docs/adr/0001-monorepo.md)。
