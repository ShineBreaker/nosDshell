import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  // Local state
  property string valueDisplayMode: settingsHelper.value("displayMode")
  property string valueDeviceNativePath: settingsHelper.value("deviceNativePath")
  property bool valueShowPowerProfiles: settingsHelper.value("showPowerProfiles")
  property bool valueShowPerformanceMode: settingsHelper.value("showPerformanceMode")
  property bool valueHideIfNotDetected: settingsHelper.value("hideIfNotDetected")
  property bool valueHideIfIdle: settingsHelper.value("hideIfIdle")

  function saveSettings() {
    var settings = settingsHelper.save();
    if (widgetData && widgetData.id) {
      settings.id = widgetData.id;
    }
    settingsChanged(settings);
    return settings;
  }

  NComboBox {
    id: deviceComboBox
    Layout.fillWidth: true
    label: I18n.tr("bar.battery.device-label")
    description: I18n.tr("bar.battery.device-description")
    minimumWidth: 240
    model: BatteryService.deviceModel
    currentKey: root.valueDeviceNativePath
    onSelected: key => {
                  settingsHelper.set("deviceNativePath", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.deviceNativePath
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("common.display-mode")
    description: I18n.tr("bar.battery.display-mode-description")
    minimumWidth: 240
    model: [
      {
        "key": "graphic",
        "name": I18n.tr("bar.battery.display-mode-graphic")
      },
      {
        "key": "graphic-clean",
        "name": I18n.tr("bar.battery.display-mode-graphic-clean")
      },
      {
        "key": "icon-hover",
        "name": I18n.tr("bar.battery.display-mode-icon-hover")
      },
      {
        "key": "icon-always",
        "name": I18n.tr("bar.battery.display-mode-icon-always")
      },
      {
        "key": "icon-only",
        "name": I18n.tr("bar.battery.display-mode-icon-only")
      }
    ]
    currentKey: root.valueDisplayMode
    onSelected: key => {
                  settingsHelper.set("displayMode", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.displayMode
  }

  NToggle {
    label: I18n.tr("bar.battery.hide-if-not-detected-label")
    description: I18n.tr("bar.battery.hide-if-not-detected-description")
    checked: valueHideIfNotDetected
    onToggled: checked => {
                 settingsHelper.set("hideIfNotDetected", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideIfNotDetected
  }

  NToggle {
    label: I18n.tr("bar.battery.hide-if-idle-label")
    description: I18n.tr("bar.battery.hide-if-idle-description")
    checked: valueHideIfIdle
    onToggled: checked => {
                 settingsHelper.set("hideIfIdle", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideIfIdle
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: I18n.tr("bar.battery.show-power-profile-label")
    description: I18n.tr("bar.battery.show-power-profile-description")
    checked: valueShowPowerProfiles
    onToggled: checked => {
                 settingsHelper.set("showPowerProfiles", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showPowerProfiles
  }

  NToggle {
    label: I18n.tr("bar.battery.show-performance-mode-label")
    description: I18n.tr("bar.battery.show-performance-mode-description")
    checked: valueShowPerformanceMode
    onToggled: checked => {
                 settingsHelper.set("showPerformanceMode", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showPerformanceMode
  }
}
