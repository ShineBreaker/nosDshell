# DEBUGGING：取证与复现

本文件收集定位界面问题的工具。取证要一直做到能写出 `AGENTS.md`「工作方式」要求的根因和影响面，现象消失不等于查完。

## 打开调试

调试模式有四个等价入口：设置 → 关于 → 调试开关；关于页 logo 连点 8 次；`qs ipc call debug toggle`；启动前设置 `NOSD_DEBUG=1`。查启动期问题只能用最后一种。

- 持久化字段是 `debug.enabled`。`Settings.isDebug` 是生效值，环境变量和设置任一打开即为真。
- `Logger.d` 只在 `Settings.isDebug` 为真时输出。验证环境默认不开调试，临时探针要么改用 `Logger.i`，要么用 `--settings` 打开 `debug.enabled`。日志里没有输出，先确认是不是这道门挡住了，再判断代码没执行。
- `debug.modules` 是 `Logger.d` 的模块白名单，逗号分隔，例如 `"Dock,Tray"`。留空表示全部放行。
- `debug.logLevel` 设为 `"warn"` 时，调试关闭状态下 `Logger.i` 也不输出，只保留警告和错误。

## 场景取证

以下命令都经 `qs ipc call` 调用，实现在 `Services/Debug/DebugService.qml`。

- `debug list` 列出已注册的场景根，命名为 `dock-<屏>`、`bar-<屏>`、`cc-<屏>`、`main-<屏>`。bar 只在高效模式下加载；cc 是控制中心面板；main 是整个 shell 表面。根名带屏幕名，先 `list` 确认再传参。
- `debug tree <根> [深度]` 按绘制顺序输出 `children[]`，与 Qt 投递 hover 时用的是同一份列表。layer 的 effectSource、effect 这类不可见子项也会列出，地址可以拿到 gdb 里对照。树很大时（>socket 上限）会返回 socket 错误，改用 `find`/`hit`。
- `debug find <根> <objectName>` 全子树按 objectName 找 item（无深度上限），返回 `describe()`：类型、`宽x高`、`@x,y`（窗口场景坐标）和 `G@x,y`（`mapToGlobal`）。定位深层元素（如设置页里 ~25 层的行）用它而不是 `tree`/`hit` 扫描。注册根下找不到时回退到该窗口的 `contentItem` 整树，因此 `Popup`/对话框（挂在窗口 Overlay 下、注册根的子树之外）也能命中。**坐标语义**：全屏窗口（main、cc、popupMenuWindow）两种坐标都等于屏幕坐标；layer-shell 窄条窗口（dock、bar 任务栏）Qt 位置恒为 (0,0)，`@`/`G@` 都只是条内局部值，点击前要加回屏幕偏移（底部停靠即 `y += 屏高 − 窗高`，窗高见 `debug tree` 首行 `window ... WxH`）；锚定 popup（ctxmenu 等）的 `G@` 是**父表面相对**坐标，同样要加父窗口偏移。
- `debug hit <根> <x> <y>` 沿 `childAt` 做命中测试直到最深节点（上限 40 层），并列出每一层所有覆盖该点的子项。用它回答"这个坐标的按下事件会交给谁"。坐标是 item 的场景坐标，根 Item 不随窗口屏幕偏移平移时即窗口坐标。
- `debug opened [深度]` 输出 `PanelService.openedPanel`。多屏下面板注册名不对时，用它拿到当前真正打开的面板。
- `debug watch <名字>` 给整棵子树挂上 `Component.destruction` 探针。事件投递途中有对象被销毁时，`DbgWatch` 日志会报出它的名字。
- `debug set <根> <objectName> <属性> <值>` 按 objectName 找到 item 并写属性。用于给指针够不到的输入灌状态，例如没有键盘注入时给搜索框填字。
- 另有 `debug status`、`debug dump`、`debug unwatch`。

`verify.sh --scenes` 的场景名和 `debug list` 的根名是两套命名，各自查。场景清单在 `Scripts/test/verify.sh` 头部。

## 真指针注入

`tools/nosd-helpers/target/release/nosd-helpers vinput click|jclick|scroll <x> <y> [...]` 通过 `zwlr_virtual_pointer_v1` 注入指针事件，进程存活期间虚拟指针一直有效。`verify.sh` 的隔离 sway 和 `Scripts/test/niri/` 的嵌套 niri 都支持该协议（把 `WAYLAND_DISPLAY` 指向对应 socket 即可）；用户的真实会话不要注入。`verify.sh` 的 `settings-tree` 场景是一个完整示例：先做命中探测，再注入点击，最后点外部关闭面板。

## 输入区域问题

症状是某块区域点不动，或点击落到了别的表面上。

Wayland 的输入归属只由 `wl_surface.set_input_region` 决定。QML 的 `transform` 只移动画面，不会更新输入区域，所以画面移走了，输入区域可能还停在原处。输入区域（`mask`）或模糊区域（`BackgroundEffect.blurRegion`）只要跟随某个 item 的几何、会随动画移动或需要在隐藏时摘除，就通过 `Commons/NSurfaceRegion.qml` 注册。它的头部注释列出了已知的平台陷阱和对应处理。排查时先看出问题的表面是否用了它、参数是否绑对（例如滑动动画要绑定动画中的实时值，而不是目标值）；还在手写 `Region { item: ... }` 跟踪几何的表面属于同一影响面，一并检查。查到新的陷阱，就把处理收进 `NSurfaceRegion`，并补进它的头部注释。

popup 表面（`PopupWindow`）同理：niri 的 `popups { blur true }` 规则会把整个 surface 矩形都模糊，透明像素也包含在内。形状带箭头（`NArrowRect`）或其他内部透明区的 popup 必须自己通过 `NSurfaceRegion` 发布只覆盖不透明本体的模糊区域（跟踪 `NArrowRect.bodyItem`），否则箭头两侧的透明余量会透出模糊背景，看起来像 popup 下方多出一条模糊带。

取证步骤：

1. 用 `WAYLAND_DEBUG=1` 跑 `verify.sh`，协议日志写进 `$NOSD_VERIFY_DIR/logs/<名字>.log`（默认目录是 `/tmp/nosd-verify`）。
2. 根据 `zwlr_layer_surface_v1.set_window_geometry` 或 `xdg_toplevel` 把 surface 编号对应到窗口。
3. 找到该 surface 最后一次生效的 `wl_region.add` 和 `set_input_region`。
4. 对比 `wl_pointer.enter` 实际落在哪个 surface。

`verify.sh` 的 `dock-fullscreen` 场景是一个完整流程：让窗口非浮动全屏，取证，向原 dock 位置注入点击，再恢复。sway 下 `fullscreen` 对浮动窗口无效，要先 `swaymsg floating disable`。

## Qt 类别日志与 core 验尸

Qt 类别日志只能在启动前用环境变量打开，QML 运行时改不了。常用的有 `QT_LOGGING_RULES="qt.quick.hover.trace=true"`（逐个 item 的 hover 投递）和 `qt.qml.binding.removal=true`。

core 验尸要设置 `QS_DISABLE_CRASH_HANDLER=1` 并执行 `ulimit -c unlimited`。Guix 下加载调试符号用 gdb 的 `add-symbol-file`，以绕过 `.gnu_debuglink` 的 CRC 校验。

## 现成脚本

- `Scripts/test/debug-smoke.sh`：调试功能全链路冒烟测试。
- `Scripts/test/repro-hover-crash.sh`：在嵌套 niri 里扫描指针、周期性重启 shell，并做 core 验尸。
