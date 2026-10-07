import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Modules.OSD
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  property var addType
  property var removeType

  // Nothing renders while the master switch is off, so the event list dims
  // with it — same gating as GeneralSubTab.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    enabled: Settings.data.osd.enabled

    Repeater {
      model: [
        {
          type: OSD.Type.Volume,
          key: "types-volume"
        },
        {
          type: OSD.Type.InputVolume,
          key: "types-input-volume"
        },
        {
          type: OSD.Type.Brightness,
          key: "types-brightness"
        },
        {
          type: OSD.Type.LockKey,
          key: "types-lockkey"
        }
      ]
      delegate: NCheckbox {
        required property var modelData
        Layout.fillWidth: true
        label: I18n.tr("panels.osd." + modelData.key + "-label")
        description: I18n.tr("panels.osd." + modelData.key + "-description")
        checked: (Settings.data.osd.enabledTypes || []).includes(modelData.type)
        onToggled: checked => {
                     if (checked) {
                       Settings.data.osd.enabledTypes = root.addType(Settings.data.osd.enabledTypes, modelData.type);
                     } else {
                       Settings.data.osd.enabledTypes = root.removeType(Settings.data.osd.enabledTypes, modelData.type);
                     }
                   }
      }
    }
  }
}
