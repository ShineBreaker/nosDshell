import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NDccRow - the DDE SettingsItem row container (DESIGN §3.5.4).
*
* Background `overlay("strong")`, `overlay("checked")` while an interactive row
* is hovered, a 2 px Color.alert border in the error state. Rows are at least
* 36 px tall but grow for a description or a slider groove; horizontal padding
* is 20, vertical 10.
*
* Outer corners are automatic: a row is the group's head when the nearest
* visible sibling above it is not a dcc row (or there is none), and its tail
* when the same holds below. That mirrors SettingsGroup::updateHeadTail()
* (settingsgroup.cpp:172-192), which only walks visible items. The scan is
* declarative, so a sibling being added, removed or hidden re-runs it and a
* bulk change costs a single re-evaluation instead of one per row.
*
* A row inside an NSettingsGroup takes isFirst/isLast from the group instead, so
* an explicit group layout still wins.
*
* Use it as the root of a control, or drop plain content into it. Set
* `interactive: false` for a read-only row and `error: true` for the alert
* border.
*/
Rectangle {
  id: root

  // Rows recognise each other through this marker.
  readonly property bool isDccRow: true

  default property alias content: contentRow.data

  property bool interactive: true
  property bool error: false
  // Hover can be driven from the outside when the control already owns a
  // MouseArea covering the whole row (NCheckbox).
  property bool hovered: false
  // Explicit corner overrides, used when the parent is an NSettingsGroup.
  property bool isFirst: false
  property bool isLast: false

  signal clicked

  implicitHeight: Math.max(Style.settingsRowHeight, contentRow.implicitHeight + Style.settingsRowPaddingV * 2)
  implicitWidth: contentRow.implicitWidth + Style.settingsRowPaddingH * 2

  color: rowColor
  border.color: root.error ? Color.alert : "transparent"
  border.width: root.error ? Style.borderM : 0

  readonly property color rowColor: {
    if (root.hovered && root.interactive && !root.error)
      return Color.overlay("checked");
    return Color.overlay("strong");
  }

  // Only the head row's top corners and the tail row's bottom corners are
  // rounded; rows in between stay square so the 1 px gaps read as separators
  // (common.qss: SettingsItem[isHead=true] / [isTail=true]).
  readonly property bool headRow: root._groupDriven ? root.isFirst : root._autoIsFirst
  readonly property bool tailRow: root._groupDriven ? root.isLast : root._autoIsLast

  topLeftRadius: headRow ? Style.radiusItem : 0
  topRightRadius: headRow ? Style.radiusItem : 0
  bottomLeftRadius: tailRow ? Style.radiusItem : 0
  bottomRightRadius: tailRow ? Style.radiusItem : 0

  Behavior on color {
    enabled: !Color.isTransitioning
    ColorAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  // Row content, inset by the standard row padding. A RowLayout so simple rows
  // can drop children in directly; controls that stack their title over a
  // control nest a ColumnLayout inside.
  RowLayout {
    id: contentRow
    anchors.fill: parent
    anchors.leftMargin: Style.settingsRowPaddingH
    anchors.rightMargin: Style.settingsRowPaddingH
    anchors.topMargin: Style.settingsRowPaddingV
    anchors.bottomMargin: Style.settingsRowPaddingV
    spacing: Style.marginM
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.interactive
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }

  // ---- automatic head/tail detection -------------------------------------
  readonly property var _siblings: parent ? parent.children : null
  readonly property int _index: {
    const kids = root._siblings;
    if (!kids)
      return -1;
    for (let i = 0; i < kids.length; i++) {
      if (kids[i] === root)
        return i;
    }
    return -1;
  }

  // Nearest visible dcc row above; anything else (a header, a gap, nothing)
  // makes this row the head of its group.
  readonly property bool _autoIsFirst: {
    const kids = root._siblings;
    const idx = root._index;
    if (!kids || idx < 0)
      return true;
    for (let i = idx - 1; i >= 0; i--) {
      const sibling = kids[i];
      if (sibling && sibling.visible !== false)
        return sibling.isDccRow !== true;
    }
    return true;
  }

  readonly property bool _autoIsLast: {
    const kids = root._siblings;
    const idx = root._index;
    if (!kids || idx < 0)
      return true;
    for (let i = idx + 1; i < kids.length; i++) {
      const sibling = kids[i];
      if (sibling && sibling.visible !== false)
        return sibling.isDccRow !== true;
    }
    return true;
  }

  // An NSettingsGroup hands out isFirst/isLast for its own children.
  readonly property bool _groupDriven: parent !== null && parent.isDccSettingsGroup === true
}
