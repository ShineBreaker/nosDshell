import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
  id: root

  property string label: ""
  property string description: ""
  property bool expanded: false
  property real contentSpacing: Style.marginM
  property bool _userInteracted: false

  signal toggled(bool expanded)

  Layout.fillWidth: true
  spacing: 0

  // Default property to accept children
  default property alias content: contentLayout.children

  // Header with clickable area
  Rectangle {
    id: headerContainer
    Layout.fillWidth: true
    Layout.preferredHeight: headerContent.implicitHeight + Style.margin2M
    color: headerArea.containsMouse ? Color.overlay("hover") : "transparent"
    radius: Style.radiusRow
    border.color: "transparent"
    border.width: Style.borderS

    // Smooth color transitions
    Behavior on border.color {
      enabled: root._userInteracted
      ColorAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    MouseArea {
      id: headerArea
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: {
        root._userInteracted = true;
        root.expanded = !root.expanded;
        root.toggled(root.expanded);
      }
    }

    RowLayout {
      id: headerContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      // Expand/collapse icon with rotation animation
      NIcon {
        id: chevronIcon
        icon: "chevron-right"
        pointSize: Style.fontSizeL
        color: Color.onShellSecondary
        Layout.alignment: Qt.AlignVCenter

        rotation: root.expanded ? 90 : 0
        Behavior on rotation {
          enabled: root._userInteracted
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }

        Behavior on color {
          enabled: root._userInteracted
          ColorAnimation {
            duration: Style.animationNormal
          }
        }
      }

      // Header text content - properly contained
      RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginL

        NText {
          text: root.label
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.onShell
          wrapMode: Text.WordWrap
        }

        NText {
          text: root.description
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightRegular
          color: Color.onShellTertiary
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          visible: root.description !== ""
        }
      }
    }
  }

  // Collapsible content with Material 3 styling
  Rectangle {
    id: contentContainer
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS

    visible: root.expanded
    color: Color.overlay("strong")
    radius: Style.radiusItem
    border.color: Style.boxBorderColor
    border.width: Style.borderS

    // Dynamic height based on content
    Layout.preferredHeight: expanded ? contentLayout.implicitHeight + Style.margin2L : 0

    // Smooth height animation
    Behavior on Layout.preferredHeight {
      enabled: root._userInteracted
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    // Content layout
    ColumnLayout {
      id: contentLayout
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: root.contentSpacing
    }

    // Fade in animation for content
    opacity: root.expanded ? 1.0 : 0.0
    Behavior on opacity {
      enabled: root._userInteracted
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
  }
}
