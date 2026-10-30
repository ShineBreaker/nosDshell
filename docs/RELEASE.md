---
title: Release Process
nav_exclude: true
---

# 发版流程

- 版号以 `Commons/Version.qml` 的 `baseVersion` 为准，其他位置与它同步（见下表）。
- `CHANGELOG.md` 里对应版本的条目就是 GitHub Release 的正文。
- GitHub Release 由 CI（`.github/workflows/release.yml`）发布。推送 `v*` tag 后，CI 校验各处版号一致且 `isDevelopment=false`，抽取 CHANGELOG 对应条目作为正文，上传 `nosdshell-<tag>.tar.gz` 和 `nosdshell-latest.tar.gz` 两个附件。Release 已存在时只刷新正文和附件。也可以用 `workflow_dispatch` 手动重发指定 tag。

## 版号位置

| 位置 | 字段 | 发版时改成 |
| --- | --- | --- |
| `Commons/Version.qml` | `baseVersion` | 新版号（如 `"1.1"`） |
| `Commons/Version.qml` | `isDevelopment` | 发版提交里设为 `false`，发版后再用一次 reopen 提交改回 `true` |
| `nosdshell.scm` | `(version ...)` | 与 `baseVersion` 一致 |
| `nosdshell.scm` | wrapper 里 `--version` 输出行 | 与 `baseVersion` 一致（CI 校验） |
| `flake.nix` | `version` 引号内的主版本号 | 新版号，保留 `_<shortRev>` 后缀 |
| `nix/package.nix` | `version ? ...` 的默认值 | 与 `baseVersion` 一致 |
| `tools/*/Cargo.toml` | 各工具的 `version` | 独立版本，按需修改，不跟随 shell 版号 |

`Modules/Panels/Settings/Tabs/About/VersionSubTab.qml` 用正则从 store 名 `nosdshell-<version>_<commit>` 里提取 commit，适用于任何版号，改版号时不用动它。

`nosdshell --version`（或 `-V`）直接打印 `nosdshell v<版号> (with quickshell v<版号> <commit>)`，不启动 shell；Guix 构建附带 fork commit，Nix 构建附带 nixpkgs quickshell 版号。小写 `-v` 是 quickshell 的 verbose 开关，会正常透传启动。

关于页的版本显示：`isDevelopment=false` 时显示 `v<baseVersion>`；日常开发时显示 `v<baseVersion>-git`，后面附 commit 短 hash。

## 发版步骤

发版会推送 tag 和 main，只在用户要求时进行。

自动化入口是 `Scripts/dev/release.sh <X.Y.Z>`（或 `just release <X.Y.Z>`），分两个阶段：

1. `[Unreleased]` 为空时，脚本根据 `v<上一版>..HEAD` 的提交生成带链接的条目草稿，简介段留 TODO，然后停下。
2. 填好简介后重跑同一命令，脚本完成落版、改版号、校验、提交、打 tag、推送和 reopen。

`--no-push` 只在本地提交并打 tag；`--skip-verify` 跳过 lint 和关于页截图。

脚本中途失败时，按下面的手工步骤逐项完成：

1. `CHANGELOG.md`：把 `[Unreleased]` 下的内容改为 `## [新版号] - YYYY-MM-DD`，并在文件底部补版本链接。条目结构见文件头部说明。
2. 按上表改版号，`isDevelopment` 设为 `false`。
3. 跑 `Scripts/dev/lint.sh --changed`，确认没有新增错误；改过 QML 就跑 `Scripts/dev/qmlfmt.sh <路径>`。
4. 界面验证：`Scripts/test/verify.sh <名字> --scenes settings-about`，至少覆盖关于页。
5. 按 Conventional Commits 提交（如 `chore(release): ...`），建附注 tag 并推送：`git tag -a v<版号> -m "v<版号>" && git push origin v<版号>`，同时推送 `main`。
6. CI 的 Release workflow 自动发布。需要手动重发已存在的 tag 时，运行 `gh workflow run release.yml -f tag=v<版号>`。
7. reopen：把 `isDevelopment` 改回 `true` 再提交一次，`[Unreleased]` 留空。
8. Guix 无需额外步骤：本仓库即 Guix channel（`.guix-channel`），包的 `source` 始终是 `local-file` 的当前 checkout——`guix pull` 用户 pin 到 `v<版号>` tag 得到的就是该 tag 的树，`guix build -f nosdshell.scm` 打包的是工作区，两者共用同一份定义。jeans 频道里的固定 pin（`%nosdshell-version` + hash）需要单独 bump。

## tag 约定

- 一律用附注 tag，命名为 `v<baseVersion>`（如 `v1.0`）。
- tag 推送后不再移动。打错且还没推送时，本地 `git tag -d` 后重打；已推送的错误 tag 用新版号纠正，不删除远端 tag。
