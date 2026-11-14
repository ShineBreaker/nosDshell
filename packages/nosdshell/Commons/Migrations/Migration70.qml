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

    // dock.monitors is the taskbar's screen list. bar.monitors later became
    // the status bar's own list (v73, DESIGN §3.13); at this version the
    // status bar did not exist yet, so carry the legacy value over only
    // when dock.monitors was never set explicitly.
    if (rawBar.monitors !== undefined && rawDock.monitors === undefined) {
      adapter.dock.monitors = rawBar.monitors;
      logger.i("Settings", "Migrated dock.monitors:", JSON.stringify(rawBar.monitors));
    }

    // Additive only: legacy keys are kept. bar.position/monitors became the
    // status bar keys at v73 (DESIGN §3.13); dock.displayMode stayed dead
    // and was deleted by v80.
    return true;
  }
}
