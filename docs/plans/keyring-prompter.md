# SystemPrompter 自研方案：用 gcr4 库替代 gcr 3.41.2 的 gcr-prompter

状态：设计已定，待实施。
适用仓库：`quickshell-nosd`、`nosDshell`、`Guix-configs`。
编写依据：本机 gcr 4.2.1（Guix `gcr` 包）、oo7 0.7.1、quickshell-nosd 0.3.2 源码，以及 2026-11-13 的实测。

## 1. 目标与验收

目标：在不依赖 `gcr@3.41.2` 可执行 `gcr-prompter` 的前提下，为 oo7 的交互解锁提供 GUI 密码输入。

验收标准（全部满足才算完成）：

1. `busctl --user`（或 `gdbus`）能看到 `org.gnome.keyring.SystemPrompter` 名字被 shell 进程持有。
2. 在钥匙串锁定状态下触发一次 `secret-tool`（或任意 libsecret 应用），nosDshell 弹出密码框；输入正确密码后应用拿到 secret。
3. 输入错误密码：弹窗保留并显示错误提示，最多重试 5 次（oo7 的 `MAX_UNLOCK_ATTEMPTS`）。
4. 点取消：oo7 收到 dismissed，应用报错退出而不是永久阻塞。
5. 同一时刻两个应用请求解锁：排队，逐个弹窗。
6. 移除 home profile 里的 `gcr@3.41.2` 后以上行为不变。

## 2. 背景与结论

现状（`Guix-configs/source/config.org:1796`）：oo7 取代 gnome-keyring，但本机 `initial-session-user` 自动登录，PAM 拿不到密码，钥匙串每次开机锁定。oo7 在图形会话里把解锁提示交给 `org.gnome.keyring.SystemPrompter`，而这个 D-Bus 服务的唯一实现是 gcr 3.x 的 `gcr-prompter`。gcr 4 删掉了可执行文件，所以 home 包显式锁了 `gcr@3.41.2`。

调查结论：gcr 4 **没有**删掉 SystemPrompter 能力，只删掉了那个壳程序。

- `gcr-4.2.1/lib/libgcr-4.so` 导出 `gcr_system_prompter_new/register/unregister` 与 `gcr_secret_exchange_begin/receive/send`。
- `gcr-system-prompter.c`（gcr3 3.41.2 下 1160 行）在 4.4.1 里仍完整保留，D-Bus 协议、`sx-aes-1` 加密交换、多轮重试、回调管理全在库里。
- 需要我们自己实现的只有 `GcrPrompt` 接口的 5 个虚函数，加上一层 UI。
- gcr3 的 `gcr-prompter` 本身也只是 `ui/gcr-prompter-tool.c`（257 行）+ `ui/gcr-prompt-dialog.c`（GTK3）。

已实测（2026-11-13，`dbus-run-session` + 最小 C 程序）：

```text
NAME_ACQUIRED org.gnome.keyring.SystemPrompter
node /org/gnome/keyring/Prompter
  interface org.gnome.keyring.internal.Prompter
    BeginPrompting / PerformPrompt / StopPrompting
```

即 gcr4 库 + 自定义 `GcrPrompt` 的注册路径成立。实测坑：编译必须加 `-DGCR_API_SUBJECT_TO_CHANGE`，否则 `gcr.h` 直接 `#error`。

## 3. 架构

```mermaid
flowchart LR
    app["libsecret 应用"] -->|Unlock| oo7["oo7-daemon"]
    oo7 -->|PerformPrompt| prompter["quickshell KeyringPrompter<br/>(GcrSystemPrompter)"]
    prompter -->|"Qt 信号"| ui["nosDshell 插件弹窗"]
    ui -->|respond / cancel| prompter
    prompter -->|"GcrSecretExchange 加密"| oo7
```

分层理由：Quickshell 没有 QML 层的 D-Bus 服务 API（`src/dbus/` 只有 DBusMenu 专用模块），服务端必须写在 C++，与 polkit 的处理方式一致。

- 服务注册：`quickshell-nosd` 新增 `Quickshell.Services.Keyring` 模块（C++，GObject + Qt）。
- UI：`nosDshell/Assets/Plugins/keyring-prompter/`（QML 插件，内置、默认启用）。
- 服务的实例化放在 nosDshell 的核心 Service（`Services/Keyring/`），不依赖插件：插件被禁用时至少还能按超时取消请求，而不是把应用永久挂住。

