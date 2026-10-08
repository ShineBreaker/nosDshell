# TOOLS — nosDshell 的 Rust 命令行工具

只在「这次改动要新写一个工具，或改 `tools/*/` 的依赖」时读本文件。改 QML、加设置、跑校验都不需要它。

## 什么时候写工具

QML 做不好的事——重计算、图像处理、系统级辅助——写成 **Rust** 命令行工具，放在 `tools/<名字>/`。

## 工具要求

- 参数只用 argv，结果写文件或 stdout，用退出码表示成败。
- shell 侧找不到工具时要能退回到其他方案，并输出一次 `Logger.w`——工具装不上不能让整个功能挂掉。

## crate 版本选择

优先用发布超过 7 天的 crate 版本（新版本被撤回或发坏是常态，7 天是「没被撤回」的代理信号），并锁定版本。`Cargo.lock` 要提交。

## 改依赖必须同步 Guix vendor 清单

`packaging/rust-crates.scm` 是 Guix 离线构建 `tools/*/` 的全部 crate 源，lockfile 里有而它没有的 crate，构建时会报 `no matching package named ...`。

流程：

1. `guix import crate --lockfile=tools/<名>/Cargo.lock <名>`
2. 把拆出来的段并进 `packaging/rust-crates.scm`，与前面各段去重
3. 确认 `nosd-<名>-cargo-inputs` 覆盖 lockfile 每一项

手工补单条也行：crate 哈希可对本地缓存跑 `guix hash $CARGO_HOME/registry/cache/*/<名>-<版本>.crate` 得到（本机 `CARGO_HOME=~/.local/share/cargo`）。

## 验证

```sh
cargo build --release --manifest-path tools/<名字>/Cargo.toml
cargo test --manifest-path tools/<名字>/Cargo.toml
```

vendor 清单改动用 Guix 包验证（构建不过就说明清单没覆盖全）：

```sh
guix build -L . -e '(@ (nosdshell) nosd-<名>)'
```

## shell 运行时是什么

本机是 Guix，没有 Nix；shell 跑在上游 `quickshell` 上。`nosdshell.scm` 打包的 `quickshell-nosd` = 我们的 fork `ShineBreaker/quickshell-nosd`（上游 0.3.2 + 两个 pipewire UAF 修复 commit）——需要 pipewire 补丁就用这个已打包的包。音频频谱由 cava 子进程提供（`Services/Media/SpectrumService.qml`）；`QS_PKG=noctalia-qs` 只用于对照那个已归档停更的 fork。