import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

// Shared dde-shutdown power-action data, used by both the dde-shutdown panel
// (Modules/Panels/SessionMenu) and the in-lock-screen power row
// (Modules/LockScreen, DESIGN §3.9 "电源按钮会在锁屏内打开 §3.8 的按钮行").
// Keeping the artwork map and the action dispatch in one place means the two
// surfaces cannot drift apart.
//
// The artwork mapping is the one dde-shutdown/skin/shutdown.qss:1-40 declares
// per button objectName (qproperty-normalIcon / hoverIcon / pressedIcon):
//   ShutDownButton  -> poweroff_*.svg
//   RestartButton   -> reboot_*.svg
//   SuspendButton   -> suspend_*.svg
//   HibernateButton -> list_actions/sleep_*.svg   (:37-40, shared widgets resource)
//   LockButton      -> lock_*.svg
//   SwitchUserButton-> userswitch_*.svg
//   LogoutButton    -> logout_*.svg
// "重启到 UEFI" is nosDshell-only and has no DDE artwork, so it reuses reboot_*.
QtObject {
  id: root

  readonly property string ddeShutdownIcons: Quickshell.shellDir + "/Assets/DDE/gxde-session-ui/dde-shutdown/img/"
  readonly property string ddeWidgetIcons: Quickshell.shellDir + "/Assets/DDE/gxde-session-ui/widgets/img/"

  // Action metadata mapping (dde-shutdown contentwidget.cpp button order)
  readonly property var actionMetadata: {
    "shutdown": {
      "icon": "power",
      "artwork": "poweroff",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.shutdown"),
      "isShutdown": true
    },
    "reboot": {
      "icon": "refresh",
      "artwork": "reboot",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.reboot"),
      "isShutdown": false
    },
    "suspend": {
      "icon": "moon",
      "artwork": "suspend",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.suspend"),
      "isShutdown": false
    },
    "hibernate": {
      "icon": "snowflake",
      "artwork": "sleep",
      "artworkDir": "widgets/list_actions",
      "title": I18n.tr("common.hibernate"),
      "isShutdown": false
    },
    "lock": {
      "icon": "lock",
      "artwork": "lock",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.lock"),
      "isShutdown": false
    },
    "switchUser": {
      "icon": "user-switch",
      "artwork": "userswitch",
      "artworkDir": "shutdown",
      "title": I18n.tr("session-menu.switch-user"),
      "isShutdown": false
    },
    "logout": {
      "icon": "logout",
      "artwork": "logout",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.logout"),
      "isShutdown": false
    },
    "rebootToUefi": {
      "icon": "device-desktop",
      "artwork": "reboot",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.reboot-to-uefi"),
      "isShutdown": false
    }
  }

  // dde-launcher's searchwidget.cpp:66 — switch user is only offered with a
  // greeter; nosDshell has no switch-user action, so it stays hidden.
  readonly property bool switchUserAvailable: typeof CompositorService.switchUser === "function"

  // DDE button order (dde-shutdown contentwidget.cpp)
  readonly property var ddeOrder: ["shutdown", "reboot", "suspend", "hibernate", "lock", "switchUser", "logout", "rebootToUefi"]

  function metadata(action) {
    return actionMetadata[action];
  }

  function artworkUrl(action) {
    const metadata = actionMetadata[action];
    if (!metadata || !metadata.artwork) {
      return "";
    }
    const base = metadata.artworkDir === "shutdown" ? root.ddeShutdownIcons : root.ddeWidgetIcons + "list_actions/";
    return base + metadata.artwork;
  }

  // Build the option list from sessionMenu.powerOptions, ordered like DDE and
  // filtered against what the system can actually do.
  function buildOptions(extra) {
    const options = [];
    const byAction = {};
    const configured = Settings.data.sessionMenu.powerOptions || [];
    for (let i = 0; i < configured.length; ++i) {
      byAction[configured[i].action] = configured[i];
    }

    for (let i = 0; i < root.ddeOrder.length; ++i) {
      const action = root.ddeOrder[i];
      const settingOption = byAction[action];
      if (!settingOption || settingOption.enabled === false) {
        continue;
      }
      if (action === "switchUser" && !root.switchUserAvailable) {
        continue;
      }
      const metadata = root.actionMetadata[action];
      options.push({
                     "action": action,
                     "icon": metadata.icon,
                     "artworkUrl": root.artworkUrl(action),
                     "title": metadata.title,
                     "isShutdown": metadata.isShutdown,
                     "available": action !== "switchUser" || root.switchUserAvailable,
                     "countdownEnabled": settingOption.countdownEnabled !== undefined ? settingOption.countdownEnabled : true,
                     "command": settingOption.command || "",
                     "keybind": settingOption.keybind || ""
                   });
    }

    if (extra) {
      for (let i = 0; i < extra.length; ++i) {
        if (extra[i]) {
          options.push(extra[i]);
        }
      }
    }

    return options;
  }

  // Dispatch a power action. Shared so the panel and the lock screen row behave
  // identically (including lockOnSuspend routing).
  function execute(action) {
    switch (action) {
    case "lock":
      CompositorService.lock();
      break;
    case "suspend":
      if (Settings.data.general.lockOnSuspend) {
        CompositorService.lockAndSuspend();
      } else {
        CompositorService.suspend();
      }
      break;
    case "hibernate":
      CompositorService.hibernate();
      break;
    case "reboot":
      CompositorService.reboot();
      break;
    case "userspaceReboot":
      CompositorService.userspaceReboot();
      break;
    case "rebootToUefi":
      CompositorService.rebootToUefi();
      break;
    case "logout":
      CompositorService.logout();
      break;
    case "shutdown":
      CompositorService.shutdown();
      break;
    }
  }
}
