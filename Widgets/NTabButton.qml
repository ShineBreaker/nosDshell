import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  // Public properties
  property string text: ""
  property string icon: ""
  property var tooltipText
  property bool checked: false
  property int tabIndex: 0
  property real pointSize: Style.fontSizeM
  property bool isFirst: false
  property bool isLast: false

  // SettingsGroup header mode (DDE §3.5.4): no pill background, no side
  // radii — a DemiBold label sitting above its group.
  property bool isTabButton: true
  property bool plain: false

  // Internal state
  property bool isHovered: false

  signal clicked

  // Sizing
  Layout.fillHeight: true
  implicitWidth: contentLayout.implicitWidth + Style.margin2M
  implicitHeight: plain ? Style.settingsHeadHeight : Style.baseWidgetSize

  topLeftRadius: plain ? 0 : (isFirst ? Style.radiusItem : Style.radiusXXXS)
  bottomLeftRadius: plain ? 0 : (isFirst ? Style.radiusItem : Style.radiusXXXS)
  topRightRadius: plain ? 0 : (isLast ? Style.radiusItem : Style.radiusXXXS)
  bottomRightRadius: plain ? 0 : (isLast ? Style.radiusItem : Style.radiusXXXS)

  color: plain ? "transparent" : (root.isHovered ? Color.overlay("hover") : (root.checked ? Color.overlay("checked") : "transparent"))
  border.color: "transparent"
  border.width: Style.borderS

  Behavior on color {
    enabled: !Color.isTransitioning
    ColorAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  // Content
  RowLayout {
    id: contentLayout
    anchors.centerIn: parent
    width: Math.min(implicitWidth, parent.width - Style.margin2S)
    spacing: (root.icon !== "" && root.text !== "") ? Style.marginXS : 0

    NIcon {
      visible: root.icon !== ""
      Layout.alignment: Qt.AlignVCenter
      icon: root.icon
      pointSize: root.pointSize * 1.2
      color: Color.onShell

      Behavior on color {
        enabled: !Color.isTransitioning
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }

    NText {
      id: tabText
      visible: root.text !== ""
      Layout.alignment: Qt.AlignVCenter
      text: root.text
      pointSize: root.plain ? Style.fontSizeTitle : root.pointSize
      font.weight: root.plain ? Style.fontWeightMedium : (root.checked ? Style.fontWeightMedium : Style.fontWeightRegular)
      color: Color.onShell
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        enabled: !Color.isTransitioning
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  // Tooltip
  Timer {
    id: tooltipTimer
    interval: Style.tooltipDelayDock
    onTriggered: {
      if (root.isHovered && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        TooltipService.show(root, root.tooltipText);
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      root.isHovered = true;
      if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        tooltipTimer.start();
      }
    }
    onExited: {
      root.isHovered = false;
      tooltipTimer.stop();
      if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        TooltipService.hide();
      }
    }
    onClicked: {
      root.clicked();
      // Update parent NTabBar's currentIndex
      if (root.parent && root.parent.parent && root.parent.parent.currentIndex !== undefined) {
        root.parent.parent.currentIndex = root.tabIndex;
      }
    }
  }
}
