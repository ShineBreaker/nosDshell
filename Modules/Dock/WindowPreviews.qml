import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

/**
* WindowPreviews - DDE AppSnapshot/PreviewContainer (gxde-dock
* frame/item/components): hovering a taskbar app item shows an arrow popup
* with one 200x130 tile per window. Tiles show a live toplevel capture
* (ScreencopyView) scaled keep-aspect into the tile minus 8 px margins;
* when capture is unavailable the tile falls back to the window title
* (DDE non-composite fallback). Click activates, the 24x24 close button
* closes, attention (urgent) windows get a 5 px radius frame in
* Color.attention @0.8.
*/
PopupWindow {
  id: root

  property Item anchorItem: null
  // [{toplevel, title, urgent}] — one entry per window
  property var entries: []
  property string dockPosition: "bottom"

  // function returning fresh entries (keeps tiles live while open)
  property var _provider: null

  readonly property bool horizontal: dockPosition === "top" || dockPosition === "bottom"
  readonly property string arrowEdge: dockPosition
  readonly property int pad: Style.marginM
  readonly property int spacing: Style.marginS
  readonly property int tileW: Math.round(200 * Style.uiScaleRatio)
  readonly property int tileH: Math.round(130 * Style.uiScaleRatio)

  // Arrow tip coordinate along the arrow edge (popup coordinates)
  readonly property real _arrowPos: {
    if (!anchorItem)
      return -1;
    if (arrowEdge === "top" || arrowEdge === "bottom")
      return anchorItem.width / 2 - anchor.rect.x;
    if (arrowEdge === "left" || arrowEdge === "right")
      return anchorItem.height / 2 - anchor.rect.y;
    return -1;
  }

  implicitWidth: entries.length > 0 ? (horizontal ? pad * 2 + entries.length * tileW + (entries.length - 1) * spacing : pad * 2 + tileW) + ((arrowEdge === "left" || arrowEdge === "right") ? Style.popupArrowHeight : 0) : 1
  implicitHeight: entries.length > 0 ? (horizontal ? pad * 2 + tileH : pad * 2 + entries.length * tileH + (entries.length - 1) * spacing) + ((arrowEdge === "top" || arrowEdge === "bottom") ? Style.popupArrowHeight : 0) : 1
  color: "transparent"
  visible: false

  anchor.item: anchorItem
  // Popup hangs Style.popupGap off the anchor item on the dock side,
  // centered on the item along the taskbar axis
  anchor.rect.x: {
    if (!anchorItem)
      return 0;
    switch (dockPosition) {
    case "left":
      return anchorItem.width + Style.popupGap;
    case "right":
      return -implicitWidth - Style.popupGap;
    default:
      return (anchorItem.width - implicitWidth) / 2;
    }
  }
  anchor.rect.y: {
    if (!anchorItem)
      return 0;
    switch (dockPosition) {
    case "top":
      return anchorItem.height + Style.popupGap;
    case "bottom":
      return -implicitHeight - Style.popupGap;
    default:
      return (anchorItem.height - implicitHeight) / 2;
    }
  }

  function show(item, provider, screenObj) {
    if (!item || !provider)
      return;
    anchorItem = item;
    _provider = provider;
    // NOTE: do not assign `screen` here. With anchor.item set the popup
    // screen is controlled by the parent window; assigning it only logs
    // "Cannot set screen of popup window" and changes nothing.
    refresh();
    if (entries.length === 0)
      return;
    hideTimer.stop();
    visible = true;
  }

  // Entries are [{toplevel, title, urgent}]; skip the assignment when the
  // list is equivalent so the Repeater does not destroy (and recreate) the
  // tiles under the cursor. Destroying the hovered delegate while Qt is
  // delivering hover events segfaults inside QQuickItem::isVisible().
  function entriesEqual(a, b) {
    if (a.length !== b.length)
      return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toplevel !== b[i].toplevel || a[i].title !== b[i].title || !!a[i].urgent !== !!b[i].urgent)
        return false;
    }
    return true;
  }

  function refresh() {
    var e = _provider ? _provider() : [];
    if (entriesEqual(entries, e))
      return;
    entries = e;
    if (visible && e.length === 0)
      hide();
  }

  // Grace delay after the cursor leaves both the item and the popup
  function scheduleHide() {
    hideTimer.restart();
  }

  function hide() {
    // Hide first; keep entries (and their delegates) alive so nothing is
    // destroyed from under the cursor mid-hover (see refresh()). The next
    // show() refreshes before becoming visible, so stale tiles never flash.
    visible = false;
    anchorItem = null;
    _provider = null;
  }

  Timer {
    id: hideTimer
    interval: 300
    onTriggered: {
      if (hoverHandler.hovered)
        restart();
      else
        root.hide();
    }
  }

  // Keep tile list live while the preview is open
  Connections {
    target: ToplevelManager ? ToplevelManager.toplevels : null
    function onValuesChanged() {
      if (root.visible)
        root.refresh();
    }
  }

  HoverHandler {
    id: hoverHandler
    onHoveredChanged: {
      if (hovered)
        hideTimer.stop();
      else
        hideTimer.restart();
    }
  }

  NArrowRect {
    anchors.fill: parent
    arrowEdge: root.arrowEdge
    arrowPosition: root._arrowPos
    radius: Style.radiusPopup
    fillColor: Color.popupShell
    borderColor: Color.borderShell
    borderWidth: 1
    shadow: Style.shadowPopup
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: root.pad + (root.arrowEdge === "left" ? Style.popupArrowHeight : 0)
    anchors.rightMargin: root.pad + (root.arrowEdge === "right" ? Style.popupArrowHeight : 0)
    anchors.topMargin: root.pad + (root.arrowEdge === "top" ? Style.popupArrowHeight : 0)
    anchors.bottomMargin: root.pad + (root.arrowEdge === "bottom" ? Style.popupArrowHeight : 0)

    GridLayout {
      anchors.fill: parent
      columns: root.horizontal ? root.entries.length : 1
      rows: root.horizontal ? 1 : root.entries.length
      columnSpacing: root.spacing
      rowSpacing: root.spacing

      Repeater {
        model: root.entries

        delegate: Item {
          id: tile
          required property var modelData
          readonly property bool urgent: modelData && modelData.urgent === true

          Layout.preferredWidth: root.tileW
          Layout.preferredHeight: root.tileH

          // Hover background
          Rectangle {
            anchors.fill: parent
            radius: Style.radiusItem
            color: tileHover.hovered ? Color.overlay("strong") : "transparent"
          }

          // Capture area: tile minus 8 px margins, keep-aspect
          Item {
            anchors.fill: parent
            anchors.margins: 8

            ScreencopyView {
              id: capture
              anchors.centerIn: parent
              captureSource: tile.modelData ? tile.modelData.toplevel : null
              paintCursor: false
              visible: hasContent
              readonly property real _k: (sourceSize.width > 0 && sourceSize.height > 0) ? Math.min(parent.width / sourceSize.width, parent.height / sourceSize.height) : 1
              width: sourceSize.width * _k
              height: sourceSize.height * _k
              constraintSize: Qt.size(Math.max(1, parent.width), Math.max(1, parent.height))
            }

            // Non-composite fallback: window title text
            NText {
              anchors.fill: parent
              visible: !capture.hasContent
              text: tile.modelData ? (tile.modelData.title || "") : ""
              pointSize: Style.fontSizeS
              color: Color.onShellSecondary
              elide: Text.ElideRight
              wrapMode: Text.WordWrap
              maximumLineCount: 3
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }

          // Attention frame: 5 px radius, Color.attention @0.8
          Rectangle {
            anchors.fill: parent
            radius: 5
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Color.attention.r, Color.attention.g, Color.attention.b, 0.8)
            visible: tile.urgent
          }

          // Click activates the window
          MouseArea {
            anchors.fill: parent
            onClicked: {
              if (tile.modelData && tile.modelData.toplevel && tile.modelData.toplevel.activate) {
                tile.modelData.toplevel.activate();
              }
              root.hide();
            }
          }

          // 24x24 close button, top-right, on hover
          NIconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            visible: tileHover.hovered
            baseSize: 24
            applyUiScale: false
            icon: "close"
            colorBg: Color.overlay("hover")
            tooltipText: ""
            onClicked: {
              if (tile.modelData && tile.modelData.toplevel && tile.modelData.toplevel.close) {
                tile.modelData.toplevel.close();
              }
            }
          }

          HoverHandler {
            id: tileHover
          }
        }
      }
    }
  }
}