## 4. 改动清单

### 4.1 quickshell-nosd

| 文件 | 动作 |
| --- | --- |
| `CMakeLists.txt` | 新增 `boption(SERVICE_KEYRING_PROMPTER "Keyring prompter" ON)` |
| `src/services/CMakeLists.txt` | 新增 `if (SERVICE_KEYRING_PROMPTER) add_subdirectory(keyringprompter) endif()` |
| `src/services/keyringprompter/CMakeLists.txt` | 新建；`pkg_check_modules(gcr REQUIRED IMPORTED_TARGET gcr-4)` |
| `src/services/keyringprompter/keyringprompter.hpp` | 新建；QML 类型 `KeyringPrompter` |
| `src/services/keyringprompter/keyringprompter.cpp` | 新建；D-Bus 名字、服务生命周期 |
| `src/services/keyringprompter/gcrprompt.hpp` | 新建；`GcrPrompt` GObject 子类 |
| `src/services/keyringprompter/gcrprompt.cpp` | 新建；5 个虚函数 → Qt 信号 |
| `src/services/keyringprompter/qml.cpp` | 新建（可选，照 polkit 的 `qml.cpp`） |

编译要点：

- `gcr-4` 的 pkg-config 依赖 `gck-2`，CMake 里直接 `PkgConfig::gcr` 即可。
- 头文件编译宏：`target_compile_definitions(... PRIVATE GCR_API_SUBJECT_TO_CHANGE)`。
- QML URI 建议 `Quickshell.Services.Keyring`，`qt_add_qml_module` + `install_qml_module` 照抄 `src/services/polkit/CMakeLists.txt`。

### 4.2 nosDshell

| 文件 | 动作 |
| --- | --- |
| `Services/Keyring/KeyringPrompterService.qml` | 新建；Singleton，实例化 `KeyringPrompter`，暴露给插件 |
| `Assets/Plugins/keyring-prompter/manifest.json` | 新建；内置插件清单 |
| `Assets/Plugins/keyring-prompter/Main.qml` | 新建；实例化弹窗 |
| `Assets/Plugins/keyring-prompter/PromptDialog.qml` | 新建；PanelWindow 密码框 |
| `Assets/Plugins/keyring-prompter/Settings.qml` | 可选；启用/超时设置（有消费方才加） |
| `DESIGN.md` §3.11 | 补充钥匙串对话框规格（复用 polkit 的 380 px / 24 px 密码框 / alert 状态） |
| `Scripts/test/verify.sh` | 可选；加 `keyring-prompter` 场景 |

插件 manifest 要点：

```json
{
  "id": "keyring-prompter",
  "name": "Keyring Prompter",
  "version": "1.0.0",
  "minNoctaliaVersion": "3.6.0",
  "author": "nosDshell",
  "license": "MIT",
  "description": "Password dialog for the oo7 Secret Service keyring",
  "tags": ["System"],
  "entryPoints": { "main": "Main.qml", "settings": "Settings.qml" },
  "dependencies": { "plugins": [] }
}
```

内置插件由 `PluginRegistry.scanPluginFolder` 自动打 `builtin=true`，且 `defaultEnabled !== false` 时默认启用（`Services/Plugins/PluginRegistry.qml:265-272`）。

### 4.3 Guix-configs

| 文件 | 动作 |
| --- | --- |
| `nosdshell.scm` | `quickshell/nosd` 的 `inputs` 追加 `gcr`（Guix 的 `gcr` 包即 4.2.1） |
| `nosdshell.scm` | 更新 `quickshell/nosd` 的 `source` commit 与 sha256（fork 推送后） |
| `source/config.org:2087` | 从 home 包移除 `"gcr@3.41.2"` |

注意：`gcr` 包在 Guix 里是 4.2.1；3.41.2 只能用 `gcr@3.41.2` 悔定。移除后 `~/.guix-home/profile/share/dbus-1/services/org.gnome.keyring.SystemPrompter.service` 随之消失。

## 5. C++ 实现要点

### 5.1 服务注册

`gcr_system_prompter_register()` 只注册对象路径，不带总线名；名字要自己 own。实测可用的最小流程：

