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
  property string valueDisplayMode: settingsHelper.value("displayMode")
  property string valueMiddleClickCommand: settingsHelper.value("middleClickCommand")
  property string valueIconColor: settingsHelper.value("iconColor")
  property string valueTextColor: settingsHelper.value("textColor")

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

  // Middle click command
  NTextInput {
    label: I18n.tr("bar.custom-button.middle-click-label")
    description: I18n.tr("panels.audio.on-middle-clicked-description")
    placeholderText: I18n.tr("panels.audio.external-mixer-placeholder")
    text: valueMiddleClickCommand
    onTextChanged: {
      settingsHelper.set("middleClickCommand", text);
      saveSettings();
    }
    defaultValue: widgetMetadata.middleClickCommand
  }
}
