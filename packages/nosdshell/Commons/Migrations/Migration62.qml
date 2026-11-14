import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v62 (DDE launcher mode keys)");

    // DDE launcher (DESIGN §3.4): fullscreen vs mini view, free vs category
    // layout, grid icon ratio. Value-only keys — the JsonAdapter applies the
    // declared defaults when the keys are absent.
    adapter.appLauncher.mode = "fullscreen";
    adapter.appLauncher.displayMode = "free";
    adapter.appLauncher.iconRatio = 0.5;
    logger.i("Settings", "Migrated appLauncher.mode/displayMode/iconRatio:", "fullscreen", "free", 0.5);

    return true;
  }
}
