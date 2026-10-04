import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.ControlCenter
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterNotificationPage - notification history page (DESIGN §3.5.2).
*
* DND switch row on top, then the reusable history list. `closeOnAction` is
* invoked after a notification action succeeds so the control center closes
* like the original panel did.
*/
Item {
  id: root

  property var screen: null
  property var closeOnAction: null

  implicitHeight: content.implicitHeight

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Style.marginS

    // DND switch row (DSwitchButton: 40x22 capsule, DESIGN §3.5.4)
    Item {
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.preferredHeight: Style.detailRowHeight

      RowLayout {
        anchors.fill: parent
        spacing: Style.marginS

        NIcon {
          icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
          pointSize: Style.fontSizeXL
          color: NotificationService.doNotDisturb ? Color.accent : Color.onShellSecondary
        }

        NText {
          Layout.fillWidth: true
          text: NotificationService.doNotDisturb ? I18n.tr("actions.disable-dnd") : I18n.tr("actions.enable-dnd")
          pointSize: Style.fontSizeM
          elide: Text.ElideRight
        }

        NToggle {
          label: ""
          checked: NotificationService.doNotDisturb
          onToggled: checked => NotificationService.doNotDisturb = checked
        }
      }
    }

    NotificationHistoryList {
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginS
      screen: root.screen
      closeOnAction: root.closeOnAction
    }
  }
}
