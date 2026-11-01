import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  required property var cardsModel
  required property list<var> cardsDefault

  // Canonical gauge order for the media/sysmon card; the settings key stores
  // the enabled subset. At least one gauge stays on — _setMetric refuses to
  // clear the last one. The fallback is the declared default, same as the
  // card itself uses.
  readonly property var _metricOrder: ["cpu", "temp", "mem", "disk"]
  readonly property var _defaultMetrics: Settings.getDefaultValue("controlCenter.sysmonMetrics") || ["cpu", "temp", "mem"]
  readonly property var sysmonMetrics: {
    const cfg = Settings.data.controlCenter.sysmonMetrics || [];
    const sel = _metricOrder.filter(m => cfg.indexOf(m) !== -1);
    return sel.length > 0 ? sel : _defaultMetrics;
  }

  function _metricOn(id) {
    return root.sysmonMetrics.indexOf(id) !== -1;
  }

  function _setMetric(id, on) {
    var cur = root.sysmonMetrics.slice();
    if (on && cur.indexOf(id) === -1) {
      cur.push(id);
    }
    if (!on) {
      cur = cur.filter(m => m !== id);
    }
    if (cur.length === 0) {
      return;
    }
    Settings.data.controlCenter.sysmonMetrics = _metricOrder.filter(m => cur.indexOf(m) !== -1);
  }

  readonly property bool mediaSysmonOn: {
    for (var i = 0; i < cardsModel.length; i++) {
      if (cardsModel[i].id === "media-sysmon-card")
        return !!cardsModel[i].enabled;
    }
    return false;
  }

  function saveCards() {
    var toSave = [];
    for (var i = 0; i < cardsModel.length; i++) {
      toSave.push({
        "id": cardsModel[i].id,
        "enabled": cardsModel[i].enabled
      });
    }
    Settings.data.controlCenter.cards = toSave;
  }

  NHeader {
    description: I18n.tr("panels.control-center.cards-desc")
  }

  ColumnLayout {
    spacing: Style.marginXXS
    Layout.fillWidth: true

    Connections {
      target: Settings.data.location
      function onWeatherEnabledChanged() {
        // Auto-disable weather card when weather is disabled
        var newModel = root.cardsModel.slice();
        for (var i = 0; i < newModel.length; i++) {
          if (newModel[i].id === "weather-card") {
            newModel[i] = Object.assign({}, newModel[i], {
                                          "enabled": Settings.data.location.weatherEnabled
                                        });
            root.cardsModel = newModel;
            saveCards();
            break;
          }
        }
      }
    }

    NReorderCheckboxes {
      Layout.fillWidth: true
      model: root.cardsModel
      disabledIds: Settings.data.location.weatherEnabled ? [] : ["weather-card"]
      onItemToggled: function (index, enabled) {
        var newModel = root.cardsModel.slice();
        newModel[index] = Object.assign({}, newModel[index], {
                                          "enabled": enabled
                                        });
        root.cardsModel = newModel;
        saveCards();
      }
      onItemsReordered: function (fromIndex, toIndex) {
        var newModel = root.cardsModel.slice();
        var item = newModel.splice(fromIndex, 1)[0];
        newModel.splice(toIndex, 0, item);
        root.cardsModel = newModel;
        saveCards();
      }
    }
  }

  // Media + system monitor card: which gauges it shows. Same sub-page and
  // group as the card's enable row (settings placement rule); the whole
  // group hides while the card is off, and the disk-path pick follows the
  // disk gauge.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    visible: root.mediaSysmonOn

    NHeader {
      label: I18n.tr("panels.control-center.card-media-sysmon")
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("system-monitor.cpu-usage")
      checked: root._metricOn("cpu")
      enabled: !checked || root.sysmonMetrics.length > 1
      onToggled: checked => root._setMetric("cpu", checked)
      defaultValue: root._defaultMetrics.indexOf("cpu") !== -1
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("system-monitor.cpu-temp")
      checked: root._metricOn("temp")
      enabled: !checked || root.sysmonMetrics.length > 1
      onToggled: checked => root._setMetric("temp", checked)
      defaultValue: root._defaultMetrics.indexOf("temp") !== -1
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("common.memory")
      checked: root._metricOn("mem")
      enabled: !checked || root.sysmonMetrics.length > 1
      onToggled: checked => root._setMetric("mem", checked)
      defaultValue: root._defaultMetrics.indexOf("mem") !== -1
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("system-monitor.disk")
      checked: root._metricOn("disk")
      enabled: !checked || root.sysmonMetrics.length > 1
      onToggled: checked => root._setMetric("disk", checked)
      defaultValue: root._defaultMetrics.indexOf("disk") !== -1
    }

    NComboBox {
      Layout.fillWidth: true
      visible: root._metricOn("disk")
      label: I18n.tr("panels.control-center.system-monitor-disk-path-label")
      description: I18n.tr("panels.control-center.system-monitor-disk-path-description")
      model: {
        const paths = Object.keys(SystemStatService.diskPercents).sort();
        return paths.map(path => ({
                                    key: path,
                                    name: path
                                  }));
      }
      currentKey: Settings.data.controlCenter.diskPath || "/"
      onSelected: key => Settings.data.controlCenter.diskPath = key
      defaultValue: Settings.getDefaultValue("controlCenter.diskPath") || "/"
    }
  }
}
