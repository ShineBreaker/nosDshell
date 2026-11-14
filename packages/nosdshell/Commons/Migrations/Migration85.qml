import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v85 (bundled usb-drive-manager dock entry)");

    // The bundled usb-drive-manager plugin ships enabled by default (DDE's
    // disk-mount applet parity). Its bar widget only renders when a plugin:*
    // entry exists in dock.plugins; append one before Trash so existing users
    // get the applet without re-adding it through the plugins page. With
    // hideWhenEmpty on (the vendored default) the icon stays invisible until a
    // removable device appears, so this costs nothing when unused.
    var plugins = adapter.dock?.plugins;
    if (plugins) {
      var id = "plugin:usb-drive-manager";
      var present = false;
      var trashIndex = -1;
      for (var i = 0; i < plugins.length; i++) {
        if (!plugins[i])
          continue;
        if (plugins[i].id === id)
          present = true;
        if (plugins[i].id === "Trash")
          trashIndex = i;
      }
      if (!present) {
        plugins.splice(trashIndex >= 0 ? trashIndex : plugins.length, 0, {
          "id": id
        });
        adapter.dock.plugins = plugins;
        logger.i("Settings", "dock.plugins: appended", id);
      }
    }

    return true;
  }
}
