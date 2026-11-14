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
* ControlCenterNotificationPage - the control center home page (DESIGN §3.5.2).
*
* DND switch row on top, then the reusable history list. The content cards
* are the first page of the quick-control pager below, not pinned here.
* `closeOnAction` is invoked after a notification action succeeds so the
* control center closes like the original panel did.
*
* The list header ("通知" + "全部清除") lives inside the list component: it is
* the first row of the top-anchored content (DESIGN §3.5.2), so it must
* travel with the notifications and hide with an empty history.
*/
Item {
  id: root
  property var screen: null
  property var closeOnAction: null

  implicitHeight: content.implicitHeight

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: Style.marginS

    // DND switch row (DSwitchButton: 40x22 capsule, DESIGN §3.5.4). The title
    // is the feature name and never switches verbs (§1.10); the state is
    // carried by the bell-off icon + accent ink (DESIGN §3.5.2).
    Item {
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.preferredHeight: Style.detailRowHeight

      RowLayout {
        anchors.fill: parent
        spacing: Style.marginS

        NIcon {
          icon: Settings.data.notifications.doNotDisturb ? "bell-off" : "bell"
          pointSize: Style.fontSizeXL
          color: Settings.data.notifications.doNotDisturb ? Colors.accent : Colors.onShellSecondary
        }

        NText {
          Layout.fillWidth: true
          text: I18n.tr("actions.do-not-disturb")
          pointSize: Style.fontSizeM
          elide: Text.ElideRight
        }

        NToggle {
          label: ""
          checked: Settings.data.notifications.doNotDisturb
          onToggled: checked => Settings.data.notifications.doNotDisturb = checked
        }
      }
    }

    NotificationHistoryList {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginS
      screen: root.screen
      closeOnAction: root.closeOnAction
    }
  }
}
