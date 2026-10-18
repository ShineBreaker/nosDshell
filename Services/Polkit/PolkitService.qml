pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.Commons

// Polkit authentication agent (DESIGN §3.11, reference
// gxde-polkit-agent/AuthDialog.cpp). Owns the Quickshell PolkitAgent so the
// shell registers with polkitd at startup — no agent means privilege prompts
// die silently. The dialog window lives in
// Modules/Polkit/PolkitAuthDialog.qml and binds these aliases.
Singleton {
  id: root

  PolkitAgent {
    id: agent
    // Registration is a DBus round-trip — isRegistered flips after init.
    onIsRegisteredChanged: Logger.i("PolkitService", "Polkit agent registered:", isRegistered)
  }

  readonly property bool isRegistered: agent.isRegistered
  readonly property bool isActive: agent.isActive
  readonly property var flow: agent.flow

  function init() {
    // Instantiation alone starts registration with polkitd.
    Logger.d("PolkitService", "Polkit agent created");
  }
}
