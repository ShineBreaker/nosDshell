import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var entriesModel: []
  property var updateEntry
  property var reorderEntries
  property var openEntrySettingsDialog

  // Sortable entries are one SettingsGroup: 1 px seams, auto head/tail
  // corners come from NDccRow's sibling scan (DESIGN §3.5.4). A ListView
  // plus a y binding that also added spacing measured as a ~4 px gap.
  Item {
    id: entryList
    Layout.fillWidth: true
    // childrenRect follows the delegate y bindings, so the block stays as
    // tall as the last row. A hand-rolled sum misses height changes.
    implicitHeight: Math.max(0, childrenRect.height)

    Repeater {
      id: entryRepeater
      model: root.entriesModel

      delegate: NDccRow {
        id: delegateItem
        width: entryList.width
        spacing: Style.marginS
        active: dragging

        required property int index
        required property var modelData

        property bool dragging: false
        property real dragY: 0
        property int dragStartY: 0
        property int dragStartIndex: -1
        property int dragTargetIndex: -1

        // Drag handle
        Rectangle {
          Layout.preferredWidth: Style.baseWidgetSize * 0.7
          Layout.preferredHeight: Style.baseWidgetSize * 0.7
          Layout.alignment: Qt.AlignVCenter
          radius: Style.radiusXS
          color: dragHandleMouseArea.containsMouse ? Colors.overlay("strong") : "transparent"

          ColumnLayout {
            anchors.centerIn: parent
            spacing: Style.marginXXS

            Repeater {
              model: 3
              Rectangle {
                Layout.preferredWidth: Style.baseWidgetSize * 0.28
                Layout.preferredHeight: Style.marginXXS
                radius: Style.marginXXXS
                color: Colors.onShellTertiary
              }
            }
          }

          MouseArea {
            id: dragHandleMouseArea
            anchors.fill: parent
            cursorShape: Qt.SizeVerCursor
            hoverEnabled: true
            preventStealing: false
            z: 1000

            onPressed: mouse => {
                         delegateItem.dragStartIndex = delegateItem.index;
                         delegateItem.dragTargetIndex = delegateItem.index;
                         delegateItem.dragStartY = delegateItem.y;
                         delegateItem.dragY = delegateItem.y;
                         delegateItem.dragging = true;
                         delegateItem.z = 999;
                         preventStealing = true;
                       }

            onPositionChanged: mouse => {
                                 if (delegateItem.dragging) {
                                   var dy = mouse.y - height / 2;
                                   var stride = delegateItem.height + Style.settingsGroupGap;
                                   var newY = delegateItem.dragY + dy;
                                   var limit = Math.max(0, (entryRepeater.count - 1) * stride);
                                   newY = Math.max(0, Math.min(newY, limit));
                                   delegateItem.dragY = newY;
                                   var targetIndex = Math.floor((newY + delegateItem.height / 2) / stride);
                                   targetIndex = Math.max(0, Math.min(targetIndex, entryRepeater.count - 1));
                                   delegateItem.dragTargetIndex = targetIndex;
                                 }
                               }

            onReleased: {
              preventStealing = false;
              if (delegateItem.dragStartIndex !== -1 && delegateItem.dragTargetIndex !== -1 && delegateItem.dragStartIndex !== delegateItem.dragTargetIndex) {
                root.reorderEntries(delegateItem.dragStartIndex, delegateItem.dragTargetIndex);
              }
              delegateItem.dragging = false;
              delegateItem.dragStartIndex = -1;
              delegateItem.dragTargetIndex = -1;
              delegateItem.z = 0;
            }

            onCanceled: {
              preventStealing = false;
              delegateItem.dragging = false;
              delegateItem.dragStartIndex = -1;
              delegateItem.dragTargetIndex = -1;
              delegateItem.z = 0;
            }
          }
        }

        // Enable checkbox
        Rectangle {
          Layout.preferredWidth: Style.baseWidgetSize * 0.7
          Layout.preferredHeight: Style.baseWidgetSize * 0.7
          Layout.alignment: Qt.AlignVCenter
          radius: Style.radiusXS
          color: modelData.enabled ? Colors.accent : Colors.overlay("field")
          border.color: modelData.enabled ? Colors.accent : Colors.borderShell
          border.width: Style.borderS

          Behavior on color {
            enabled: !Colors.isTransitioning
            NColorAnim {
              duration: Style.motionSwitch
              curve: "swift"
            }
          }

          NIcon {
            visible: modelData.enabled
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -1
            icon: "check"
            color: Colors.onAccent
            pointSize: Math.max(Style.fontSizeXS, Style.baseWidgetSize * 0.35)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.updateEntry(index, {
                                 "enabled": !modelData.enabled
                               });
            }
          }
        }

        // Label
        NText {
          Layout.fillWidth: true
          // Names are stored once at load. Resolve from the action id so a
          // live language switch does not leave the previous language.
          text: {
            switch (modelData.id) {
            case "lock":
              return I18n.tr("common.lock");
            case "suspend":
              return I18n.tr("common.suspend");
            case "hibernate":
              return I18n.tr("common.hibernate");
            case "reboot":
              return I18n.tr("common.reboot");
            case "userspaceReboot":
              return I18n.tr("common.userspace-reboot");
            case "rebootToUefi":
              return I18n.tr("common.reboot-to-uefi");
            case "logout":
              return I18n.tr("common.logout");
            case "shutdown":
              return I18n.tr("common.shutdown");
            default:
              return modelData.text || "";
            }
          }
          color: Colors.onShell
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        // Countdown toggle (only shown when global countdown is enabled)
        NIconButtonHot {
          visible: Settings.data.sessionMenu.enableCountdown
          icon: "clock"
          hot: modelData.countdownEnabled !== undefined ? modelData.countdownEnabled : true
          baseSize: Style.baseWidgetSize * 0.8
          Layout.alignment: Qt.AlignVCenter
          tooltipText: I18n.tr("common.countdown")
          onClicked: root.updateEntry(delegateItem.index, {
                                        "countdownEnabled": !(modelData.countdownEnabled !== undefined ? modelData.countdownEnabled : true)
                                      })
        }

        // Settings button (cogwheel)
        NIconButton {
          icon: "settings"
          tooltipText: I18n.tr("panels.session-menu.entry-settings-tooltip")
          baseSize: Style.baseWidgetSize * 0.8
          Layout.alignment: Qt.AlignVCenter
          onClicked: root.openEntrySettingsDialog(delegateItem.index)
        }

        // Position binding for non-dragging state. dragY is a separate
        // property so this binding never reads y (that loop disables it
        // and the row never snaps back into the 1 px seam).
        y: {
          if (delegateItem.dragging)
            return delegateItem.dragY;

          var draggedIndex = -1;
          var targetIndex = -1;
          for (var i = 0; i < entryRepeater.count; i++) {
            var item = entryRepeater.itemAt(i);
            if (item && item.dragging) {
              draggedIndex = item.dragStartIndex;
              targetIndex = item.dragTargetIndex;
              break;
            }
          }

          if (draggedIndex !== -1 && targetIndex !== -1 && draggedIndex !== targetIndex) {
            var currentIndex = delegateItem.index;
            var stride = delegateItem.height + Style.settingsGroupGap;
            if (draggedIndex < targetIndex) {
              if (currentIndex > draggedIndex && currentIndex <= targetIndex) {
                return (currentIndex - 1) * stride;
              }
            } else {
              if (currentIndex >= targetIndex && currentIndex < draggedIndex) {
                return (currentIndex + 1) * stride;
              }
            }
          }

          return delegateItem.index * (delegateItem.height + Style.settingsGroupGap);
        }

        Behavior on y {
          enabled: !delegateItem.dragging
          NAnim {
            duration: Style.motionExpand
            curve: "expand"
          }
        }
      }
    }
  }
}
