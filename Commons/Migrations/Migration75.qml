import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v75 (modernization knobs: transient style, border/shadow/row-height scales, accent override, blur sigma)");

    if (rawJson?.ui?.transientSurface === undefined) {
      adapter.ui.transientSurface = "auto";
    }
    if (rawJson?.ui?.transientOpacity === undefined) {
      adapter.ui.transientOpacity = 1.0;
    }
    if (rawJson?.ui?.borderEmphasis === undefined) {
      adapter.ui.borderEmphasis = 1.0;
    }
    if (rawJson?.ui?.rowHeightScale === undefined) {
      adapter.ui.rowHeightScale = 1.0;
    }
    if (rawJson?.ui?.accentOverride === undefined) {
      adapter.ui.accentOverride = "";
    }
    if (rawJson?.general?.shadowStrength === undefined) {
      adapter.general.shadowStrength = 1.0;
    }
    if (rawJson?.wallpaper?.blurSigma === undefined) {
      adapter.wallpaper.blurSigma = 0;
    }
    logger.i("Settings", "transientSurface:", adapter.ui.transientSurface);

    return true;
  }
}
