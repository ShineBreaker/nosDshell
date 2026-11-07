import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  property bool valueShowBackground: settingsHelper.value("showBackground")
  property bool valueRoundedCorners: settingsHelper.value("roundedCorners")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.clock-show-background-label")
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
    label: I18n.tr("panels.desktop-widgets.clock-rounded-corners-label")
    checked: valueRoundedCorners
    onToggled: checked => {
      settingsHelper.set("roundedCorners", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.roundedCorners
  }
}
