---
title: Release Process
nav_exclude: true
---

# 发版流程

**发版由 tag 触发。** 把带正确版号的 release commit 和 `nosdshell-v<版号>` 附注 tag 推到 `main`，仓根 `.github/workflows/release.yml` 会完成其余工作：按 tag 前缀路由到本组件，校验版号、发布 GitHub Release、把 `isDevelopment` 改回 `true`。本地不需要创建 Release，也不需要手动 reopen。nosd-pkgs 的 pin 由人在本地更新（见文末），不走 CI。

人只准备两样东西：`CHANGELOG.md` 的版本条目，以及各处同步的版号。

## 人做的事

1. 写 `CHANGELOG.md` 条目：在 `[Unreleased]` 下写一段面向用户的简介（一两句话，可以带宣传口吻），接一条 `---` 分割线，然后按类别列出本次改动并引用 commit。文件头部的说明就是格式。
2. 按下面的「版号位置」改版号。版号以 `Commons/Version.qml` 的 `baseVersion` 为准；发版提交里 `isDevelopment` 必须是 `false`，CI 会校验。
3. 提交 `chore(release): nosdshell v<版号>`，打附注 tag，推送 `main` 和 tag：

   ```sh
   git tag -a nosdshell-v<版号> -m "nosdshell-v<版号>"
   git push origin main nosdshell-v<版号>
   ```

   ⚠️ 一次 push 最多 3 个 tag，超出则全部 workflow 不触发（GitHub 静默丢弃 push 事件）。多组件同发时分批推。

`Scripts/dev/release.sh <X.Y.Z>`（`just release`）把这三步串起来：`[Unreleased]` 为空时先生成带 commit 链接的条目草稿并停下，填好简介后重跑，完成落版、改版号、lint、关于页截图、提交、打 tag 和推送。`--no-push` 只在本地提交并打 tag（CI 因此不会运行），`--skip-verify` 跳过 lint 和关于页截图。

发版会推送 tag 和 main，只在用户要求时进行。

## CI 做的事

推 `nosdshell-v*` tag 后，`release.yml`（monorepo 根 workflow）依次执行：

- **build**：由 tag 前缀判定组件；`tools/release/build.py` 校验 tag 与 `baseVersion`、`isDevelopment=false` 一致，按 CHANGELOG 对应段落生成正文，打包 `nosdshell-<版号>.tar.gz` + `SHA256SUMS`。
- **github-release**：创建或刷新 GitHub Release。Release 已存在时只刷新正文和附件。
- **reopen**：在 `main` 上把 `isDevelopment` 改回 `true`，提交 `chore(release): reopen development after nosdshell-v<版号>` 并推送。

需要重发一个已存在的 tag 时，用 `gh workflow run release.yml -f tag=nosdshell-v<版号>`，各 job 都是幂等的。

## 更新 nosd-pkgs pin

`nosd-pkgs` 的 Guix 包定义（`guix/nosd/packages.scm`）与 flake input 按组件 tag pin。发版后在本地检出里把 `nosdshell` 的 ref 改到新 tag、更新 hash，用你自己的 GPG 签名提交并推送。`quickshell-nosd` 的 pin 只在 quickshell fork 有推进时同步。确认 `commit.gpgsign` 是开着的；不要用 `--no-gpg-sign`。

本地核对 hash：`git worktree add /tmp/nosd-<版号> nosdshell-v<版号>`，在 worktree 里跑 `guix hash -S nar -x packages/nosdshell`，输出应当与 `packages.scm` 里 nosdshell 的 base32 一致。核对完 `git worktree remove /tmp/nosd-<版号>`。

## 版号位置

| 位置 | 字段 | 发版时改成 |
| --- | --- | --- |
| `Commons/Version.qml` | `baseVersion` | 新版号（如 `"1.1"`） |
| `Commons/Version.qml` | `isDevelopment` | 发版提交里设为 `false`，CI 在 reopen job 里改回 `true` |
| `tools/*/Cargo.toml` | 各工具的 `version` | 独立版本，按需修改，不跟随 shell 版号 |

`Modules/Panels/Settings/Tabs/About/VersionSubTab.qml` 用正则从 store 名 `nosdshell-<version>_<commit>` 里提取 commit，适用于任何版号，改版号时不用动它。

`nosdshell --version`（或 `-V`）直接打印 `nosdshell v<版号> (with quickshell v<版号> <commit>)`，不启动 shell；Guix 构建附带 fork commit，Nix 构建附带 nixpkgs quickshell 版号。小写 `-v` 是 quickshell 的 verbose 开关，会正常透传启动。

关于页的版本显示：`isDevelopment=false` 时显示 `v<baseVersion>`；日常开发时显示 `v<baseVersion>-git`，后面附 commit 短 hash。

## 手工兜底

本地脚本失败、或想完全手工发版时，按顺序做：

1. `CHANGELOG.md`：把 `[Unreleased]` 下的内容改成 `## [新版号] - YYYY-MM-DD`，并在文件底部补版本链接。
2. 按上表改版号，`isDevelopment` 设为 `false`。
3. 跑 `Scripts/dev/lint.sh --changed`；改过 QML 就跑 `Scripts/dev/qmlfmt.sh <路径>`。
4. 界面验证：`Scripts/test/verify.sh <名字> --scenes settings-about`，至少覆盖关于页。
5. 提交 `chore(release): nosdshell v<版号>`，打附注 tag，推送 `main` 和 tag。tag 已经打好而只是推送失败时，补 `git push origin main nosdshell-v<版号>` 即可。
6. 推送后 CI 自动接管；想跟进度用 `gh run watch`。
7. CI 没跑成时的兜底：
   - Release：`gh workflow run release.yml -f tag=nosdshell-v<版号>`。
   - reopen：把 `isDevelopment` 改回 `true`，提交 `chore(release): reopen development after nosdshell-v<版号>` 并推送。
   - nosd-pkgs：按上面「更新 nosd-pkgs pin」一节在本地做。
8. Guix/Nix：分发由 nosd-pkgs 承担——pin 更新并推送之后，`guix pull` + `guix home reconfigure`（或 flake 侧 `nix flake update nosdshell`）即可用上该版。本仓不再含 channel/flake 定义。

## tag 约定

- 一律用附注 tag，命名为 `nosdshell-v<baseVersion>`（如 `nosdshell-v1.7.7`）。历史 `v*` tag（旧 nosDshell 布局，shell 在仓根）仍有效可引用，但**新 tag 一律带组件前缀**——`v*` 不再触发发布流水线。
- tag 推送后不再移动。打错且还没推送时，本地 `git tag -d` 后重打；已推送的错误 tag 用新版号纠正，不删除远端 tag。
