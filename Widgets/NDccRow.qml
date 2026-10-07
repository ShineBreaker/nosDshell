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
* An explicit isFirst/isLast override still wins over the automatic scan.
*
* Use it as the root of a control, or drop plain content into it. Set
* `interactive: false` for a read-only row and `error: true` for the alert
* border.
*/
Rectangle {
  id: root

  // Rows recognise each other through this marker. A plain row is not one: it
  // has no chrome, so it also ends the run of rows above it.
  readonly property bool isDccRow: !root.plain

  default property alias content: contentRow.data

  // Forwarded so a control can keep declaring `spacing` on its root the way it
  // did when the root was a RowLayout.
  property alias spacing: contentRow.spacing

  property bool interactive: true
  property bool error: false
  // Plain mode drops the row chrome entirely (no fill, no padding, no minimum
  // height). Controls set this when they have no label to show, so a bare
  // switch or combo still looks like it always did.
  property bool plain: false
  // Rows that are clickable in their own right install a click area. Controls
  // whose content already handles clicks (switch, combo, slider) leave this
  // false so the content keeps its input.
  property bool clickable: false
  // Hover can be driven from the outside when the control already owns a
  // MouseArea covering the whole row (NCheckbox).
  property bool hovered: false
  // Manual corner overrides: win over the automatic scan when set.
  property bool isFirst: false
  property bool isLast: false

  signal clicked

  // DDE's SettingsGroup is a QVBoxLayout, so every item in it is stretched to
  // the group width (settingsgroup.cpp:46-47). Rows do the same; a bare control
  // keeps its content width so a switch in a dock popup does not stretch. A
  // caller can still pin a labelled row with `Layout.fillWidth: false`.
  Layout.fillWidth: !root.plain

  // A row is stretched by its container (DDE's SettingsItem is a QFrame in a
  // QVBoxLayout and never drives the group's width), so the implicit width is
  // only a hint. Cap it at one content width: a long description would
  // otherwise widen the enclosing scroll column past the module view and push
  // the row's right-hand control off screen.
  implicitHeight: plain ? contentRow.implicitHeight : Math.max(Style.settingsRowHeight, contentRow.implicitHeight + Style.settingsRowPaddingV * 2)
  implicitWidth: Math.min(contentRow.implicitWidth, Style.settingsRowContentMaxWidth) + (plain ? 0 : Style.settingsRowPaddingH * 2)

  color: rowColor
  border.color: root.error ? Color.alert : "transparent"
  border.width: root.error ? Style.borderM : 0

  readonly property color rowColor: {
    if (root.plain)
      return "transparent";
    if (root.hovered && root.interactive && !root.error)
      return Color.overlay("checked");
    return Color.overlay("strong");
  }

  // Only the head row's top corners and the tail row's bottom corners are
  // rounded; rows in between stay square so the 1 px gaps read as separators
  // (common.qss: SettingsItem[isHead=true] / [isTail=true]).
  readonly property bool headRow: root.plain ? false : (root.isFirst || root._autoIsFirst)
  readonly property bool tailRow: root.plain ? false : (root.isLast || root._autoIsLast)

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
    anchors.leftMargin: root.plain ? 0 : Style.settingsRowPaddingH
    anchors.rightMargin: root.plain ? 0 : Style.settingsRowPaddingH
    anchors.topMargin: root.plain ? 0 : Style.settingsRowPaddingV
    anchors.bottomMargin: root.plain ? 0 : Style.settingsRowPaddingV
    spacing: Style.marginM
  }

  // A passive hover handler rather than a MouseArea: the row's own children
  // (switch, combo, slider) own their clicks, and a MouseArea covering the
  // whole row would swallow them.
  HoverHandler {
    id: rowHover
    enabled: root.interactive
    onHoveredChanged: root.hovered = hovered
  }

  // Only rows that are clickable in their own right (e.g. NCheckbox)
  // get a click area; the rest let their content handle input.
  MouseArea {
    anchors.fill: parent
    visible: root.clickable
    enabled: root.clickable && root.interactive
    hoverEnabled: true
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

}
