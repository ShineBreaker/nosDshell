import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  width: 700

  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  property string valueStatType: settingsHelper.value("statType")
  property string valueDiskPath: settingsHelper.value("diskPath")
  property bool valueShowBackground: settingsHelper.value("showBackground")
  property bool valueRoundedCorners: settingsHelper.value("roundedCorners")
  property string valueLayout: settingsHelper.value("layout")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.system-stat-stat-type-label")
    description: I18n.tr("panels.desktop-widgets.system-stat-stat-type-description")
    currentKey: valueStatType
    minimumWidth: 260 * Style.uiScaleRatio
    model: {
      let items = [
            {
              "key": "CPU",
              "name": I18n.tr("system-monitor.cpu-usage")
            },
            {
              "key": "Memory",
              "name": I18n.tr("common.memory")
            },
            {
              "key": "Network",
              "name": I18n.tr("bar.system-monitor.network-traffic-label")
            },
            {
              "key": "Disk",
              "name": I18n.tr("system-monitor.disk")
            }
          ];
      if (Settings.data.systemMonitor.enableDgpuMonitoring)
        items.push({
                     "key": "GPU",
                     "name": I18n.tr("panels.system-monitor.gpu-section-label")
                   });
      return items;
    }
    onSelected: key => {
                  settingsHelper.set("statType", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.statType
  }

  NComboBox {
    Layout.fillWidth: true
    visible: valueStatType === "Disk"
    label: I18n.tr("bar.system-monitor.disk-path-label")
    description: I18n.tr("bar.system-monitor.disk-path-description")
    model: {
      const paths = Object.keys(SystemStatService.diskPercents).sort();
      return paths.map(path => ({
                                  key: path,
                                  name: path
                                }));
    }
    currentKey: valueDiskPath
    onSelected: key => {
                  settingsHelper.set("diskPath", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.diskPath
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.system-stat-show-background-label")
    description: I18n.tr("panels.desktop-widgets.system-stat-show-background-description")
    checked: valueShowBackground
    onToggled: checked => {
                 settingsHelper.set("showBackground", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showBackground
  }

  NToggle {
    Layout.fillWidth: true
    visible: valueShowBackground
    label: I18n.tr("panels.desktop-widgets.system-stat-rounded-corners-label")
    description: I18n.tr("panels.desktop-widgets.system-stat-rounded-corners-description")
    checked: valueRoundedCorners
    onToggled: checked => {
                 settingsHelper.set("roundedCorners", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.roundedCorners
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.system-stat-layout-label")
    description: I18n.tr("panels.desktop-widgets.system-stat-layout-description")
    currentKey: valueLayout
    minimumWidth: 260 * Style.uiScaleRatio
    model: [
      {
        "key": "side",
        "name": I18n.tr("panels.desktop-widgets.system-stat-layout-side")
      },
      {
        "key": "bottom",
        "name": I18n.tr("panels.desktop-widgets.system-stat-layout-bottom")
      }
    ]
    onSelected: key => {
                  settingsHelper.set("layout", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.layout
  }
}
