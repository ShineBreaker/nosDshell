import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
import QtQuick.Layouts

// Shared launcher search field (DESIGN §3.4.1 / §3.4.2): 290 px wide,
// overlay("strong") surface, radiusItem, glyph left with 25 px left padding,
// 20 px right padding, white text.
Item {
  id: root

  property alias text: input.text
  property alias textInput: input
  property string placeholderText: I18n.tr("launcher.dde.search-placeholder")
  // True on the fullscreen launcher's blurred wallpaper (always dark); false
  // on the mini window's theme-aware panel surface.
  property bool wallpaperSurface: false
  signal textEdited(string text)
  signal accepted

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusItem
    color: root.wallpaperSurface ? Color.overlayWallpaper("strong") : Color.overlay("strong")
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 25
    anchors.rightMargin: 20
    spacing: Style.marginS

    NIcon {
      icon: "search"
      pointSize: Style.fontSizeM
      color: root.wallpaperSurface ? Color.onWallpaperTertiary : Color.onShellTertiary
      Layout.alignment: Qt.AlignVCenter
    }

    TextInput {
      id: input

      Layout.fillWidth: true
      Layout.fillHeight: true
      color: root.wallpaperSurface ? Color.onWallpaper : Color.onShell
      selectionColor: Color.accent
      selectedTextColor: root.wallpaperSurface ? Color.onWallpaper : Color.onShell
      font.family: Settings.data.ui.fontDefault
      font.pointSize: 12 * Style.uiScaleRatio
      verticalAlignment: TextInput.AlignVCenter
      renderType: Text.NativeRendering
      clip: true
      selectByMouse: true
      activeFocusOnTab: false

      onTextEdited: root.textEdited(text)
      onAccepted: root.accepted()

      Text {
        anchors.fill: parent
        anchors.leftMargin: 2
        verticalAlignment: input.verticalAlignment
        text: root.placeholderText
        color: root.wallpaperSurface ? Color.onWallpaperTertiary : Color.onShellTertiary
        font: input.font
        visible: input.text === ""
      }

      cursorDelegate: Rectangle {
        visible: input.activeFocus
        width: 1
        color: root.wallpaperSurface ? Color.onWallpaper : Color.onShell
      }
    }
  }
}
