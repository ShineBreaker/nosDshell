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

  // Local state
  property bool valueHideWhenIdle: settingsHelper.value("hideWhenIdle")
  property string valueColorName: settingsHelper.value("colorName")

  function saveSettings() {
    var settings = settingsHelper.save();
    settings.width = parseInt(widthInput.text) || widgetMetadata.width;
    settingsChanged(settings);
    return settings;
  }

  NTextInput {
    id: widthInput
    Layout.fillWidth: true
    label: I18n.tr("common.width")
    description: I18n.tr("bar.audio-visualizer.width-description")
    text: String(settingsHelper.value("width", ""))
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    onTextChanged: saveSettings()
    defaultValue: String(widgetMetadata.width)
  }

  NColorChoice {
    Layout.fillWidth: true
    label: I18n.tr("bar.audio-visualizer.color-name-label")
    description: I18n.tr("bar.audio-visualizer.color-name-description")
    currentKey: root.valueColorName
    onSelected: key => {
                  settingsHelper.set("colorName", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.colorName
  }

  NToggle {
    label: I18n.tr("bar.audio-visualizer.hide-when-idle-label")
    description: I18n.tr("bar.audio-visualizer.hide-when-idle-description")
    checked: valueHideWhenIdle
    onToggled: checked => {
                 settingsHelper.set("hideWhenIdle", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideWhenIdle
  }
}
