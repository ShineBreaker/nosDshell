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

  // Hover/press block
  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: root.blockMargin
    anchors.rightMargin: root.blockMargin
    anchors.topMargin: 1
    anchors.bottomMargin: root.blockMargin * 2
    radius: Style.radiusLarge
    color: (mouseArea.containsMouse || root.selected) ? Color.pressDim : "transparent"
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 6
    spacing: 0

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.iconSize
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
        color: Color.onShell
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
      color: Color.onShell
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignTop
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
  }

  // New app dot: 10 px accent circle at the left of the label
  Rectangle {
    visible: root.isNew
    width: 10
    height: 10
    radius: width / 2
    color: Color.accent
    x: 8
    y: parent.height - height - 8
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   appContextMenu.openAtItem(root, mouse.x, mouse.y);
                 } else {
                   root.activated();
                 }
               }
  }

  // Right-click: DDE dark menu without arrow at the cursor (DESIGN §3.4.1)
  NContextMenu {
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
