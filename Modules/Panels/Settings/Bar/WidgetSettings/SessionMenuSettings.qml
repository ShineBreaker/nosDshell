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
  property string valueIconColor: settingsHelper.value("iconColor")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NColorChoice {
    label: I18n.tr("common.select-icon-color")
    currentKey: root.valueIconColor
    onSelected: key => {
                  settingsHelper.set("iconColor", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.iconColor
  }
}
