import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root
  objectName: "NTabBar"

  // Public properties
  property int currentIndex: 0
  property real spacing: Style.marginXS
  property real margins: 0
  property real tabHeight: Style.baseWidgetSize
  property bool distributeEvenly: false
  default property alias content: tabRow.children

  // DDE settings mode (DESIGN §3.5.3–3.5.4): the horizontal sub-tab strip is
  // replaced by a SettingsHead above each sub-tab's own group. The paired
  // NTabView renders those heads while it is `stacked`, so the strip itself
  // collapses; pair the two with `NTabView.stacked`.
  property bool groupMode: false
  visible: !groupMode

  onGroupModeChanged: _updateGroupMode()
  onDistributeEvenlyChanged: _applyDistribution()
  Component.onCompleted: {
    _updateGroupMode();
    _applyDistribution();
  }

  function _updateGroupMode() {
    if (!tabRow)
      return;
    color = groupMode ? "transparent" : Color.overlay("strong");
    for (let i = 0; i < tabRow.children.length; i++) {
      const child = tabRow.children[i];
      if (child.isTabButton === true) {
        child.plain = groupMode;
        child.isFirst = false;
        child.isLast = false;
      }
    }
    tabRow.spacing = groupMode ? Style.marginS : root.spacing;
  }

  // The titles a stacked NTabView draws as its per-tab SettingsHeads.
  function groupTitles() {
    const titles = [];
    if (!tabRow || !tabRow.children)
      return titles;
    for (let i = 0; i < tabRow.children.length; i++) {
      const child = tabRow.children[i];
      if (child && child.isTabButton === true)
        titles.push(child.text);
    }
    return titles;
  }

  function _updateFirstLast() {
    // Defensive check for QML initialization timing
    if (!tabRow || !tabRow.children) {
      return;
    }
    var kids = tabRow.children;
    var len = kids.length;
    var firstVisible = -1;
    var lastVisible = -1;
    for (var i = 0; i < len; i++) {
      var child = kids[i];
      // Only consider items that have isFirst/isLast (actual tab buttons, not Repeaters)
      if (child.visible && "isFirst" in child) {
        if (firstVisible === -1)
          firstVisible = i;
        lastVisible = i;
      }
    }
    for (var i = 0; i < len; i++) {
      var child = kids[i];
      if ("isFirst" in child)
        child.isFirst = (i === firstVisible);
      if ("isLast" in child)
        child.isLast = (i === lastVisible);
    }
  }

  function _applyDistribution() {
    if (!tabRow || !tabRow.children) {
      return;
    }
    if (!distributeEvenly) {
      for (var i = 0; i < tabRow.children.length; i++) {
        var child = tabRow.children[i];
        child.Layout.fillWidth = true;
      }
      return;
    }

    for (var i = 0; i < tabRow.children.length; i++) {
      var child = tabRow.children[i];
      child.Layout.fillWidth = true;
      child.Layout.preferredWidth = 1;
    }
  }

  // Styling
  Layout.margins: Style.borderS
  implicitWidth: tabRow.implicitWidth + (margins * 2)
  implicitHeight: tabHeight + (margins * 2)
  color: Color.overlay("strong")
  radius: Style.radiusItem

  RowLayout {
    id: tabRow
    anchors.fill: parent
    anchors.margins: margins
    spacing: root.spacing

    onChildrenChanged: {
      for (var i = 0; i < children.length; i++) {
        var child = children[i];
        child.visibleChanged.connect(root._updateFirstLast);
      }
      root._updateFirstLast();
      root._applyDistribution();
    }
  }
}
