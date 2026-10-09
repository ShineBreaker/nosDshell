# DEBUGGING — nosDshell 取证手册

只在「界面行为不符合预期、要找出原因或稳定复现」的分支读本文件。正常写功能、改设置、跑校验都不需要它。

## 打开调试

四个等价入口：设置 → 关于 → 调试 开关；关于页 logo 连点 8 次；`qs ipc call debug toggle`；启动前 `NOSD_DEBUG=1`（启动期取证用这一条）。

- 持久化字段是 `debug.enabled`；`Settings.isDebug` 是 env ∥ 设置的有效值。
- `debug.modules` 是 `Logger.d` 的模块白名单（逗号分隔，空 = 全部），如 `"Dock,Tray"`。
- `debug.logLevel` 为 `"warn"` 时 `Logger.i` 静默，只剩 w/e——禁用调试时的最小化日志。
- `Logger.d` 受 `debug.enabled` 门控：验证环境里没开调试时，临时探针改用 `Logger.i` 才会打出来。

## 场景取证

经 `qs ipc call` 使用，服务实现在 `Services/Debug/DebugService.qml`：

- `debug list` — 已注册的场景根：`dock-<屏>`、`bar-<屏>`、`cc-<屏>`、`main-<屏>`。bar 只在 efficient 模式加载，cc 是控制中心面板，main 是整个 shell surface。多屏时根名带屏名，先 `list` 确认再传，不要猜。
- `debug tree <根> [深度]` — 按绘制序 dump `children[]`，即 Qt hover 投递快照的同一份列表；layer 的 effectSource / effect 这类幽灵子项直接可见，地址可对 gdb。
- `debug hit <根> <x> <y>` — 沿 `childAt` 命中测试到最深节点，并列出每层所有盖住该点的子项；回答「这个坐标的 press 会落到谁手上」。
- `debug opened [深度]` — dump `PanelService.openedPanel`；多屏注册错名时用它拿「当前真正打开的面板」。
- `debug watch <名字>` — 给整棵子树挂 `Component.destruction` 探针，投递途中谁被销毁，`DbgWatch` 日志会报名字。
- `debug set <根> <objectName> <属性> <值>` — 按 objectName 找 item 写属性；往指针到不了的输入里灌状态（比如没键盘注入时给搜索框填词）。
- `debug status` / `debug dump` / `debug unwatch`。

`verify.sh --scenes` 的场景名与 `debug list` 的根名不是同一套命名，两边各自查（场景清单见 `Scripts/test/verify.sh` 头部注释）。

## 真指针注入

`tools/nosd-helpers/target/release/nosd-helpers vinput click|jclick <x> <y> [dx dy]`——走 `zwlr_virtual_pointer_v1`，进程存活期间虚拟指针有效。只在 `verify.sh` 的隔离 sway 里注入，用户真机会话不用。`verify.sh` 的 `settings-tree` 场景是现成示例（rail 命中探针 + 注入点击 + 外点关面板）。

## 输入归属排查（"某块区域点不动"）

表面内容 `transform` 划走 ≠ 输入区域释放——Wayland 输入归属只由 `wl_surface.set_input_region` 决定，QML transform 不产生 region 更新，mask 会冻结在动画前的矩形上。取证用 `WAYLAND_DEBUG=1` 跑 `verify.sh`（日志落在 `$WORK/logs/<名>.log`）：先认 `zwlr_layer_surface_v1.set_window_geometry` / `xdg_toplevel` 把 surface 编号对到窗口，再追 `wl_region.add` + `set_input_region` 的最后一次有效值，对比 `wl_pointer.enter` 落在哪个 surface。`verify.sh` 的 `dock-fullscreen` 场景（非浮窗全屏 → 取证 → 注入点击原 dock 条 → 恢复）是现成流程。注意 sway 下 `fullscreen` 对浮窗无效，先 `swaymsg floating disable`。quickshell 侧：`Region { item: X }` 的 mask 只在 item 的 x/y/w/h 变化时重建，transform 动画不触发——`Dock.qml` 的 sentinel（零尺寸 `Region` 绑动画值）就是为此加的逐帧 `changed` 泵。

## Qt 类别日志与 core 验尸

类别日志只能在**启动前**用环境变量打开，QML 运行时改不了：`QT_LOGGING_RULES="qt.quick.hover.trace=true"`（逐 item hover 投递）、`qt.qml.binding.removal=true` 等。

core 验尸：`QS_DISABLE_CRASH_HANDLER=1` 加 `ulimit -c unlimited`；Guix 下调试符号用 `add-symbol-file` 绕过 `.gnu_debuglink` 的 CRC。

## 现成脚本

- `Scripts/test/debug-smoke.sh` — debug 面全链路冒烟。
- `Scripts/test/repro-hover-crash.sh` — 嵌套 niri 指针扫描 + 周期重启 + core 验尸。

## 起 qs 之前

起 `qs` 是这条分支里最容易出事的一步，权威规则见 `AGENTS.md`「运行环境与校验」：验证一律走 `Scripts/test/verify.sh <名字>`（`dbus-run-session` + 无头 sway，HOME 与所有 XDG 目录隔离到 `/tmp`），用户正在使用的 niri 会话里不直接起；结束进程只 kill 自己启动时记下的 PID。

另外别让验证环境因为 `debug.enabled` 关闭而「没输出」就误判成没执行——临时探针按上面「打开调试」一节选日志级别。