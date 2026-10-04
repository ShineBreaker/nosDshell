import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v60 (bar -> dock taskbar mapping)");

    var bar = rawJson && rawJson.bar ? rawJson.bar : {};

    // Users with an existing config had a bar -> map to efficient (taskbar) mode
    adapter.dock.mode = "efficient";
    logger.i("Settings", "Migrated dock.mode:", "efficient");

    // dock.enabled now gates the taskbar in both modes — keep it on so the
    // migrated bar does not silently disappear for users who had disabled
    // the old floating dock
    adapter.dock.enabled = true;
    logger.i("Settings", "Migrated dock.enabled:", true);

    var position = bar.position || "top";
    adapter.dock.position = position;
    logger.i("Settings", "Migrated dock.position:", position);

    // bar.widgets.left ++ center ++ right -> dock.plugins, dropping the
    // built-ins (Launcher/Taskbar) that the taskbar provides itself
    var plugins = [];
    var builtin = {
      "Launcher": true,
      "Taskbar": true
    };
    var sections = ["left", "center", "right"];
    if (bar.widgets) {
      for (var s = 0; s < sections.length; s++) {
        var list = bar.widgets[sections[s]];
        if (!list || list.length === undefined)
          continue;
        for (var i = 0; i < list.length; i++) {
          var entry = list[i];
          if (!entry || !entry.id || builtin[entry.id])
            continue;
          plugins.push(entry);
        }
      }
    }
    if (plugins.length > 0) {
      adapter.dock.plugins = plugins;
      logger.i("Settings", "Migrated dock.plugins:", JSON.stringify(plugins));
    }

    var hideMode = (bar.displayMode === "auto_hide") ? "keep-hidden" : "keep-showing";
    adapter.dock.hideMode = hideMode;
    logger.i("Settings", "Migrated dock.hideMode:", hideMode);

    var iconSize = 30;
    switch (bar.density) {
    case "comfortable":
      iconSize = 36;
      break;
    case "spacious":
      iconSize = 48;
      break;
    default:
      iconSize = 30;
      break;
    }
    adapter.dock.iconSize = iconSize;
    logger.i("Settings", "Migrated dock.iconSize:", iconSize);

    return true;
  }
}
