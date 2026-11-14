# TOOLS：Rust 命令行工具

QML 不擅长的工作（重计算、图像处理、系统级辅助）写成 Rust 命令行工具，放在 `tools/<名字>/`。现有工具是 `nosd-blur`、`nosd-helpers`、`nosd-theme`；新功能先看能否作为现有工具的子命令加进去，`nosd-helpers` 就是按单个二进制、多个子命令组织的。

## 工具要求

- 输入只用命令行参数，结果写到文件或 stdout，用退出码表示成败。
- shell 侧找不到工具或工具执行失败时，功能要退回到其他方案继续工作，并输出一次 `Logger.w`。工具装不上不能让整个功能失效。降级方案写进 `DESIGN.md` 中该工具的章节（§4）。

## 依赖

- crate 优先选发布超过 7 天的版本，并锁定版本。新发布的版本被撤回或发坏很常见，7 天没被撤回可以作为基本可靠的信号。`Cargo.lock` 要提交。
- `nosdshell/rust-crates.scm` 是 Guix 离线构建 `tools/*/` 时的全部 crate 来源。lockfile 里有而它没有的 crate，构建时会报 `no matching package named ...`。所以每次改依赖都要同步它：
  1. 运行 `guix import crate --lockfile=tools/<名字>/Cargo.lock <名字>`。
  2. 把生成的定义并进 `nosdshell/rust-crates.scm`，与已有定义去重。
  3. 确认 `nosd-<名字>-cargo-inputs` 覆盖了 lockfile 的每一项。

  只补一个 crate 时也可以手写定义，哈希用 `guix hash $CARGO_HOME/registry/cache/*/<名字>-<版本>.crate` 从本地缓存算出（本机 `CARGO_HOME=~/.local/share/cargo`）。

## 验证

```sh
cargo build --release --manifest-path tools/<名字>/Cargo.toml
cargo test --manifest-path tools/<名字>/Cargo.toml
```

改了 vendor 清单，再用 Guix 构建确认清单完整：

```sh
guix build -L . -e '(@ (nosdshell) nosd-<名字>)'
```

`verify.sh` 优先使用 `target/release` 下的构建产物，`just tools` 会一次构建全部工具。
