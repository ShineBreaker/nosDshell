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

自动化入口分两段：本地打 tag，CI 收尾。人只需要准备 CHANGELOG 和版号。

本地 `Scripts/dev/release.sh <X.Y.Z>`（或 `just release <X.Y.Z>`）分两个阶段：

1. `[Unreleased]` 为空时，脚本根据 `v<上一版>..HEAD` 的提交生成带链接的条目草稿，简介段留 TODO，然后停下。
2. 填好简介后重跑同一命令，脚本完成落版、改版号、校验、提交、打 tag，并推送 main 和 tag。

`--no-push` 只在本地提交并打 tag，不推送——CI 因此不会运行；`--skip-verify` 跳过 lint 和关于页截图。

tag 推上去之后，CI 自动完成剩余步骤：

- `.github/workflows/release.yml` 发布 GitHub Release（正文取 CHANGELOG 对应条目），然后在 main 上补一个 reopen 提交，把 `isDevelopment` 改回 `true`。
- 同一个 workflow 触发 jeans 的 `nosdshell-release.yml`：那边跑 `scripts/check-updates/update_versions.py --only nosdshell`，在 `ShineBreaker/jeans` 建分支开 PR，更新 `%nosdshell-version` 和 `%nosdshell-source` 的 base32。更新逻辑只有 jeans 一份，nosDShell 侧不重复实现 hash。

jeans 那一步需要本仓库的 secret `JEANS_TOKEN`：一个对 `ShineBreaker/jeans` 有 `Actions: write` 的 PAT。没配时 job 只打 warning 并跳过，其余发版照常完成；PR 由 jeans 自己的 `GITHUB_TOKEN` 创建，不需要第二个密钥。

脚本中途失败时，按下面的手工步骤逐项完成：

1. `CHANGELOG.md`：把 `[Unreleased]` 下的内容改为 `## [新版号] - YYYY-MM-DD`，并在文件底部补版本链接。条目结构见文件头部说明。
2. 按上表改版号，`isDevelopment` 设为 `false`。
3. 跑 `Scripts/dev/lint.sh --changed`，确认没有新增错误；改过 QML 就跑 `Scripts/dev/qmlfmt.sh <路径>`。
4. 界面验证：`Scripts/test/verify.sh <名字> --scenes settings-about`，至少覆盖关于页。
5. 按 Conventional Commits 提交（如 `chore(release): ...`），建附注 tag 并推送：`git tag -a v<版号> -m "v<版号>" && git push origin v<版号>`，同时推送 `main`。
6. 推送后等 CI：`gh run watch`。需要重发已存在的 tag 时运行 `gh workflow run release.yml -f tag=v<版号>`。
7. CI 没跑成或没配 token 时的兜底：
   - Release：重发上面的 workflow。
   - reopen：把 `isDevelopment` 改回 `true`，提交 `chore(release): reopen development after v<版号>` 并推送。
   - jeans：`gh workflow run nosdshell-release.yml --repo ShineBreaker/jeans -f tag=v<版号>`；连这个也触发不了时，在 jeans 仓库里跑 `python3 scripts/check-updates/update_versions.py --only nosdshell`（需要 `pip install requests`），确认只改了 `modules/jeans/packages/desktop.scm` 的两行，再提交推送。
8. Guix：本仓库即 Guix channel（`.guix-channel`），包的 `source` 始终是 `local-file` 的当前 checkout——`guix pull` 用户 pin 到 `v<版号>` tag 得到的就是该 tag 的树，`guix build -f nosdshell.scm` 打包的是工作区，两者共用同一份定义，无需改动。jeans 的 PR merge 之后，`guix pull` 再 `guix home reconfigure` 即可用上该版。

## tag 约定

- 一律用附注 tag，命名为 `v<baseVersion>`（如 `v1.0`）。
- tag 推送后不再移动。打错且还没推送时，本地 `git tag -d` 后重打；已推送的错误 tag 用新版号纠正，不删除远端 tag。
