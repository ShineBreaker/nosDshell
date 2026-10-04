import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NSettingsItem - a DDE SettingsItem row (DESIGN §3.5.4).
*
* 36 px tall, bg `overlay("strong")`, hover `overlay("checked")`, error state a
* 2 px Color.alert border. Interactive rows (clickable / switchable) get the
* hover fill; plain rows only paint the background. Padding is (20, 10).
*
* Pass content in `content`; rows are meant to be dropped into an
* NSettingsGroup, which handles the 1 px gaps and the outer corner radii.
*/
Rectangle {
  id: root

  property string title: ""
  property string description: ""
  property string icon: ""
  property var value: "" // secondary text (white x 0.8) on the right
  property bool error: false
  property bool interactive: true

  signal clicked

  implicitHeight: Style.settingsRowHeight
  radius: style_radius
  color: style_color

  readonly property color style_color: {
    if (root.error)
      return Color.overlay("strong");
    if (rowArea.containsMouse && root.interactive)
      return Color.overlay("checked");
    return Color.overlay("strong");
  }

  // The group's first/last rows carry the rounded outer corners.
  property bool isFirst: false
  property bool isLast: false
  readonly property real style_radius: (isFirst || isLast) ? Style.radiusItem : Style.radiusRow

  border.color: root.error ? Color.alert : "transparent"
  border.width: root.error ? Style.borderM : 0

  Behavior on color {
    enabled: !Color.isTransitioning
    ColorAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.settingsRowPaddingH
    anchors.rightMargin: Style.settingsRowPaddingH
    spacing: Style.marginM

    NIcon {
      visible: root.icon !== ""
      Layout.alignment: Qt.AlignVCenter
      icon: root.icon
      pointSize: Style.fontSizeL
      color: Color.onShellSecondary
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      NText {
        Layout.fillWidth: true
        text: root.title
        pointSize: Style.fontSizeTitle
        color: root.error ? Color.alert : Color.onShell
        elide: Text.ElideRight
      }

      NText {
        Layout.fillWidth: true
        visible: root.description !== ""
        text: root.description
        pointSize: Style.fontSizeS
        color: Color.onShellSecondary
        elide: Text.ElideRight
      }
    }

    NText {
      Layout.alignment: Qt.AlignVCenter
      visible: root.value !== undefined && root.value !== ""
      text: String(root.value)
      pointSize: Style.fontSizeBody
      color: Color.onShellSecondary
      horizontalAlignment: Text.AlignRight
    }
  }

  MouseArea {
    id: rowArea
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.interactive
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.clicked()
  }
}
