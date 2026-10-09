pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor

// Single dispatch point for session/power actions (action name ->
// CompositorService call). This switch used to live inline in both
// ShutdownActions.execute (Modules/Panels/SessionMenu) and the launcher's
// session search results (Modules/Panels/Launcher/Providers/SessionProvider),
// and the two copies had already drifted apart on "lock": the launcher bypassed
// the custom lock command. Routing every entry point through
// CompositorService.lock() (custom command first, lockScreen fallback —
// CompositorService.qml:650-658) makes all three surfaces behave identically.
//
// Being an engine-wide singleton, this object outlives panel unloading, so it
// is safe to call from Qt.callLater closures fired after launcher.close()
// unloads the panel (see 072eb6d05).
Singleton {
  id: root

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
