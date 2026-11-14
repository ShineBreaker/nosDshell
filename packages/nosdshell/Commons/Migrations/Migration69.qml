import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v69 (debug section added)");

    // New developer section. Older configs simply lack the keys — the
    // JsonObject adapter fills declared defaults, so no rawJson surgery.
    return true;
  }
}