```c
GDBusConnection* conn = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
GcrSystemPrompter* prompter =
    gcr_system_prompter_new(GCR_SYSTEM_PROMPTER_SINGLE, qs_gcr_prompt_get_type());

g_bus_own_name_on_connection(conn, "org.gnome.keyring.SystemPrompter",
                             G_BUS_NAME_OWNER_FLAGS_NONE,
                             on_name_acquired, on_name_lost, prompter, NULL);

static void on_name_acquired(GDBusConnection* connection, const gchar* name, gpointer user_data) {
    gcr_system_prompter_register(GCR_SYSTEM_PROMPTER(user_data), connection);
}
```

要点：

- 名字被别的实现占着时走 `on_name_lost`，此时不要 register，日志警告后退出（与 gcr-prompter 行为一致）。
- `GCR_SYSTEM_PROMPTER_SINGLE` 足够；多应用并发由 oo7 侧排队，库内部也会串行化。
- GLib 主循环：本机 `libQt6Core` 链接了 `libglib-2.0`，Qt 使用 glib event dispatcher，polkit 服务的 GObject 异步回调已在此模式下工作；新服务沿用同一模式即可。若实测回调不触发，退路是给服务单独起线程跑 `GMainLoop`，通过 Qt 信号跨线程。

### 5.2 GcrPrompt 子类

`GcrPrompt` 是接口，必须实现 5 个虚函数（`gcr-prompt.h`）：

```c
static void qs_prompt_iface_init(GcrPromptInterface* iface) {
    iface->prompt_password_async  = qs_prompt_password_async;
    iface->prompt_password_finish = qs_prompt_password_finish;
    iface->prompt_confirm_async   = qs_prompt_confirm_async;
    iface->prompt_confirm_finish  = qs_prompt_confirm_finish;
    iface->prompt_close           = qs_prompt_close;
}

static void qs_prompt_password_async(GcrPrompt* prompt, GCancellable* cancellable,
                                     GAsyncReadyCallback callback, gpointer user_data) {
    /* 用 GTask 接管回调，把请求转成 Qt 信号；QML 回复后 g_task_return_pointer */
    GTask* task = g_task_new(prompt, cancellable, callback, user_data);
    /* 保存 task，发出 passwordRequested(...) */
}
```

- 返回值经 `gcr_prompt_password_finish` 交回，密码由 `GcrSystemPrompter` 用 `GcrSecretExchange` 加密，QML 侧不接触交换协议。
- `prompt_confirm_async` 用于创建 keyring / 改密时的确认框；第一版可以只弹「继续/取消」。
- 属性（`title`/`message`/`description`/`warning`/`password_new`/`choice_label`/`caller_window`）由库在每次 `PerformPrompt` 前写好，子类用 `gcr_prompt_get_*()` 读，不要自己维护。
- 同一个 `GcrPrompt` 实例会被复用做多轮重试：每次 `password_async` 都算新一次弹窗，QML 要在每次请求时刷新 `warning`。

### 5.3 Qt 桥与 QML API

```cpp
class KeyringPrompter : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool isActive READ isActive NOTIFY activeChanged)
    Q_PROPERTY(QString title READ title NOTIFY promptChanged)
    Q_PROPERTY(QString message READ message NOTIFY promptChanged)
    Q_PROPERTY(QString warning READ warning NOTIFY promptChanged)
    Q_PROPERTY(QString promptType READ promptType NOTIFY promptChanged) // password | confirm

public:
    Q_INVOKABLE void respond(const QString& password);
    Q_INVOKABLE void confirm();
    Q_INVOKABLE void cancel();
signals:
    void activeChanged();
    void promptChanged();
};
```

- `KeyringPrompter` 用 `QML_ELEMENT` 暴露（照 `PolkitAgent` 的写法，`src/services/polkit/qml.hpp`）。
- prompt 实例到桥的关联：进程内单例即可（一个 shell 一个 prompter），`qs_prompt_*` 里取全局弱指针。
- `respond()` 调 `g_task_return_pointer(task, g_strdup(password), g_free)`；`cancel()` 用 `g_task_return_new_error(task, G_IO_ERROR, G_IO_ERROR_CANCELLED, ...)`。
- 新增请求（`PerformPrompt` 下一轮）时先 `promptChanged`，再置 `isActive = true`。
- 服务端 `StopPrompting` 会调 `prompt_close`：清掉挂起 task，`isActive = false`。

