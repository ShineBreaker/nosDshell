import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v61 (dock.windowPreviews default)");

    // DDE AppSnapshot: hovering a taskbar app item shows live window previews.
    // Value-only key — the JsonAdapter applies the declared default when the
    // key is absent, so there is nothing to transform here.
    adapter.dock.windowPreviews = true;
    logger.i("Settings", "Migrated dock.windowPreviews:", true);

    return true;
  }
}
