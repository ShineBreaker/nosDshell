---
title: Release Process
nav_exclude: true
---

# 发版流程

## 现状

- 仓库此前没有任何 tag（本地 `git tag -l`、远端 tags、GitHub Releases 均为零）；`v1.0` 是第一个 tag。
- 版号唯一真相源是 `Commons/Version.qml` 的 `baseVersion`，其它位置与它同步（下表）。
- `CHANGELOG.md` 是发版文案来源：发版时对应版本的条目即 GitHub Release 的正文。
- GitHub Release 由 CI 自动发布（`.github/workflows/release.yml`）：推 `v*` tag 后校验四处版号与 `isDevelopment=false`，抽 CHANGELOG 对应条目做正文，产出 `nosdshell-<tag>.tar.gz` 与 `nosdshell-latest.tar.gz` 两个资产；对已存在的 Release 只刷新正文和资产。也支持 `workflow_dispatch` 手动重发指定 tag。

## 版号位置

| 位置 | 字段 | 发版时改成 |
| --- | --- | --- |
| `Commons/Version.qml` | `baseVersion` | 新版号（如 `"1.1"`） |
| `Commons/Version.qml` | `isDevelopment` | 发版提交置 `false`，发完用一次 reopen 提交置回 `true` |
| `nosdshell.scm` | `(version ...)` | 与 `baseVersion` 一致 |
| `flake.nix` | `version` 引号内的主版本号 | 新版号（`_<shortRev>` 后缀保留，不要动） |
| `nix/package.nix` | `version ? ...` 默认值 | 与 `baseVersion` 一致 |
| `tools/*/Cargo.toml` | 各工具 `version` | 独立版本，按需改，不跟随 shell 版号 |

`Modules/Panels/Settings/Tabs/About/VersionSubTab.qml` 的 commit 提取正则按 store 名 `nosdshell-<version>_<commit>` 通配，改版号时不用动。

界面显示：`isDevelopment=false` 时 About 页显示 `v<baseVersion>`；日常开发为 `v<baseVersion>-git`（另附 commit 短 hash）。

## 发版步骤

自动化入口：`Scripts/dev/release.sh <X.Y.Z>`（或 `just release <X.Y.Z>`）走完全部流程。它是两段的——`[Unreleased]` 为空时先按 `v<上一版>..HEAD` 的 commit 生成带链接的条目脚手架（营销段留 TODO）就停；填好简介后重跑同一命令完成落版、版号、校验、提交、tag、推送与 reopen。`--no-push` 只在本地提交+打 tag，`--skip-verify` 跳过 lint 和 About 截图。下面是被自动化的手工步骤，脚本失败时按此逐项执行：

1. `CHANGELOG.md`：把 `[Unreleased]` 下的内容落版为 `## [新版号] - YYYY-MM-DD`，并在文件底部补版本链接。条目结构见文件头注释（简介段 → `---` → 引用 commit 的正文）。
2. 按上表改版号，`isDevelopment` 置 `false`。
3. `Scripts/dev/lint.sh --changed` 无新增错误；改过 QML 就跑 `Scripts/dev/qmlfmt.sh <路径>`。
4. 界面验证：`Scripts/test/verify.sh <名字> --scenes settings-about`（至少覆盖 About 页；涉及任务栏模式 / 停靠方向 / 明暗 / 模糊时按 `AGENTS.md` 加 `--settings` 组合）。
5. 提交（Conventional Commits，如 `chore(release): ...`），建附注 tag 并推送：
   `git tag -a v<版号> -m "v<版号>" && git push origin v<版号>`，同时把 `main` 推上去。
6. CI 的 Release workflow 自动发布（校验版号、抽 CHANGELOG 条目、上传 tarball）。如需手动重发已存在的 tag：`gh workflow run release.yml -f tag=v<版号>`。
7. reopen：`isDevelopment` 置回 `true` 再提交一次，`[Unreleased]` 留空待写。
8. Guix 正式 release 构建：把 `nosdshell.scm` 的 `source` 从 `local-file` 换回 `git-fetch` 的 tag（见文件头注释），填好新 hash；验证 `guix build -f nosdshell.scm`。

## tag 约定

- 一律附注 tag，命名 `v<baseVersion>`（如 `v1.0`）。
- tag 一经推送不再移动；打错且未推送时本地删除重打（`git tag -d`），已推送的错 tag 用新版号纠正，不删远端 tag。
