# ADR 0001：合并 shell 与主题为 monorepo，独立发版

- 状态：已接受
- 日期：2026-11-15
- 决策人：ShineBreaker + Devin

## 背景

nosDshell 生态原有四个仓库：`nosDshell`（shell 本体）、`nosd-app-themes`
（GTK + Kvantum 主题）、`fcitx5-theme-nosd`（输入法皮肤）、
`quickshell-nosd`（quickshell fork）。UI 令牌的语义只有一份
（`DESIGN.md`），但实现分散在三端：QML（`Commons/Style.qml`）、
GTK CSS、Kvantum。原 `check-tokens.py` 靠
`root.parent / "nosDshell"` 硬编码跨仓找 Style.qml——只在恰好并排
clone 的开发机上有效，CI 与孤立 clone 静默跳过，跨仓漂移无法强制。

同期 nosDshell 仓自身兼任 Guix channel（`.guix-channel` + `nosdshell.scm`
local-file 源码）与 Nix flake（`flake.nix` + `nix/`），分发设施与开发
源码耦合：发版要同步 5 处版本号，channel 用户 `guix pull` 拉的是整个
开发树。

## 决策

1. **合并为一个 monorepo `nosd`**，布局 `packages/` 平铺（参考
   agenote ADR 0005 的同款先例）：

   ```
   packages/{nosdshell, nosd-gtk-theme, nosd-kvantum-theme, fcitx5-theme-nosd}
   spec/tokens.toml          # 跨组件令牌唯一声明
   tools/{check-tokens.py, release/build.py}
   ```

   原 `nosd-app-themes` 一拆二：GTK 与 Kvantum 各成组件（产品面与
   打包面本来就分离）。主题历史以「归位提交 + merge
   --allow-unrelated-histories」并入，不 rewrite。

2. **`quickshell-nosd` 保持独立仓**：纯 fork、无 UI 面、有每日
   upstream sync CI，与「UI 一致性」动机正交，合并没有收益只有
   sync 噪音。

3. **分发设施整体迁出到 `nosd-pkgs` 仓**：`.guix-channel`、`*.scm`
   包定义、`flake.nix`、`nix/` 全部删除；nosd-pkgs 同时是 Guix
   channel 与 Nix flake，按组件 tag pin 源码（git-fetch /
   flake input），并容纳更多相关软件（quickshell fork、Rust 工具、
   Guix Home 服务）。本仓只留 `packages/nosdshell/guix.scm` 作
   开发回环入口（import nosd-pkgs 定义、local-file 工作树）。

4. **组件独立发版**：tag `<component>-v<version>` 前缀路由
   （`tools/release/build.py` 的 COMPONENTS 注册表），各组件各有
   VERSION/CHANGELOG/产物。一个提交可携带多个 tag 实现原子联合
   发版。历史 `v*` tag 有效但不再触发流水线。

## 理由

- **UI 一致性首次可强制**：spec + checker + 三端实现在同一 clone，
  tokens job 进 CI；token 变更可与各端适配同提交落地（跨仓做不到的
  原子性）。
- **发布粒度与耦合粒度匹配**：主题改 bug 不必发 shell；token 跨端
  改动又可单提交+多 tag 原子发。
- **分发与开发解耦**：channel/flake 从「打包自身 checkout」改为
  「pin release tag」，用户拿到的是发布物而非开发树；发版不再
  牵扯 5 处版本号。

## 代价与接受的取舍

- 老 `v1.7.x` tag 指向旧布局树，不能直接用于 `packages/nosdshell`
  子路径打包——过渡期 nosd-pkgs 先 pin 重构后 commit，首个
  `nosdshell-v*` tag 后切 tag pin。
- 主题取消独立 git 仓库形态；独立可用性靠组件 Makefile + tarball
  发布物保留。
- channel 名 `nosdshell`→`nosd`、flake URL 变更：breaking change，
  发版说明给迁移片段。

## tag 陷阱（继承 agenote 运维记录）

- tag 漏推 = GitHub 无 Release（push 事件不触发 workflow）。
- 一次 push >3 个 tag → 全部 workflow 静默不触发；分批推。
