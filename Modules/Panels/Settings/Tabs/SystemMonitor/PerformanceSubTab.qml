import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.performance-mode-disable-wallpaper-label")
    description: I18n.tr("panels.system.performance-mode-disable-wallpaper-description")
    checked: !Settings.data.performance.disableWallpaper
    defaultValue: !Settings.getDefaultValue("performance.disableWallpaper")
    onToggled: checked => Settings.data.performance.disableWallpaper = !checked
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.performance-mode-disable-desktop-widgets-label")
    description: I18n.tr("panels.system.performance-mode-disable-desktop-widgets-description")
    checked: !Settings.data.performance.disableDesktopWidgets
    defaultValue: !Settings.getDefaultValue("performance.disableDesktopWidgets")
    onToggled: checked => Settings.data.performance.disableDesktopWidgets = !checked
  }
}
