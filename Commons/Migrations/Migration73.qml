import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v73 (optional status bar keys go live)");

    // DESIGN §3.13: bar.enabled / bar.position / bar.displayMode /
    // bar.monitors are consumed again in fashion mode. Missing keys fall back
    // to adapter defaults; the only safety needed is pinning an out-of-range
    // displayMode left over from old Noctalia configs.
    if (adapter.bar.displayMode !== "always_visible" && adapter.bar.displayMode !== "auto_hide" && adapter.bar.displayMode !== "non_exclusive") {
      adapter.bar.displayMode = "always_visible";
    }
    const pos = adapter.bar.position;
    if (pos !== "top" && pos !== "bottom" && pos !== "left" && pos !== "right") {
      adapter.bar.position = "top";
    }
    logger.i("Settings", "Status bar:", adapter.bar.enabled, adapter.bar.position, adapter.bar.displayMode);

    return true;
  }
}
