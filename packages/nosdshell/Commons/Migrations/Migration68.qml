import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v68 (dock.windowPreviews removed)");

    // The window-preview popup is gone — hovering app items shows only the
    // title tooltip. Dropping the stale key keeps the dock section clean.
    if (rawJson.dock) {
      delete rawJson.dock.windowPreviews;
    }

    return true;
  }
}
