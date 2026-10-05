import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v65 (nosDshell rebrand)");

    // The upstream services these keys drove no longer exist in nosDshell,
    // so the persisted keys are dead weight.
    if (rawJson.general) {
      delete rawJson.general.showChangelogOnStartup;
      delete rawJson.general.telemetryEnabled;
    }

    // Settings group rename: noctaliaPerformance -> performance
    if (rawJson.noctaliaPerformance !== undefined) {
      rawJson.performance = rawJson.noctaliaPerformance;
      delete rawJson.noctaliaPerformance;
    }

    // Location: weatherTaliaMascotAlways -> weatherMascotAlways
    if (rawJson.location && rawJson.location.weatherTaliaMascotAlways !== undefined) {
      rawJson.location.weatherMascotAlways = rawJson.location.weatherTaliaMascotAlways;
      delete rawJson.location.weatherTaliaMascotAlways;
    }

    // Hook command keys
    if (rawJson.hooks) {
      if (rawJson.hooks.noctaliaPerformanceModeEnabled !== undefined) {
        rawJson.hooks.performanceModeEnabled = rawJson.hooks.noctaliaPerformanceModeEnabled;
        delete rawJson.hooks.noctaliaPerformanceModeEnabled;
      }
      if (rawJson.hooks.noctaliaPerformanceModeDisabled !== undefined) {
        rawJson.hooks.performanceModeDisabled = rawJson.hooks.noctaliaPerformanceModeDisabled;
        delete rawJson.hooks.noctaliaPerformanceModeDisabled;
      }
    }

    // Widget id and per-widget key renames, wherever they appear
    // (bar.widgets.*, bar.screenOverrides.*, controlCenter.*, dock.plugins,
    // desktopWidgets.monitorWidgets, calendar.cards)
    renameWidgetEntries(rawJson, logger);

    return true;
  }

  function renameWidgetEntries(node, logger) {
    if (node === null || node === undefined)
      return;

    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++)
        renameWidgetEntries(node[i], logger);
      return;
    }

    if (typeof node === "object") {
      if (node.id === "NoctaliaPerformance")
        node.id = "PerformanceMode";
      if (node.showNoctaliaPerformance !== undefined) {
        node.showPerformanceMode = node.showNoctaliaPerformance;
        delete node.showNoctaliaPerformance;
      }
      for (var key in node) {
        if (key === "id")
          continue;
        renameWidgetEntries(node[key], logger);
      }
    }
  }
}
