import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v78 (dead Noctalia layout keys removed)");

    // No reader anywhere: the DDE lock screen has no compact variant
    // (DESIGN §3.9), the session menu is a fixed full-screen layout
    // (DESIGN §3.8), and the control center is always on the right
    // (DESIGN §3.5.1). The persisted values cannot affect anything.
    if (rawJson.general) {
      delete rawJson.general.compactLockScreen;
    }
    if (rawJson.sessionMenu) {
      delete rawJson.sessionMenu.position;
      delete rawJson.sessionMenu.showHeader;
      delete rawJson.sessionMenu.largeButtonsStyle;
      delete rawJson.sessionMenu.largeButtonsLayout;
    }
    if (rawJson.controlCenter) {
      delete rawJson.controlCenter.position;
    }

    return true;
  }
}
