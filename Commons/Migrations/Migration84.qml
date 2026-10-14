import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v84 (per-favorite darkMode removed)");

    // The darkMode boolean on each wallpaper.favorites[] entry duplicated
    // the appearance slot (deb79261d introduced appearance; darkMode is the
    // older upstream key) and is unrelated to the global shell light/dark
    // mode. Convert any straggler entries still keyed on the old boolean,
    // then drop the field: after this migration the favorite lookup reads
    // appearance only (the WallpaperService TODO this closes).

    function convert(list) {
      if (!list) {
        return;
      }
      for (var i = 0; i < list.length; i++) {
        var entry = list[i];
        if (!entry) {
          continue;
        }
        if (entry.appearance !== "light" && entry.appearance !== "dark") {
          entry.appearance = entry.darkMode ? "dark" : "light";
        }
        delete entry.darkMode;
      }
    }

    convert(rawJson?.wallpaper?.favorites);
    convert(adapter.wallpaper?.favorites);

    return true;
  }
}
