import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v70 (dock displayMode/position/monitors mapping)");

    var rawDock = rawJson && rawJson.dock ? rawJson.dock : {};
    var rawBar = rawJson && rawJson.bar ? rawJson.bar : {};

    // dock.displayMode is dead (DDE reads dock.hideMode) — carry an explicit
    // user value over only when hideMode was never set explicitly.
    if (rawDock.displayMode !== undefined && rawDock.hideMode === undefined) {
      var hideMode = (rawDock.displayMode === "auto_hide") ? "keep-hidden" : "keep-showing";
      adapter.dock.hideMode = hideMode;
      logger.i("Settings", "Migrated dock.hideMode:", hideMode);
    }

    // bar.position is masked by dock.position in fashion mode — copy it over
    // only when the user never set dock.position explicitly.
    if (rawBar.position !== undefined && rawDock.position === undefined) {
      adapter.dock.position = rawBar.position;
      logger.i("Settings", "Migrated dock.position:", rawBar.position);
    }

    // bar.monitors is compat data — dock.monitors is the single multi-screen
    // list for both modes (DDE "one taskbar"). Carry over only when set.
    if (rawBar.monitors !== undefined && rawDock.monitors === undefined) {
      adapter.dock.monitors = rawBar.monitors;
      logger.i("Settings", "Migrated dock.monitors:", JSON.stringify(rawBar.monitors));
    }

    // Additive only: legacy keys (dock.displayMode, bar.position, bar.monitors) are kept.
    return true;
  }
}
