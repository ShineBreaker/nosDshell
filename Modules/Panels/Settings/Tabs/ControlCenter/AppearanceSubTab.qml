import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true
  Layout.fillHeight: true

  ColumnLayout {
    spacing: Style.settingsGroupGap
    Layout.fillWidth: true

    NComboBox {
      id: diskPathComboBox
      Layout.fillWidth: true
      label: I18n.tr("panels.control-center.system-monitor-disk-path-label")
      description: I18n.tr("panels.control-center.system-monitor-disk-path-description")
      model: {
        const paths = Object.keys(SystemStatService.diskPercents).sort();
        return paths.map(path => ({
                                    key: path,
                                    name: path
                                  }));
      }
      currentKey: Settings.data.controlCenter.diskPath || "/"
      onSelected: key => Settings.data.controlCenter.diskPath = key
      defaultValue: Settings.getDefaultValue("controlCenter.diskPath") || "/"
    }
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
