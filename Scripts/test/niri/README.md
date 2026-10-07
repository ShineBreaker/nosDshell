# 嵌套 niri 验证环境

`verify.sh` 的 headless sway 覆盖 QML 内部行为（布局、绑定、文本渲染），但
**shell ↔ 合成器交互**类问题——layer-shell 几何、exclusive zone、焦点与输入
投递、多屏输出管理——只有在真 niri 代码路径上才复现得出来。本目录是一组在
**真实 niri 会话里嵌套跑 nosDshell** 的可组合脚本，隔离级别与 verify.sh
相同：独立 HOME/XDG/dbus/runtime，真会话配置、通知服务、IPC socket 一概不碰。

原理：niri 检测到 `WAYLAND_DISPLAY` 时自动走 winit 后端，把自身渲染成真
会话里的一个窗口。给它一套隔离的 XDG 环境 + `dbus-run-session` 私有总线，
嵌套实例内部再跑 nosDshell——跑的是**真 niri 26.04 的完整协议栈**，副作用
全部关在隔离目录里。

> 注意：嵌套 niri 会以窗口形式出现在真机桌面上（大小即 `NIRI_W`/`NIRI_H`）。
> 用户在场时不要跑；适合用户离场或明确允许时做合成器保真验证。

## 快速开始

```bash
# 1. 建隔离树 + niri config + settings 种子（可加 --settings 深合并自定义种子）
Scripts/test/niri/bootstrap.sh

# 2. 起嵌套 niri（dbus-run-session 私有总线，等 wayland+IPC socket）
Scripts/test/niri/start-niri.sh

# 3. 起 nosDshell（等 IPC ready）
Scripts/test/niri/start-shell.sh

# 4. 驱动场景 + 截图
Scripts/test/niri/shot.sh /tmp/out/panel.png
Scripts/test/niri/burst.sh /tmp/out/cold-open cold 30   # 30 帧连拍

# 5. 收场（只按 pidfile 杀，不 pkill）
Scripts/test/niri/stop.sh
```

场景驱动用 `env.sh` 里的 helper——在场景脚本里 `. "$(dirname "$0")/env.sh"`
之后直接可用：

```bash
qs settings open          # qs IPC（已对好嵌套 socket/隔离 env）
qs settings openTab dock  # 打开并跳 dock 页
niri_msg layers           # 嵌套 niri 的 niri msg（对好 NIRI_SOCKET）
wait_shell_ready          # 轮询 ipc call state all 直到就绪
```

改设置不用走 IPC：直接编辑 `$NOSD_CONFIG_DIR/settings.json`（=
`$ISO/config/nosdshell/settings.json`）后重启 shell：

```bash
python3 -c 'import json,os; p=os.environ["NOSD_CONFIG_DIR"]+"settings.json";
d=json.load(open(p)); d["dock"]["enabled"]=False; json.dump(d,open(p,"w"))'
# 然后 kill shell.pid + 重新 start-shell.sh
```

## 脚本

| 脚本 | 作用 |
|---|---|
| `env.sh` | 共享前置（被 source，不执行）：隔离根、XDG 导出、合成器指纹清洗、socket 发现、`qs`/`niri_msg`/`wait_shell_ready` helper |
| `bootstrap.sh` | 建隔离目录树、写 `config.kdl`、写 settings.json 种子（`--settings` 深合并） |
| `start-niri.sh` | `dbus-run-session` 里起嵌套 niri，等 wayland socket + IPC socket |
| `start-shell.sh` | 在嵌套 wayland socket 上起 `quickshell -p <REPO>`，等 IPC 就绪；拒绝重复起 |
| `stop.sh` | 按 `runtime/*.pid` 逐个 kill（10s 超时后 -9），只碰自己起的 PID |
| `shot.sh` | 单帧截图 → 目标路径（新增文件判定 + 立即搬走） |
| `burst.sh` | N 帧连拍 `<prefix>-NNN.png`（有效 ~7fps，帧距由合成器决定） |

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `NOSD_NIRI_DIR` | `/tmp/nosd-niri-verify` | 隔离根（会做 $HOME/系统路径安全检查） |
| `QS_BIN` | PATH → `guix shell quickshell` 解析 | shell 二进制；不要写 guix store 路径（升级即失效） |
| `NIRI_OUT` | `HEADLESS-1` | 嵌套输出名（winit 后端的输出名） |
| `NIRI_W` / `NIRI_H` | `1920` / `1080` | 嵌套输出分辨率（= 窗口大小） |

## 嵌套 niri 的四个坑（bootstrap 已全部内置，勿删）

1. **winit 输出默认 `transform: flipped vertically`**——整个嵌套桌面上下
   颠倒。`config.kdl` 里必须显式 `transform "normal"`。
2. **hotkey-overlay 每次都弹**且 winit 下 `niri msg windows` 返回空、IPC
   关不掉——只能 `hotkey-overlay { skip-at-startup }`。
3. **`screenshot-path` 只支持秒级精度**——`%f` 会变字面量；连拍必须每帧
   拍完立即搬出 incoming 目录（shot.sh/burst.sh 已封装）。
4. **`ipc call settings openTab` 在 shell 就绪头几秒会被静默吞**——先
   `wait_shell_ready`，面板就绪后再 openTab。

## 输入注入的限制

wlroots 的 `zwlr_virtual_pointer_v1`（`wlrctl`、`nosd-helpers vinput`）在
niri 上**不存在**。点击类操作按优先级用：

1. `qs ipc call ...`——面板开关、tab 跳转、服务 toggle 都有 IPC handler；
2. 直接改 `$ISO` 下的 `settings.json` + 重启 shell——状态种子最干净；
3. 真指针（cua 之类）——嵌套窗口获得焦点后真实鼠标事件会进入嵌套会话，
   是最真实的端到端路径，但需要真机屏幕可用。

## 判读 shell.log

`start-shell.sh` **不关** Qt 分类日志（`QT_LOGGING_RULES=*=false` 会把
TypeError/ReferenceError 一起吞掉，验证就失去意义）。跑完场景后照常检查
`$ISO/log/shell.log` 的 `.qml:行号` 报错；`$ISO/log/niri.log` 里
login1/xcursor 的 WARN 是隔离环境已知噪声。

## 与 verify.sh 的分工

| 维度 | `verify.sh`（headless sway） | `niri/`（嵌套 niri） |
|---|---|---|
| QML 布局/绑定/文本 | ✓ | ✓ |
| 场景编排成熟度 | 全场景表 + spawn 窗口 + seed | 手工组合脚本 |
| 输入注入 | `vinput` 虚拟指针 | 无虚拟指针（IPC/种子/真指针） |
| layer-shell / exclusive zone / 焦点投递 | 近似（wlroots） | **真路径** |
| 对真会话影响 | 无 | 桌面上出现一个嵌套窗口 |
| 适用 | 日常回归、提交前验证 | 合成器敏感行为、sway 上复现不了的 bug |

## 来源

管线由 hermes 在 2026-10-07 的设置修复终验中搭建（报告：
`.agents/workfile/settings-polish/report-hermes-final.md`），本次收编时
把硬编码 store 路径、`wayland-1` 写死、日志全静默三处不健壮的写法改掉，
其余语义保持一致。
