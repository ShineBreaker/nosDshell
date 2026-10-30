# AGENTS.md：nosDshell

nosDshell 是 Noctalia v4（基于 Quickshell/QML 的 Wayland shell）的分叉，目标是用 DDE 15（deepin 15）的界面呈现 Noctalia 的全部功能。Noctalia 的业务内核原样继承，包括 Services、设置数据、挂件体系和插件机制。改造只发生在表现层和交互编排。

## 工作方式

这个仓库要长期维护。修一个问题，目标是让同一类问题以后不再出现。任何改动都要让代码库更收敛，即同一件事只有一种做法、一处实现。

收敛沿着代码库的分层进行。业务行为留在 `Services/` 和设置管线（`Commons/Settings.qml`、迁移）里，与上游语义一致；表现层的数值和样式收进令牌（`Commons/Style.qml`、`Commons/Colors.qml`）和公共件，与 `DESIGN.md` 一致；组件只负责组合。判断一处修复该落在哪里，先判断问题属于哪一层。

动手修改之前，先查清三件事：

1. 根因。用一句话写出问题为什么会发生。如果只能描述现象（"这里颜色不对"），说明还没查到底，要继续追到是哪个数据、令牌、绑定或接口给出了错误的值。业务问题先查本仓库 git 历史和上游实现（见「业务保真」），表现问题再查 `references/` 里的 DDE 源码。
2. 影响面。列出根因牵连的全部代码：同一个令牌、公共件、Service 属性或设置键的所有消费方，以及用同一种写法写成的同类实现（用 grep 搜同一模式）。
3. 收口点。找到这些实例共同经过的那一层，通常是令牌、公共件、Service、迁移或注册表。修复放在这一层，让所有实例一起改正。只有找不到共同层时才逐个文件修改，并在提交正文里说明原因。

修复之后留一道护栏，让同类问题再出现时被拦下或一眼认出。护栏可以是新令牌、收敛出来的公共件、迁移、`verify.sh` 场景，或分支文档里的一条通用规则。

一次修复做完的标准：

- 根因写进了提交正文。
- 影响面里同一根因的实例全部修好；根因不同的相关问题列给用户，由用户决定是否一起处理。
- 护栏已经就位，提交正文写明它是什么。

## 业务保真

- 分叉点是 `a08ff3619`（上游 `legacy-v4` 分支的最后一个提交），上游完整历史就在本仓库里。想知道上游原本怎么做，先看 `git show a08ff3619:<路径>` 或 `git diff a08ff3619..HEAD -- <路径>`，再决定怎么改。
- 功能优先复用 `Services/`、`Commons/` 和各注册表里的现有实现。改界面时保持 Service 的属性签名、信号语义和副作用不变。确实要改 Service 的行为，就在提交正文里写明上游语义为什么在这里不适用，例如 niri 或 PipeWire 的平台差异。
- 每份数据都要有消费方，包括 `Assets/settings-default.json` 的键、注册表里的挂件和 Service 暴露的接口。最常见的退化是上游功能的界面被砍掉而数据还留着。遇到这种情况先恢复接入；确定不要这个功能时，按下面的设置键规则清理。
- 设置键只有三种合法状态：
  - 活跃：有行为消费方。用户可调的键还要在当前生效的前端里有控件，只接在已删除或非默认前端上的控件不算。
  - 兼容：上游代码仍然读取它，但在 DDE 形态下取值固定。迁移把它钉在固定值上，`Commons/Settings.qml` 的声明处和 `DESIGN.md` 的对应章节都注明它是兼容数据以及原因。
  - 删除：功能已经不存在。写迁移从用户已存的配置里删掉它。

  迁移的写法见 `CODING_STANDARDS.md`。`lint.sh` 里的 `check-settings-keys.py` 强制这条规则，报 `no reader` 的键按上面三种状态处理。
- 删除任何上游能力都要有明确理由，写进提交正文，并登记到 `DESIGN.md` §6.1。noctalia 身份类组件（遥测、版本更新检查、GitHub 与赞助者服务、吉祥物）已经登记。

## 依据

- 视觉和交互以 `DESIGN.md` 为唯一依据。改任何可见界面、加组件、调颜色、尺寸或动效，或者决定 Noctalia 的某个功能落到 DDE 的哪个模块（对照表在 §2）之前，先读 `DESIGN.md` 的对应章节。
- 数值只有一条来路。`DESIGN.md` 给出数值，`Commons/Style.qml` 和 `Commons/Colors.qml` 把它定义成令牌，组件只读令牌。新数值在两个令牌文件里都没有时，先去 `references/` 找出处，把令牌加上，最后才在组件里使用。
- `references/` 是 GXDE-OS（DDE 15 的社区维护版）源码的浅克隆，只读，已被 git 忽略。数值、结构和行为都在这里查，仓库与组件的对照见 `references/README.md`。
- DDE 专属素材（时钟表盘、关机按钮、启动器和控制中心图标等）从 `references/` 复制原件，规则见 `DESIGN.md` §1.9。

