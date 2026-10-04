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
      kids[i].isFirst = (i === 0);
      kids[i].isLast = (i === kids.length - 1);
      // Rows span the group width (NSettingsItem is a Rectangle, not a layout).
      kids[i].width = Qt.binding(() => root.width);
    }
  }
}
