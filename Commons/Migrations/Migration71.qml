import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v71 (keybinds keyHome/keyEnd added)");

    // New keybind keys. Older configs simply lack the keys — the
    // JsonObject adapter fills declared defaults, so no rawJson surgery.
    return true;
  }
}
