import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v80 (keys dropped in d3f2097f2 removed from persisted files)");

    // d3f2097f2 dropped these schema keys without a migration, relying on
    // JsonObject ignoring undeclared keys. The persisted copies stay in user
    // files forever and would silently re-enter if a same-named key is ever
    // reintroduced. bar.rightClick* and dock.backgroundOpacity came back as
    // live keys (Migrations 76/79) and are deliberately NOT deleted.
    // This is a dead-key sweep, not a capability removal — §6.1's scope
    // note exempts it from the removal registry.
    if (rawJson.dock) {
      delete rawJson.dock.dockType;
      delete rawJson.dock.displayMode;
      delete rawJson.dock.sitOnFrame;
      delete rawJson.dock.size;
      delete rawJson.dock.floatingRatio;
      delete rawJson.dock.animationSpeed;
      delete rawJson.dock.showLauncherIcon;
      delete rawJson.dock.launcherPosition;
      delete rawJson.dock.inactiveIndicators;
      delete rawJson.dock.groupIndicatorStyle;
      delete rawJson.dock.showDockIndicator;
      delete rawJson.dock.indicatorThickness;
      delete rawJson.dock.indicatorColor;
      delete rawJson.dock.indicatorOpacity;
    }
    if (rawJson.general) {
      delete rawJson.general.boxRadiusRatio;
      delete rawJson.general.shadowDirection;
      delete rawJson.general.clockStyle;
      delete rawJson.general.clockFormat;
      if (rawJson.general.keybinds) {
        delete rawJson.general.keybinds.keyRemove;
      }
    }
    if (rawJson.location) {
      delete rawJson.location.showCalendarWeather;
    }
    if (rawJson.network) {
      delete rawJson.network.bluetoothDetailsViewMode;
      delete rawJson.network.disableDiscoverability;
    }
    if (rawJson.osd) {
      delete rawJson.osd.backgroundOpacity;
    }
    if (rawJson.ui) {
      delete rawJson.ui.settingsPanelSideBarCardStyle;
    }
    if (rawJson.wallpaper) {
      delete rawJson.wallpaper.hideWallpaperFilenames;
    }

    return true;
  }
}
