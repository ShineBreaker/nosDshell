import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v77 (fashion dock plugin strip: spacing + fused pill)");

    if (rawJson?.dock?.pluginSpacing === undefined) {
      adapter.dock.pluginSpacing = 4;
    }
    if (rawJson?.dock?.fusedPlugins === undefined) {
      adapter.dock.fusedPlugins = false;
    }

    return true;
  }
}
