import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  WidgetNumberInput {
    id: widthInput
    Layout.fillWidth: true
    label: I18n.tr("common.width")
    description: I18n.tr("bar.spacer.width-description")
    text: String(settingsHelper.value("width", ""))
    storedValue: settingsHelper.value("width", widgetMetadata.width)
    minimum: 1
    maximum: 2000
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    onCommitted: value => {
                   settingsHelper.set("width", value);
                   saveSettings();
                 }
    defaultValue: String(widgetMetadata.width)
  }
}
