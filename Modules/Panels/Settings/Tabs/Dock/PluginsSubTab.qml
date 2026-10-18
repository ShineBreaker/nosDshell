import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../../Bar" as BarSettings

// DDE taskbar "Plugins" page. Both modes share the sectioned layout editor
// (MonitorWidgetsConfig editMode "taskbar"): left/center zones write
// dock.taskbarWidgets and the right zone writes dock.plugins. The fashion
// dock flattens the same three lists into a single strip (left ++ center ++
// plugins — DockContent.contentList), so every item, Launcher and the app
// strip included, is addable, reorderable and gets the per-instance settings
// gear, and the arrangement carries across modes.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  enabled: Settings.data.dock.enabled

  BarSettings.MonitorWidgetsConfig {
    editMode: "taskbar"
    Layout.fillWidth: true
  }
}
