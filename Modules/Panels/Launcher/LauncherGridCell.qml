import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import qs.Commons
import qs.Widgets
import QtQuick.Layouts

// Fullscreen grid cell (DESIGN §3.4.1): icon = cell * iconRatio above a 12 px
// label (max 2 lines, elided, with the DDE text shadow), hover/selected drawn as
// a pressDim (black @0.41) rounded block, new-app dot to the left of the label.
Item {
  id: root

  required property var modelData
  required property int index
  // Owning grid, injected by NGridView; may be null during early evaluation.
  property var gridView: GridView.view

  // Emitted on left-click; the owning view maps `index` back to the result
  // object in the launcher model, then selects and activates it.
  signal activated

  property int iconSize: 85

  // New until first launch (tracked in ShellState by ApplicationsProvider)
  readonly property bool isNew: modelData.isNew === true

  readonly property bool selected: root.gridView !== null && index === root.gridView.currentIndex

  // Hover/press block inset, from the curve fit in appitemdelegate.cpp:92-97:
  // margin = (0.26418192 * cellWidth - 0.38890932 * iconWidth) * 0.71
  readonly property real blockMargin: Math.max(1, (0.26418192 * width - 0.38890932 * root.iconSize) * 0.71)
  // itemBoundingRect(): the top-aligned square inside the cell (cells are
  // already square; keep the formula so a non-square cell still behaves).
  readonly property real _side: Math.min(width, height)

  // Hover/press block — upstream `br` = itemBoundingRect minus
  // QMargins(margin, 1, margin, margin*2). The block contains BOTH the icon
  // and the label: itemTextRect() derives the name area from `br`, so the
  // content column is anchored inside the block, not to the raw cell.
  Rectangle {
    id: block
    x: (root.width - root._side) / 2 + root.blockMargin
    y: 1
    width: root._side - root.blockMargin * 2
    height: root._side - 1 - root.blockMargin * 2
    radius: Style.radiusLarge
    color: (mouseArea.containsMouse || root.selected) ? Color.pressDim : "transparent"
  }

  ColumnLayout {
    anchors.left: block.left
    anchors.right: block.right
    anchors.top: block.top
    anchors.bottom: block.bottom
    anchors.margins: 2
    spacing: 0

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.iconSize
      // Upstream iconTopMargin = max(ibr.height*0.2 - iconSize*0.3, 1)
      Layout.topMargin: Math.max(1, root._side * 0.2 - root.iconSize * 0.3)
      Layout.alignment: Qt.AlignHCenter

      IconImage {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: modelData.icon ? ThemeIcons.iconFromName(modelData.icon) : ""
        visible: source !== ""
        asynchronous: true
        smooth: true
      }

      NIcon {
        anchors.centerIn: parent
        pointSize: root.iconSize * 0.9
        color: Color.onWallpaper
        visible: !modelData.icon || modelData.icon === ""
      }
    }

    // Label: 12 px white, 2 lines max, elided, DDE text shadow (§1.5)
    NText {
      id: appLabel
      Layout.fillWidth: true
      Layout.topMargin: Math.max(1, root.iconSize * 0.06)
      text: modelData.name || ""
      pointSize: Style.fontSizeBody
      color: Color.onWallpaper
      style: Text.Sunken
      styleColor: Color.onWallpaperShadow
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignTop
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
  }

  // New app dot: 10 px accent circle at the left of the label's first line
  // (upstream: textRect.topLeft shifted left by the dot width, appitemdelegate.cpp:172)
  Rectangle {
    visible: root.isNew
    width: 10
    height: 10
    radius: width / 2
    color: Color.accent
    x: block.x + 2
    y: appLabel.mapToItem(root, 0, 0).y - 1
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   // Build the menu on the first right-click only.
                   appContextMenuLoader.active = true;
                   appContextMenuLoader.item?.openAtItem(root, mouse.x, mouse.y);
                 } else {
                   root.activated();
                 }
               }
  }

  // Right-click: DDE dark menu without arrow at the cursor (DESIGN §3.4.1).
  // Lazy: the grid builds dozens of cells on open/filter, and a resident
  // Popup tree (background + contentItem) in each one is pure first-open
  // cost — only a right-click ever needs it.
  Loader {
    id: appContextMenuLoader
    active: false

    sourceComponent: NContextMenu {
      id: appContextMenu
      variant: "dark"
      arrowEdge: "" // no arrow in the fullscreen launcher

      readonly property var itemActions: {
        const provider = root.modelData.provider;
        if (provider && provider.getItemActions) {
          return provider.getItemActions(root.modelData) || [];
        }
        return [];
      }

      // { label, action: "key:string" } — resolved in onTriggered
      model: {
        const actions = appContextMenu.itemActions;
        const items = [];
        for (let i = 0; i < actions.length; i++) {
          items.push({
                       "label": actions[i].tooltip || actions[i].label || "",
                       "icon": actions[i].icon || "",
                       "action": "row:" + i
                     });
        }
        return items;
      }

      onTriggered: (action, item) => {
                     if (typeof action === "string" && action.startsWith("row:")) {
                       const idx = parseInt(action.substring(4));
                       const actions = appContextMenu.itemActions;
                       if (idx >= 0 && idx < actions.length && actions[idx].action) {
                         actions[idx].action();
                       }
                     }
                   }
    }
  }
}
