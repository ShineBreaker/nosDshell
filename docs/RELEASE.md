---
title: Release Process
nav_exclude: true
---

# 发版流程

**发版由 tag 触发。** 把带正确版号的 release commit 和 `v<版号>` 附注 tag 推到 `main`，`.github/workflows/release.yml` 会完成其余全部工作：校验版号、发布 GitHub Release、把 `isDevelopment` 改回 `true`、通知 jeans 更新 channel pin。本地不需要创建 Release，也不需要手动 reopen。

人只准备两样东西：`CHANGELOG.md` 的版本条目，以及各处同步的版号。

## 人做的事

1. 写 `CHANGELOG.md` 条目：在 `[Unreleased]` 下写一段面向用户的简介（一两句话，可以带宣传口吻），接一条 `---` 分割线，然后按类别列出本次改动并引用 commit。文件头部的说明就是格式。
2. 按下面的「版号位置」改版号。版号以 `Commons/Version.qml` 的 `baseVersion` 为准；发版提交里 `isDevelopment` 必须是 `false`，CI 会校验。
3. 提交 `chore(release): v<版号>`，打附注 tag，推送 `main` 和 tag：

   ```sh
   git tag -a v<版号> -m "v<版号>"
   git push origin main v<版号>
   ```

`Scripts/dev/release.sh <X.Y.Z>`（`just release`）把这三步串起来：`[Unreleased]` 为空时先生成带 commit 链接的条目草稿并停下，填好简介后重跑，完成落版、改版号、lint、关于页截图、提交、打 tag 和推送。`--no-push` 只在本地提交并打 tag（CI 因此不会运行），`--skip-verify` 跳过 lint 和关于页截图。

发版会推送 tag 和 main，只在用户要求时进行。

## CI 做的事

推 `v*` tag 后，`release.yml` 依次执行三个 job：

- **release**：校验 tag 与 `baseVersion`、`isDevelopment=false`、`nosdshell.scm`、`flake.nix`、`nix/package.nix` 和 wrapper 的 `--version` 行全部一致；按 CHANGELOG 对应条目生成正文；打包 `nosdshell-<tag>.tar.gz` 和 `nosdshell-latest.tar.gz`；创建或刷新 GitHub Release。Release 已存在时只刷新正文和附件。
- **reopen**：在 `main` 上把 `isDevelopment` 改回 `true`，提交 `chore(release): reopen development after v<版号>` 并推送。
- **jeans-pr**：触发 jeans 的 `nosdshell-release.yml`，由 jeans 侧更新 `%nosdshell-version` 与 `%nosdshell-source` 的 base32 并开 PR。hash 逻辑只有 jeans 一份，本仓库不重复实现。

jeans 那一步需要本仓库的 secret `JEANS_TOKEN`（对 `ShineBreaker/jeans` 有 `Actions: write`）。没配时 job 只打 warning 并跳过，其余发版照常完成；PR 由 jeans 自己的 `GITHUB_TOKEN` 创建。

需要重发一个已存在的 tag 时，用 `gh workflow run release.yml -f tag=v<版号>`，三个 job 都是幂等的。

## 版号位置

| 位置 | 字段 | 发版时改成 |
| --- | --- | --- |
| `Commons/Version.qml` | `baseVersion` | 新版号（如 `"1.1"`） |
| `Commons/Version.qml` | `isDevelopment` | 发版提交里设为 `false`，CI 在 reopen job 里改回 `true` |
| `nosdshell.scm` | `(version ...)` | 与 `baseVersion` 一致 |
| `nosdshell.scm` | wrapper 里 `--version` 输出行 | 与 `baseVersion` 一致（CI 校验） |
| `flake.nix` | `version` 引号内的主版本号 | 新版号，保留 `_<shortRev>` 后缀 |
| `nix/package.nix` | `version ? ...` 的默认值 | 与 `baseVersion` 一致 |
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
5. 提交 `chore(release): v<版号>`，打附注 tag，推送 `main` 和 tag。tag 已经打好而只是推送失败时，补 `git push origin main v<版号>` 即可。
6. 推送后 CI 自动接管；想跟进度用 `gh run watch`。
7. CI 没跑成时的兜底：
   - Release：`gh workflow run release.yml -f tag=v<版号>`。
   - reopen：把 `isDevelopment` 改回 `true`，提交 `chore(release): reopen development after v<版号>` 并推送。
   - jeans：`gh workflow run nosdshell-release.yml --repo ShineBreaker/jeans -f tag=v<版号>`；触发不了时在 jeans 仓库跑 `python3 scripts/check-updates/update_versions.py --only nosdshell`（需要 `pip install requests`），确认只改了 `modules/jeans/packages/desktop.scm` 的两行再提交推送。
8. Guix：本仓库即 Guix channel（`.guix-channel`），包的 `source` 始终是 `local-file` 的当前 checkout——`guix pull` 用户 pin 到 `v<版号>` tag 得到的就是该 tag 的树，`guix build -f nosdshell.scm` 打包的是工作区，两者共用同一份定义，无需改动。jeans 的 PR merge 之后，`guix pull` 再 `guix home reconfigure` 即可用上该版。

## tag 约定

- 一律用附注 tag，命名为 `v<baseVersion>`（如 `v1.0`）。
- tag 推送后不再移动。打错且还没推送时，本地 `git tag -d` 后重打；已推送的错误 tag 用新版号纠正，不删除远端 tag。
