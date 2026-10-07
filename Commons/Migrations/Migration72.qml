import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v72 (settings panel mode pinned to controlCenter)");

    // The settings-panel-mode picker is gone (DDE presents settings only
    // inside the control-center frame). Pin any legacy floating/panel value
    // so no invisible leftover switches the surface off the frame.
    if (adapter.ui.settingsPanelMode !== "controlCenter")
      adapter.ui.settingsPanelMode = "controlCenter";
    logger.i("Settings", "Migrated ui.settingsPanelMode:", adapter.ui.settingsPanelMode);

    return true;
  }
}
