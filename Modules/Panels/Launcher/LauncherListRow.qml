import QtQuick
import Quickshell.Widgets

import qs.Commons
import qs.Widgets
import QtQuick.Layouts

// Non-app result row shared by the fullscreen list and the mini list
// (DESIGN §3.4.1 / §3.4.2): 36 px tall, icon 24 at x=10, text at x=48,
// hover/selection = overlay("hover") rounded rect radiusRow inset 1.
Item {
  id: root

  required property int index
  // Owning view's result array, injected by the delegate site. The list view's
  // model carries only a count (CODING_STANDARDS "QML 规则"): boxing the
  // entries through a QVariant model would turn each result's provider
  // QObject into a raw pointer that loses QPointer tracking. The row resolves
  // the live JS entry itself; a transient miss reads null.
  property var results: []

  readonly property var modelData: results[index] ?? null

  property var listView: null
  // Driven by appLauncher.density via the owning view's LauncherModel.
  property int rowHeight: 36
  property int iconSize: 24

  signal activated
  signal rightClicked(var mouse)

  width: listView ? listView.width : 400
  height: rowHeight

  readonly property int iconY: Math.round((rowHeight - iconSize) / 2)
  readonly property bool ignoreMouse: Settings.data.appLauncher.ignoreMouseInput

  readonly property bool selected: listView ? listView.currentIndex === index : false

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 1
    anchors.bottomMargin: 1
    radius: Style.radiusRow
    color: (mouseArea.containsMouse || root.selected) ? Colors.overlayWallpaper("hover") : "transparent"
  }

  // Optional backing plate behind the icon (appLauncher.showIconBackground)
  Rectangle {
    x: 10 - Style.marginS
    y: root.iconY - Style.marginS
    width: root.iconSize + Style.marginS * 2
    height: root.iconSize + Style.marginS * 2
    radius: Style.radiusRow
    color: Colors.overlayWallpaper("hover")
    visible: Settings.data.appLauncher.showIconBackground && !modelData?.isImage
  }

  // Icon — darkened wallpaper surface: symbolic glyphs stay in onWallpaper ink
  NSymbolicImage {
    id: rowIcon
    x: 10
    width: root.iconSize
    height: root.iconSize
    y: root.iconY
    source: modelData?.icon ? ThemeIcons.iconFromName(modelData.icon) : ""
    detectSymbolic: true
    color: Colors.onWallpaper
    visible: status === Image.Ready
    asynchronous: true
  }

  NIcon {
    x: 10
    y: root.iconY
    width: root.iconSize
    height: root.iconSize
    // The glyph fills the same box the image icon does, so an action row with a
    // Tabler glyph and an app row with a themed icon share one left edge and one
    // optical size (DESIGN §3.4.2: 图标 24 px 放在 x=10).
    pointSize: root.iconSize
    // Fallback when there is no themed icon, or it failed to load: only feed
    // real Tabler glyph names to the font path, app icon names would warn and
    // render the fallback.
    icon: (Icons.icons[modelData?.icon] !== undefined || Icons.aliases[modelData?.icon] !== undefined) ? modelData.icon : "apps"
    color: Colors.onWallpaper
    visible: modelData?.icon === "" || rowIcon.status === Image.Error
  }

  NText {
    x: 10 + root.iconSize + 14
    width: parent.width - (x + 10)
    height: root.rowHeight
    verticalAlignment: Text.AlignVCenter
    text: modelData?.name || ""
    pointSize: Style.fontSizeBody
    color: Colors.onWallpaper
    elide: Text.ElideRight
    maximumLineCount: 1
    applyUiScale: false
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: !root.ignoreMouse
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   root.rightClicked(mouse);
                 } else {
                   root.activated();
                 }
               }
  }
}
