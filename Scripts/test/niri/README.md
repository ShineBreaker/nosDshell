# 嵌套 niri 验证环境

`verify.sh` 用无头 sway 验证 QML 内部行为（布局、绑定、文本渲染）。shell 与合成器之间的交互，例如 layer-shell 几何、exclusive zone、焦点与输入投递、多屏输出管理，只有在真实的 niri 代码路径上才能复现。本目录的脚本在真实 niri 会话里嵌套运行一个 niri，再在里面运行 nosDshell。

隔离级别与 `verify.sh` 相同。HOME、XDG 目录、dbus 总线和 runtime 目录都是独立的，真实会话的配置、通知服务和 IPC socket 不受影响。

原理：niri 检测到 `WAYLAND_DISPLAY` 时会使用 winit 后端，把自己渲染成真实会话里的一个窗口。脚本给它一套隔离的 XDG 环境和 `dbus-run-session` 私有总线，嵌套实例跑的是完整的 niri 协议栈，所有副作用都留在隔离目录里。

嵌套 niri 会以窗口形式出现在真实桌面上，大小等于 `NIRI_W` × `NIRI_H`。用户在场时先征得同意再运行。

## 快速开始

```bash
# 1. 建隔离目录、写 niri config 和 settings 种子（--settings 可深合并自定义种子）
Scripts/test/niri/bootstrap.sh

# 2. 在 dbus-run-session 私有总线里启动嵌套 niri，等待 wayland 和 IPC socket
Scripts/test/niri/start-niri.sh

# 3. 启动 nosDshell，等待 IPC 就绪
Scripts/test/niri/start-shell.sh

# 4. 驱动场景并截图
Scripts/test/niri/shot.sh /tmp/out/panel.png
Scripts/test/niri/burst.sh /tmp/out/cold-open cold 30   # 连拍 30 帧

# 5. 收尾（只按 pidfile 结束进程，不用 pkill）
Scripts/test/niri/stop.sh
```

场景脚本里先 `. "$(dirname "$0")/env.sh"`，之后可以直接使用这些函数：

```bash
qs settings open          # qs IPC，已指向嵌套 socket 和隔离环境
qs settings openTab dock  # 打开设置并跳到任务栏页
niri_msg layers           # 嵌套 niri 的 niri msg，已指向嵌套 NIRI_SOCKET
wait_shell_ready          # 轮询 ipc call state all，直到 shell 就绪
```

改设置不必走 IPC。直接编辑 `$NOSD_CONFIG_DIR/settings.json`（即 `$ISO/config/nosdshell/settings.json`），然后重启 shell：

```bash
python3 -c 'import json,os; p=os.environ["NOSD_CONFIG_DIR"]+"settings.json";
d=json.load(open(p)); d["dock"]["enabled"]=False; json.dump(d,open(p,"w"))'
# 然后结束 shell.pid 对应的进程，重新运行 start-shell.sh
```

## 脚本

| 脚本 | 作用 |
|---|---|
| `env.sh` | 被其他脚本 source 的公共环境：隔离根目录、XDG 导出、清除真实合成器的环境变量、socket 发现，以及 `qs`、`niri_msg`、`wait_shell_ready` 函数 |
| `bootstrap.sh` | 建隔离目录树，写 `config.kdl` 和 settings.json 种子（`--settings` 深合并） |
| `start-niri.sh` | 在 `dbus-run-session` 里启动嵌套 niri，等待 wayland 和 IPC socket |
| `start-shell.sh` | 在嵌套 wayland socket 上启动 `quickshell -p <仓库>`，等待 IPC 就绪；已在运行时拒绝重复启动 |
| `stop.sh` | 按 `runtime/*.pid` 逐个结束进程，10 秒后仍未退出则发 SIGKILL；只处理自己启动的 PID |
| `shot.sh` | 截一帧到目标路径 |
| `burst.sh` | 连拍 N 帧，文件名为 `<prefix>-NNN.png`，实际约 7 帧每秒，帧间隔由合成器决定 |

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `NOSD_NIRI_DIR` | `/tmp/nosd-niri-verify` | 隔离根目录。解析到 `$HOME` 或系统路径时脚本拒绝运行 |
| `QS_BIN` | 先找 PATH，找不到再用 `guix shell quickshell` 解析 | shell 二进制。不要填 guix store 路径，升级后会失效 |
| `NIRI_OUT` | `HEADLESS-1` | 嵌套输出名（winit 后端的输出名） |
| `NIRI_W` / `NIRI_H` | `1920` / `1080` | 嵌套输出分辨率，也就是窗口大小 |

## 嵌套 niri 的已知问题

`bootstrap.sh` 和截图脚本已经处理了以下问题，改脚本时保留这些处理。

1. winit 输出默认带 `transform: flipped vertically`，整个嵌套桌面上下颠倒。`config.kdl` 里必须显式写 `transform "normal"`。
2. 快捷键提示层每次启动都会弹出，而 winit 下 `niri msg windows` 返回空，IPC 关不掉它。只能在配置里写 `hotkey-overlay { skip-at-startup }`。
3. `screenshot-path` 只支持秒级精度，`%f` 会被当成字面量。连拍时每拍完一帧必须立即把文件移出接收目录。
4. shell 刚就绪的头几秒，`ipc call settings openTab` 会被静默丢弃。先 `wait_shell_ready`，等面板就绪后再 openTab。

## 输入注入

wlroots 的 `zwlr_virtual_pointer_v1`（`wlrctl`、`nosd-helpers vinput` 用的协议）在 niri 上不存在。点击类操作按以下优先级选择：

1. `qs ipc call ...`。面板开关、页面跳转、服务开关都有 IPC handler。
2. 直接改 `$ISO` 下的 `settings.json` 再重启 shell。这样得到的初始状态最干净。
3. 真实指针。嵌套窗口获得焦点后，真实鼠标事件会进入嵌套会话。这是最接近真实使用的端到端路径，但需要占用真实屏幕。

## 检查 shell.log

`start-shell.sh` 不关闭 Qt 分类日志。`QT_LOGGING_RULES=*=false` 会把 `TypeError`、`ReferenceError` 一起屏蔽，验证就失去意义。跑完场景后照常检查 `$ISO/log/shell.log` 里的 `.qml:行号` 报错。`$ISO/log/niri.log` 里 login1 和 xcursor 相关的 WARN 是隔离环境的已知噪声。

## 与 verify.sh 的分工

| 维度 | `verify.sh`（无头 sway） | `niri/`（嵌套 niri） |
|---|---|---|
| QML 布局、绑定、文本 | 支持 | 支持 |
| 场景编排 | 完整场景表，自动开窗口和写种子 | 手工组合脚本 |
| 输入注入 | `vinput` 虚拟指针 | 无虚拟指针（IPC、种子或真实指针） |
| layer-shell、exclusive zone、焦点投递 | 近似（wlroots 实现） | 真实 niri 路径 |
| 对真实会话的影响 | 无 | 桌面上出现一个嵌套窗口 |
| 适用场合 | 日常回归、提交前验证 | 合成器相关行为、sway 上复现不了的问题 |
