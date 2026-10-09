import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v76 (per-surface opacity knobs: popup, dock)");

    if (rawJson?.ui?.popupOpacity === undefined) {
      adapter.ui.popupOpacity = 1.0;
    }
    if (rawJson?.dock?.backgroundOpacity === undefined) {
      adapter.dock.backgroundOpacity = 1.0;
    }

    // Transparency defaults were raised (less see-through frames). Only
    // lift users who never customised the keys — a deliberate value stays.
    if (rawJson?.ui?.panelBackgroundOpacity === 0.4) {
      adapter.ui.panelBackgroundOpacity = 0.65;
    }
    if (rawJson?.general?.dimmerOpacity === 0.2) {
      adapter.general.dimmerOpacity = 0.35;
    }

    return true;
  }
}
