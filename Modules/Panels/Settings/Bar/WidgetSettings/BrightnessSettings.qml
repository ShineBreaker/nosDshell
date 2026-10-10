import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
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
  property string valueIconColor: settingsHelper.value("iconColor")
  property string valueTextColor: settingsHelper.value("textColor")
  property bool valueApplyToAllMonitors: settingsHelper.value("applyToAllMonitors")

  readonly property bool hasMultipleMonitors: (Quickshell.screens || []).length > 1

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NDisplayModeComboBox {
    currentKey: valueDisplayMode
    onSelected: key => {
                  settingsHelper.set("displayMode", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.displayMode
  }

  NColorChoice {
    label: I18n.tr("common.select-icon-color")
    currentKey: valueIconColor
    onSelected: key => {
                  settingsHelper.set("iconColor", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.iconColor
  }

  NColorChoice {
    label: I18n.tr("common.select-text-color")
    currentKey: valueTextColor
    onSelected: key => {
                  settingsHelper.set("textColor", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.textColor
  }

  NToggle {
    visible: hasMultipleMonitors
    Layout.fillWidth: true
    label: I18n.tr("bar.brightness.apply-all-label")
    description: I18n.tr("bar.brightness.apply-all-description")
    checked: valueApplyToAllMonitors
    onToggled: checked => {
                 settingsHelper.set("applyToAllMonitors", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.applyToAllMonitors
  }
}
