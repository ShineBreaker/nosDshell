import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v63 (settings pages live in the control center)");

    // DDE control center (DESIGN §3.5.3): the settings pages moved into the
    // 408 px frame, so the panel mode becomes the default. Users who had
    // explicitly chosen a floating panel keep it — only the stock "attached"
    // default is upgraded, everything else is left as-is.
    if (adapter.ui.settingsPanelMode === "attached")
      adapter.ui.settingsPanelMode = "controlCenter";
    logger.i("Settings", "Migrated ui.settingsPanelMode:", adapter.ui.settingsPanelMode);

    return true;
  }
}
