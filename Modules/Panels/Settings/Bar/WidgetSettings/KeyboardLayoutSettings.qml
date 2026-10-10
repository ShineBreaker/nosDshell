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
  property bool valueShowIcon: settingsHelper.value("showIcon")
  property string valueIconColor: settingsHelper.value("iconColor")
  property string valueTextColor: settingsHelper.value("textColor")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NDisplayModeComboBox {
    visible: valueShowIcon // Hide display mode setting when icon is disabled
    useForceOpen: true
    currentKey: valueDisplayMode
    onSelected: key => {
                  settingsHelper.set("displayMode", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.displayMode
  }

  NToggle {
    label: I18n.tr("bar.custom-button.show-icon-label")
    description: I18n.tr("bar.keyboard-layout.show-icon-description")
    checked: valueShowIcon
    onToggled: checked => {
                 settingsHelper.set("showIcon", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showIcon
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
}