### 5.4 超时兜底

没有 UI 消费者（插件被禁用）时不能把调用方挂死。服务端收到请求后启动 60 秒定时器，超时按「用户取消」返回，并在日志里写明原因。这与 gcr-prompter 的 `QUIT_TIMEOUT` 思路一致。

## 6. QML 侧要点

`PromptDialog.qml` 直接照 `Modules/Polkit/PolkitAuthDialog.qml` 的结构：

- `PanelWindow` + `WlrLayershell.layer: Overlay` + `keyboardFocus: Exclusive`。
- 密码框、错误行、底部按钮条复用 `qs.Widgets` 与 `Commons/Style` 令牌；不要把数值写死在组件里。
- 有 `warning` 时输入框进 alert 状态，开始输入即清除（polkit 已有同款行为）。
- 用 `NSurfaceRegion` 把对话框矩形注册给 `BackgroundEffect.blurRegion`（DESIGN.md §1.2 的硬性要求）。
- 关闭时调用 `prompter.cancel()`，不要只 `visible = false`。

`Main.qml` 只做装配：

```qml
import QtQuick
import Quickshell
import qs.Services.Keyring

Item {
    id: root
    property var pluginApi: null

    PromptDialog {
        prompter: KeyringPrompterService.prompter
        visible: KeyringPrompterService.prompter.isActive
    }
}
```

## 7. 验证顺序

1. **编译**：`guix build -f nosdshell.scm quickshell-nosd`（或项目内的 `just build`），确认新增模块与 gcr 依赖能过。
2. **服务注册**：隔离会话启动 shell，`gdbus introspect --session --dest org.gnome.keyring.SystemPrompter --object-path /org/gnome/keyring/Prompter` 应看到三个方法。
3. **真实解锁**（隔离环境，参考 `Scripts/test/verify.sh`）：
   - 起 `oo7-daemon`，创建并锁定一个 keyring；
   - `secret-tool store` / `secret-tool lookup` 触发解锁；
   - 确认弹窗出现、密码正确时 secret 取回、错误时重试、取消时应用报错返回。
4. **并发**：两个 `secret-tool lookup` 同时触发，确认排队。
5. **移除 gcr3**：从 home 包去掉 `gcr@3.41.2`，`blue home` 后重复步骤 2–4。
6. **回归**：跑 `Scripts/dev/lint.sh --changed`；界面改动跑 `verify.sh` 截图对照 `DESIGN.md`，确认没有新增 QML 报错。

## 8. 风险与回退

| 风险 | 影响 | 处置 |
| --- | --- | --- |
| `org.gnome.keyring.internal.Prompter` 是 internal 接口 | gcr 大版本可能改协议 | 锁 gcr 4.2.1/4.4.1；升级时重跑第 7 节 |
| GLib 异步回调不被 dispatch | 弹窗不出现 | 先验证；必要时服务独立线程跑 `GMainLoop` |
| 插件被禁用 | 无人应答，应用阻塞 | 服务侧 60 s 超时取消；`DESIGN.md` 记录该行为 |
| 与 gcr3 prompter 抢名字 | 一方 `on_name_lost` | 先移除 home 的 `gcr@3.41.2` 再启用新服务 |
| 焦点/层 shell 行为与 polkit 不同 | 弹窗被窗口盖住 | 复用 PolkitAuthDialog 的 `WlrLayershell` 配置，用 `Scripts/test/niri/` 实测 |

回退：删掉插件、从 `source/config.org` 恢复 `"gcr@3.41.2"`、`blue home`。C++ 服务保留不影响（名字被 gcr-prompter 占用时会自己退出）。

## 9. 建议的提交拆分

1. `quickshell-nosd`：`feat(services): add keyring prompter backed by gcr4`
2. `nosDshell`：`feat(plugins): add keyring prompter dialog`
3. `nosDshell`：`docs(design): document keyring unlock dialog`
4. `Guix-configs`：`feat(nosdshell): drop gcr 3.41.2 in favour of the built-in prompter`

每个提交独立可验证；第 4 步在 1–3 验证通过后再做。
