import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NSettingsGroup - a DDE SettingsGroup (DESIGN §3.5.4).
*
* Rows stack vertically with a 1 px gap that lets the mask show through; only
* the first row's top corners and the last row's bottom corners are rounded
* (applied here, on the rows, so no group background is needed).
*
* Usage:
*   NSettingsGroup {
*     NSettingsItem { title: ... }
*     NSettingsItem { title: ... }
*   }
*/
Item {
  id: root

  // NDccRow reads this to know the group already decided the head/tail corners
  // for its children and it should not re-derive them.
  readonly property bool isDccSettingsGroup: true
  // A group is not itself a row: to a neighbouring row it reads as a boundary.
  readonly property bool isDccRow: false

  default property alias content: column.data

  implicitWidth: implicitContentWidth
  implicitHeight: column.implicitHeight

  readonly property real implicitContentWidth: {
    var w = 0;
    for (var i = 0; i < column.children.length; i++) {
      var c = column.children[i];
      if (c && c.implicitWidth !== undefined)
        w = Math.max(w, c.implicitWidth);
    }
    return w;
  }

  Column {
    id: column
    width: parent.width
    spacing: Style.settingsGroupGap

    onChildrenChanged: Qt.callLater(root.applyCorners)
    Component.onCompleted: Qt.callLater(root.applyCorners)
  }

  function applyCorners() {
    const kids = column.children;
    for (var i = 0; i < kids.length; i++) {
      if (kids[i] === undefined || kids[i] === null)
        continue;
      // DDE only looks at visible items (settingsgroup.cpp:172-192), so an
      // invisible row neither holds the corners nor gives them up.
      const visible = kids[i].visible !== false;
      kids[i].isFirst = visible && (i === 0 || !isVisibleRow(kids[i - 1]));
      kids[i].isLast = visible && (i === kids.length - 1 || !isVisibleRow(kids[i + 1]));
      // Rows span the group width (NSettingsItem is a Rectangle, not a layout).
      kids[i].width = Qt.binding(() => root.width);
    }
  }

  function isVisibleRow(child) {
    return child !== undefined && child !== null && child.visible !== false;
  }
}
