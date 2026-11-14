pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Keyring
import qs.Commons

// Secret Service (oo7) keyring unlock backend (DESIGN §3.11). Owns the
// org.gnome.keyring.SystemPrompter bus name so an application asking for a
// locked keyring gets a dialog instead of blocking: without a SystemPrompter
// implementation the request has nowhere to go, and gcr 4 no longer ships gcr
// 3's gcr-prompter. The dialog window lives in
// Modules/Keyring/KeyringPromptDialog.qml and binds these properties.
Singleton {
  id: root

  KeyringPrompter {
    id: prompter

    onIsRegisteredChanged: Logger.i("KeyringPrompter", "System prompter registered:", isRegistered)
  }

  readonly property bool isRegistered: prompter.isRegistered
  readonly property bool isActive: prompter.isActive
  //! "password" or "confirm".
  readonly property string promptType: prompter.promptType
  readonly property string message: prompter.message
  readonly property string description: prompter.description
  //! Set by the caller after a failed attempt ("the password is incorrect").
  readonly property string warning: prompter.warning
  readonly property bool passwordNew: prompter.passwordNew

  function respond(password) {
    prompter.respond(password);
  }

  function confirm() {
    prompter.confirm();
  }

  function cancel() {
    prompter.cancel();
  }

  function init() {
    // Instantiation alone owns the bus name; a second implementation on the
    // bus (gcr 3's gcr-prompter) makes isRegistered stay false.
    Logger.d("KeyringPrompter", "Keyring prompter created");
  }
}
