import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v79 (status-bar right-click action restored)");

    // Re-added keys: fill defaults where the user config lacks them; a
    // value left over from before the keys were dropped counts as a
    // deliberate choice and stays.
    if (rawJson?.bar?.rightClickAction === undefined) {
      adapter.bar.rightClickAction = "controlCenter";
    }
    if (rawJson?.bar?.rightClickFollowMouse === undefined) {
      adapter.bar.rightClickFollowMouse = true;
    }
    if (rawJson?.bar?.rightClickCommand === undefined) {
      adapter.bar.rightClickCommand = "";
    }

    return true;
  }
}
