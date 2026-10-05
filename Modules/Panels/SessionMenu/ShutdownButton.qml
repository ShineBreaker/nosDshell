import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// RoundItemButton (gxde-session-ui/widgets/rounditembutton.cpp) — the dde-shutdown
// power button. 140x140, 75x75 glyph, 10 px gap, white wrapping label;
// hover/selected = pressDim rounded rect radiusLarge; disabled = opacity 0.5.
//
// The glyph is the original 75x75 DDE artwork and switches between the
// normal / hover / press SVGs: rounditembutton.cpp:173-181 repaints m_itemIcon
// from a QSvgRenderer in its event filter, it does not tint or fade the icon.
// Paint events are :194-201 (dim block only in the Checked state) and the
// press transition is :150-158.
//
// Shared by the dde-shutdown panel and the in-lock-screen power row, so the two
// cannot drift apart.
Rectangle {
  id: button

  property string icon: ""
  // Absolute path prefix of the DDE artwork, e.g. ".../dde-shutdown/img/poweroff"
  property string artworkPath: ""
  property string title: ""
  property bool isShutdown: false
  property bool isSelected: false
  property bool effectiveHover: false
  property bool pressed: false
  property bool available: true
  property bool pending: false
  property string keybind: ""

  signal clicked

  readonly property bool dimmed: isSelected || effectiveHover || pressed

  // rounditembutton.cpp:194-201 — one SVG per state, no overlay
  readonly property string artworkState: pressed ? "press" : (dimmed ? "hover" : "normal")

  radius: Style.radiusLarge
  color: dimmed ? Color.pressDim : "transparent"
  // rounditembutton.cpp:65-74 — setDisabled() drops the whole widget to 0.5
  opacity: button.available ? 1.0 : 0.5

  Behavior on color {
    enabled: !Settings.data.general.animationDisabled
    ColorAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    enabled: !Settings.data.general.animationDisabled
    NumberAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    // rounditembutton.cpp:104-111 — 10 px of leading space, then the icon,
    // then the wrapping label below it
    spacing: Style.shutdownButtonIconTextGap

    Image {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Style.shutdownButtonIcon
      Layout.preferredHeight: Style.shutdownButtonIcon
      source: button.artworkPath !== "" ? button.artworkPath + "_" + button.artworkState + ".svg" : ""
      sourceSize.width: Style.shutdownButtonIcon
      sourceSize.height: Style.shutdownButtonIcon
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
      cache: true
      // Fall back to the Tabler glyph only if the artwork is missing
      visible: source !== ""
    }

    NIcon {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Style.shutdownButtonIcon
      Layout.preferredHeight: Style.shutdownButtonIcon
      visible: button.artworkPath === ""
      icon: button.icon
      color: "white"
      pointSize: Style.fontSizeXXXL
    }

    NText {
      Layout.alignment: Qt.AlignHCenter
      Layout.maximumWidth: Style.shutdownButtonSize - Style.marginM
      text: button.title
      pointSize: Style.fontSizeM
      color: "white"
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    // Keybind shown after the label, onShellTertiary (white @0.6)
    NText {
      Layout.alignment: Qt.AlignHCenter
      text: button.keybind
      pointSize: Style.fontSizeS
      color: Color.onShellTertiary
      visible: text.length > 0
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    enabled: button.available
    cursorShape: Qt.PointingHandCursor
    onPressed: button.pressed = true
    onReleased: button.pressed = false
    onEntered: button.pressed = false
    onExited: button.pressed = false
    onClicked: button.clicked()
  }
}
