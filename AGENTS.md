# AGENTS.md — nosd monorepo

nosDshell 生态的 monorepo：shell 本体与周边主题集中管理，用单一 UI 契约
（`spec/tokens.toml` + `tools/check-tokens.py`）保证各端界面一致。
布局与独立发版决策见 [`docs/adr/0001`](docs/adr/0001-monorepo.md)；
跨仓分发（Guix channel / Nix flake）在隔壁 `nosd-pkgs` 仓，不在本仓。

## 1. 组件地图

| 组件 | 是什么 | tag 前缀 | 改它时读 |
|---|---|---|---|
| `packages/nosdshell` | Noctalia v4 分叉（DDE 15 呈现层），Quickshell/QML | `nosdshell-v*` | [`packages/nosdshell/AGENTS.md`](packages/nosdshell/AGENTS.md) |
| `packages/nosd-gtk-theme` | deepin / deepin-dark GTK 2/3/4 主题 | `nosd-gtk-theme-v*` | 组件内 README + `spec/tokens.toml` |
| `packages/nosd-kvantum-theme` | nosd Kvantum 主题 + 模板工具 | `nosd-kvantum-theme-v*` | 同上 |
| `packages/fcitx5-theme-nosd` | deepin-light / deepin-dark fcitx5 皮肤 | `fcitx5-theme-nosd-v*` | 同上 |
| `spec/tokens.toml` | 跨组件 UI 令牌唯一声明（radius/color/border…） | — | 改数值先改这里 |
| `tools/check-tokens.py` | 令牌 ↔ 各端实现漂移检查 | — | `python3 tools/check-tokens.py .` |
| `tools/release/build.py` | 组件产物构建 + tag/版本校验（COMPONENTS 注册表） | — | 新增组件只改这里 |

**不在本仓**：`quickshell-nosd`（独立仓，每日上游同步 CI，无 UI 面）；
`nosd-pkgs`（Guix channel + Nix flake，按组件 tag pin 分发）。

## 2. 单一真相源

- UI 数值只有一条来路：`spec/tokens.toml` 是机器可读声明，
  `packages/nosdshell/DESIGN.md` 是可读权威。改可见数值：
  DESIGN.md → spec/tokens.toml → 各端实现（Style.qml / GTK CSS /
  Kvantum），同提交落地，`check-tokens` 必须过。
- 组件版本各管各的：nosdshell 看 `Commons/Version.qml` 的 `baseVersion`，
  主题组件看各自 `VERSION` 文件；各组件各有 `CHANGELOG.md`。

## 3. 发版

- tag 形如 `<component>-v<version>`，一个提交可携带多个 tag，每个 tag
  只触发自己组件的 release workflow（路由逻辑在 `.github/workflows/release.yml`
  + `tools/release/build.py` 的 COMPONENTS）。
- 历史 `v*` tag（旧 nosDshell 布局）有效但**新发版一律组件前缀**。
- **tag 漏推 = 无 Release**：每次发版 `git ls-remote --tags origin | grep <tag>` 自查。
- **一次 push 最多 3 个 tag**：超出则全部 workflow 不触发，分批推。

## 4. 工作准则

1. 改 shell 时先读 `packages/nosdshell/AGENTS.md`——根因/影响面/收口点
   分析与 lint/verify 校验分级都在那里，本文件不重复。
2. 一个提交只属于一个语义单元；跨组件的原子改动（如 token 变更）允许
   单提交多目录，但提交正文写清牵连面。
3. Conventional Commits；GPG 签名，签名失败先说明再降级；默认只提交
   不推送、不改写历史。
4. 分发相关改动去 `nosd-pkgs`；本仓唯一的 Guix 文件是
   `packages/nosdshell/guix.scm`（开发回环入口，import nosd-pkgs 的包定义）。
