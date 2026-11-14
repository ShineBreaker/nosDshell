import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v74 (persisted DND + ethernet layout keys)");

    // DND moves from volatile service state to a persisted setting.
    // Missing keys fall back to adapter defaults; set explicitly anyway.
    if (rawJson?.notifications?.doNotDisturb === undefined) {
      adapter.notifications.doNotDisturb = false;
    }
    // The ethernet panel reused the wifi layout key; it gets its own.
    if (rawJson?.network?.ethernetDetailsViewMode === undefined) {
      adapter.network.ethernetDetailsViewMode = "grid";
    }
    logger.i("Settings", "DND:", adapter.notifications.doNotDisturb, "ethernet layout:", adapter.network.ethernetDetailsViewMode);

    return true;
  }
}