## 运行与校验

开发机是 Guix，没有 Nix；云端容器里没有 Guix，有 Nix。测试脚本通过 `NOSD_PKG_BACKEND` 在两者之间切换，准备步骤见 `DEBUGGING.md`「运行环境」。`lefthook.yml` 声明的 pre-commit（QML 格式化、重建设置索引）要靠 `nix/shell.nix` 提供 lefthook，在 Guix 开发机上不会执行，这两步要自己跑。

- shell 跑在上游 `quickshell` 上。上游缺少两个 PipeWire 释放后使用（UAF）修复，需要它们时用 `nosdshell.scm` 打包的 `quickshell-nosd`（我们的 fork）。上游 quickshell 也没有内置音频频谱，频谱由 cava 子进程提供（`Services/Media/SpectrumService.qml`）。
- 常用命令包在 `justfile` 里，运行 `just` 可以列出全部。`just run` 和 `just restore` 会替换用户正在使用的 shell，`just release` 会推送 tag 和 main，这三条只在用户要求时运行。
- 运行验证一律用 `Scripts/test/verify.sh <名字>`。它在隔离的 dbus 会话和无头 sway 里运行，截图与日志的位置写在脚本头部。在用户的 niri 会话里直接起 `qs` 会接管他的通知服务并改写他的配置。
- 问题依赖真实 niri 行为时（layer-shell、exclusive zone、焦点与输入投递这类 sway 上复现不了的问题），用 `Scripts/test/niri/`，用法见目录内的 README。它会在用户桌面上打开一个窗口，用户在场时先征得同意。
- 结束进程时只 kill 自己启动时记下的 PID。用户会话里也有同名进程，例如 pipewire 和 wireplumber。

校验分级：

- 每次改完都跑 `Scripts/dev/lint.sh --changed`，不能出现新的错误。
- 界面改动还要用 `verify.sh` 截图，逐条对照 `DESIGN.md`，并确认日志里没有新增的 `TypeError`、`ReferenceError` 或 `.qml:行号` 报错。"新增"以改动前的状态为基线。拿不准时，用 `git worktree add <临时目录> <基线提交>` 取出基线，在那里先跑 `just tools` 构建 Rust 工具，再跑同一组场景对比，用完 `git worktree remove`。隔离环境缺少 NetworkManager、天气网络和完整的 BlueZ，由此产生的 WARN 在基线里同样存在，不算回归。
- 改动牵连到的每个设置维度，都要用 `--settings` 覆盖它的全部取值并分别截图。最常牵连的维度是两种任务栏模式、四个停靠方向、亮色与暗色、模糊开关。
- 涉及启动耗时或面板开合延迟的改动，先用 `Scripts/test/bench.sh` 建基线再对比，轮次和取值方法见脚本头部。

## 分支文档

按这次改动的性质读对应的文件：

- 写 QML、新增或修改设置、改界面文案时，读 [`CODING_STANDARDS.md`](./CODING_STANDARDS.md)。
- 界面行为不符合预期、需要取证或复现时，读 [`DEBUGGING.md`](./DEBUGGING.md)。
- 新写工具或改 `tools/*/` 的依赖时，读 [`TOOLS.md`](./TOOLS.md)。
- 发版时，读 [`docs/RELEASE.md`](./docs/RELEASE.md)。

## 维护文档

- 每条规则只写在一个地方。本文件放每次任务都用得上的规则，分支文档放只在某类任务里用的规则，`DESIGN.md` 放视觉与交互规格，其他位置需要时链接过去。
- 把一次修复的经验写进文档时，写成通用规则：在哪一类情况下怎么做，为什么。需要时附一个代码位置作为例子。事故经过写在提交正文里。
- `docs/` 同时是 GitHub Pages 站点，配置在 `docs/_config.yml`。`docs/legacy/` 由 `Scripts/docs/vendor-legacy-docs.py` 从上游 noctalia-docs 生成，CI 会重新生成并比对；要改其中内容，就改脚本后重新生成。

## 提交

- 每完成一块可以独立验证的工作，校验通过后就提交一次。
- 提交说明沿用 Conventional Commits，例如 `feat(dock): ...`、`style(tokens): ...`、`docs(design): ...`。正文写清为什么改、根因是什么、依据的参考位置（格式为 `仓库/路径:行号`）。
- 只提交本次任务改动的文件。工作区里有其他会话未提交的改动时，用 `git add <路径>` 只暂存自己的文件。
- 不 push，不改写历史。
