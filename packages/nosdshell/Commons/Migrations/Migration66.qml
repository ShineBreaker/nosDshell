import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v66 (weather mascot removed)");

    // The Talia mascot easter egg is gone; both spellings are dead weight
    // (65 renames the talia spelling for anyone upgrading through it).
    if (rawJson.location) {
      delete rawJson.location.weatherMascotAlways;
      delete rawJson.location.weatherTaliaMascotAlways;
    }

    return true;
  }
}
