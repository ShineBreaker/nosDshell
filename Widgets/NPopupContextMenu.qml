import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI

// Simple context menu PopupWindow (similar to TrayMenu)
// Designed to be rendered inside a PopupMenuWindow for click-outside-to-close
// Automatically positions itself to respect screen boundaries
// DDE deepin-menu look (DESIGN §3.3): arrowed dark popup, full-row accent
// hover, 20px side padding, font-height+8 rows, groove separators.
PopupWindow {
  id: root

  property alias model: repeater.model
  property real itemHeight: -1 // -1 = auto: font height + 8
  property real itemPadding: Style.menuItemPadding
  property int verticalPolicy: ScrollBar.AsNeeded
  property int horizontalPolicy: ScrollBar.AsNeeded

  property var anchorItem: null
  property ShellScreen screen: null
  property real minWidth: 120
  property real calculatedWidth: 180

  // Explicit offset for centering on target item (computed from targetItem in openAtItem)
  property real targetOffsetX: 0
  property real targetOffsetY: 0
  property real targetWidth: 0
  property real targetHeight: 0

  // DDE menu variants (DESIGN §3.3): "dark" (default) or "light"
  property string variant: "dark"
  // Arrowed popup plumbing; callers set these when they anchor the menu
  property string arrowEdge: ""
  property real arrowPosition: -1 // -1 = centered

  // Submenu support: model entries may carry hasSubmenu: true + submenu: [...].
  // Submenus are nested PopupWindows anchored to the parent row (same pattern
  // as Modules/Bar/Extras/TrayMenu.qml).
  property bool isSubmenu: false
  property real submenuAnchorX: 0
  property real submenuAnchorY: 0

  readonly property bool _light: variant === "light"
  readonly property color _bgColor: _light ? Color.popupLight : Color.popupShell
  readonly property color _borderColor: _light ? Color.popupLightBorder : Color.borderShell
  readonly property real _radius: _light ? Style.radiusRow : Style.radiusPopup
  readonly property var _shadow: _light ? Style.shadowMenuLight : Style.shadowPopup
  readonly property color _textColor: _light ? Color.popupLightText : Color.onShell
  readonly property color _disabledColor: _light ? Color.popupLightDisabled : Color.textDisabledDark
  readonly property real _rowHeight: itemHeight > 0 ? itemHeight : rowMeasure.implicitHeight + 8

  // Keyboard highlight index (-1 = none)
  property int highlightIndex: -1

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)

  // Thickness of the shell strip occupying `edge` on this screen: the bar
  // surface (efficient taskbar or fashion status bar, barHeight) or the
  // fashion dock window (dockItemThickness). Context menus must never extend
  // into that strip — the bar/dock layer paints above popups, so any overlap
  // renders the menu partially hidden.
  function _edgeOccupancy(edge) {
    var screenName = screen?.name;
    if (!screenName)
      return 0;
    if (BarService.hasBarOnScreen(screenName) && barPosition === edge)
      return barHeight;
    if (Settings.data.dock.enabled && Settings.getTaskbarPositionForScreen(screenName) === edge) {
      if (Settings.data.dock.mode === "fashion") {
        var dockMonitors = Settings.data.dock.monitors || [];
        if (dockMonitors.length > 0 && !dockMonitors.includes(screenName))
          return 0;
        return Style.dockItemThickness;
      }
      if (BarService.hasBarOnScreen(screenName))
        return barHeight;
    }
    return 0;
  }

  signal triggered(string action, var item)

  implicitWidth: calculatedWidth + (arrowEdge === "left" || arrowEdge === "right" ? Style.popupArrowHeight : 0)
  implicitHeight: Math.min(600, flickable.contentHeight + Style.margin2S) + (arrowEdge === "top" || arrowEdge === "bottom" ? Style.popupArrowHeight : 0)
  visible: false
  color: "transparent"

  NText {
    id: rowMeasure
    visible: false
    text: "Ag"
    pointSize: Style.fontSizeS
  }

  NText {
    id: textMeasure
    visible: false
    pointSize: Style.fontSizeS
    wrapMode: Text.NoWrap
    elide: Text.ElideNone
    width: undefined
  }

  NIcon {
    id: iconMeasure
    visible: false
    icon: "bell"
    pointSize: Style.fontSizeS
    applyUiScale: false
  }

  onModelChanged: {
    Qt.callLater(calculateWidth);
  }

  function _isSeparator(item) {
    return item && (item.separator === true || item.type === "separator" || item.action === "separator");
  }

  function _isActivatable(index) {
    var item = model && model[index];
    return item && !_isSeparator(item) && item.visible !== false && item.enabled !== false;
  }

  function _hasSubmenu(item) {
    return item && item.hasSubmenu === true && item.submenu !== undefined && item.submenu.length > 0;
  }

  function _activate(index) {
    if (_isActivatable(index)) {
      var item = model[index];
      if (_hasSubmenu(item)) {
        var row = repeater.itemAt(index);
        if (row && row._openSubmenu)
          row._openSubmenu();
        return;
      }
      root.triggered(item.action || item.key || index.toString(), item);
    }
  }

  function _closeSubmenusExcept(row) {
    for (var i = 0; i < columnLayout.children.length; i++) {
      var child = columnLayout.children[i];
      if (child !== row && child.subMenu) {
        child.subMenu.close();
        child.subMenu.destroy();
        child.subMenu = null;
      }
    }
  }

  function _closeSubmenus() {
    _closeSubmenusExcept(null);
  }

  function _hasOpenSubmenu() {
    for (var i = 0; i < columnLayout.children.length; i++) {
      if (columnLayout.children[i].subMenu)
        return true;
    }
    return false;
  }

  // Programmatically open the submenu of row `index` (verification/testing).
  function openSubmenuAt(index) {
    var row = repeater.itemAt(index);
    if (row && row.hasSubmenu && row._openSubmenu)
      row._openSubmenu();
  }

  function calculateWidth() {
    let maxWidth = 0;
    if (model && model.length) {
      for (let i = 0; i < model.length; i++) {
        const item = model[i];
        if (item && item.visible !== false && !_isSeparator(item)) {
          const label = item.label || item.text || "";
          textMeasure.text = label;
          textMeasure.forceLayout();

          let itemWidth = textMeasure.contentWidth + 8;

          if (item.icon !== undefined) {
            itemWidth += iconMeasure.width + Style.marginS;
          }

          if (item.checked === true || item.hasSubmenu === true) {
            itemWidth += Style.fontSizeXL + Style.marginS;
          }

          // RowLayout side padding (itemPadding, 20 each end) — the +8 and
          // margin2M slack alone don't cover it, so short labels elided.
          itemWidth += 2 * root.itemPadding + Style.margin2M;

          if (itemWidth > maxWidth) {
            maxWidth = itemWidth;
          }
        }
      }
    }
    // Width follows the longest label (DESIGN §3.3: text + 50, cap 500) —
    // elide only past the cap, never inside a menu that has room.
    calculatedWidth = Math.max(minWidth, Math.min(Math.round(500 * Style.uiScaleRatio), maxWidth + Style.margin2S));
  }

  anchor.item: anchorItem

  anchor.rect.x: {
    // Submenus anchor beside the parent row, flipping left when they would clip
    // the right screen edge (TrayMenu.qml pattern).
    if (isSubmenu && anchorItem) {
      var posInPopupX = anchorItem.mapToItem(null, 0, 0);
      var parentWindowX = anchorItem.Window ? anchorItem.Window.window : null;
      var windowXOnScreen = (parentWindowX && screen) ? (parentWindowX.x - screen.x) : 0;
      var menuScreenX = windowXOnScreen + posInPopupX.x + submenuAnchorX;
      if (screen && menuScreenX + implicitWidth > screen.width) {
        return -implicitWidth + Style.marginS;
      }
      if (screen && menuScreenX < 0) {
        return submenuAnchorX - menuScreenX;
      }
      return submenuAnchorX;
    }
    if (anchorItem && screen) {
      const anchorGlobalPos = anchorItem.mapToItem(null, 0, 0);

      // Use stored targetOffsetX and targetWidth for positioning
      const effectiveWidth = targetWidth > 0 ? targetWidth : anchorItem.width;
      const targetGlobalX = anchorGlobalPos.x + targetOffsetX;

      let baseX;
      if (root.barPosition === "right") {
        // For right bar: position menu to the left of target
        baseX = targetOffsetX - implicitWidth - Style.marginM;
      } else if (root.barPosition === "left") {
        // For left bar: position menu to the right of target
        baseX = targetOffsetX + effectiveWidth + Style.marginM;
      } else {
        // For top/bottom bar: center horizontally on target
        const targetCenterScreenX = targetGlobalX + (effectiveWidth / 2);
        baseX = targetCenterScreenX - (implicitWidth / 2) - anchorGlobalPos.x;
      }

      // Clamp inside the screen, additionally keeping clear of whatever shell
      // strip occupies each vertical edge (the menu would paint under it)
      const leftOcc = root._edgeOccupancy("left");
      const rightOcc = root._edgeOccupancy("right");
      const leftLimit = leftOcc > 0 ? leftOcc + Style.marginS : Style.marginM;
      const rightLimit = screen.width - (rightOcc > 0 ? rightOcc + Style.marginS : Style.marginM) - implicitWidth;
      let menuScreenX = anchorGlobalPos.x + baseX;
      if (menuScreenX > rightLimit)
        menuScreenX = rightLimit;
      if (menuScreenX < leftLimit)
        menuScreenX = leftLimit;
      return menuScreenX - anchorGlobalPos.x;
    }
    return 0;
  }
  anchor.rect.y: {
    // Submenus align their top with the parent row, shifting up when they would
    // clip the bottom screen edge.
    if (isSubmenu && anchorItem) {
      var posInPopupY = anchorItem.mapToItem(null, 0, 0);
      var parentWindowY = anchorItem.Window ? anchorItem.Window.window : null;
      var windowYOnScreen = (parentWindowY && screen) ? (parentWindowY.y - screen.y) : 0;
      var menuScreenY = windowYOnScreen + posInPopupY.y + submenuAnchorY;
      var screenHeight = screen ? screen.height : 0;
      var overflowBottom = menuScreenY + implicitHeight - (screenHeight - Style.marginM);
      if (screen && overflowBottom > 0) {
        return submenuAnchorY - overflowBottom;
      }
      if (screen && menuScreenY < Style.marginM) {
        return submenuAnchorY + (Style.marginM - menuScreenY);
      }
      return submenuAnchorY;
    }
    if (anchorItem && screen) {
      // Check if using absolute positioning (small anchor point item)
      const isAbsolutePosition = anchorItem.width <= 1 && anchorItem.height <= 1;

      if (isAbsolutePosition) {
        const anchorGlobalPos = anchorItem.mapToItem(null, 0, 0);
        const menuTop = anchorGlobalPos.y;
        const menuBottom = anchorGlobalPos.y + implicitHeight;

        // Keep the menu out of the strip any shell surface occupies on either
        // horizontal edge — anchoring at the click point alone leaves the menu
        // inside the taskbar/dock whenever the click lands on it.
        const topOcc = root._edgeOccupancy("top");
        const bottomOcc = root._edgeOccupancy("bottom");
        const absTopLimit = topOcc > 0 ? topOcc + Style.marginS : Style.marginM;
        const absBottomLimit = screen.height - (bottomOcc > 0 ? bottomOcc + Style.marginS : Style.marginM);
        if (menuTop < absTopLimit) {
          return absTopLimit - menuTop;
        }
        if (menuBottom > absBottomLimit) {
          if (bottomOcc > 0) {
            return absBottomLimit - implicitHeight - menuTop;
          }
          // Position above the click point instead
          return -implicitHeight;
        }
        return 0;
      }

      const anchorGlobalPos = anchorItem.mapToItem(null, 0, 0);

      // Use target offset/height for vertical bars, anchor dimensions otherwise
      const effectiveHeight = targetHeight > 0 ? targetHeight : anchorItem.height;
      const effectiveOffsetY = targetOffsetY;

      // Calculate base Y position based on bar orientation
      let baseY;
      if (root.barPosition === "bottom") {
        // For bottom bar: position menu above the bar
        baseY = -(implicitHeight + Style.marginS);
      } else if (root.barPosition === "top") {
        // For top bar: position menu below bar at consistent height
        // Compensate for anchor's Y position to ensure menu top is always at (barHeight + margin)
        baseY = barHeight + Style.marginS - anchorGlobalPos.y;
      } else {
        // For left/right bar: vertically center on target item
        const targetCenterY = effectiveOffsetY + (effectiveHeight / 2);
        baseY = targetCenterY - (implicitHeight / 2);
      }

      const menuScreenY = anchorGlobalPos.y + baseY;
      const menuBottom = menuScreenY + implicitHeight;

      // Define clipping boundaries per edge; the occupied strips cover the
      // status bar and the fashion dock alike
      const topOcc2 = root._edgeOccupancy("top");
      const bottomOcc2 = root._edgeOccupancy("bottom");
      const topLimit = topOcc2 > 0 ? topOcc2 + Style.marginS : Style.marginM;
      const bottomLimit = bottomOcc2 > 0 ? screen.height - bottomOcc2 - Style.marginS : screen.height - Style.marginM;

      // Adjust if menu would clip at top (skip when the bottom edge is
      // occupied - don't push the menu down over the taskbar/dock)
      if (menuScreenY < topLimit && bottomOcc2 === 0) {
        const adjustment = topLimit - menuScreenY;
        return baseY + adjustment;
      }

      // Adjust if menu would clip at bottom (or overlap bar for bottom bar)
      if (menuBottom > bottomLimit) {
        const overflow = menuBottom - bottomLimit;
        return baseY - overflow;
      }

      return baseY;
    }

    // Fallback if no screen
    if (root.barPosition === "bottom") {
      return -implicitHeight - Style.marginS;
    }
    return barHeight;
  }

  Component.onCompleted: {
    Qt.callLater(calculateWidth);
  }

  Item {
    anchors.fill: parent
    focus: true

    // Keyboard navigation: Up/Down move, Enter triggers, Escape closes
    Keys.onUpPressed: {
      var n = root.model ? root.model.length : 0;
      if (n === 0)
        return;
      var i = root.highlightIndex;
      var steps = 0;
      do {
        i = (i <= 0) ? n - 1 : i - 1;
        steps++;
      } while (steps < n && !root._isActivatable(i))
      root.highlightIndex = i;
    }
    Keys.onDownPressed: {
      var n = root.model ? root.model.length : 0;
      if (n === 0)
        return;
      var i = root.highlightIndex;
      var steps = 0;
      do {
        i = (i >= n - 1) ? 0 : i + 1;
        steps++;
      } while (steps < n && !root._isActivatable(i))
      root.highlightIndex = i;
    }
    Keys.onReturnPressed: root._activate(root.highlightIndex)
    Keys.onEnterPressed: root._activate(root.highlightIndex)
    Keys.onRightPressed: {
      var row = repeater.itemAt(root.highlightIndex);
      if (row && row.hasSubmenu && row._openSubmenu)
        row._openSubmenu();
    }
    Keys.onLeftPressed: {
      if (root.isSubmenu)
        root.close();
    }
    Keys.onEscapePressed: {
      if (root._hasOpenSubmenu())
        root._closeSubmenus();
      else
        root.close();
    }
  }

  NArrowRect {
    id: menuBackground
    anchors.fill: parent
    arrowEdge: root.arrowEdge
    arrowPosition: root.arrowPosition
    radius: root._radius
    fillColor: root._bgColor
    borderColor: root._borderColor
    borderWidth: Style.borderS
    shadow: root._shadow
    // DDE menus appear/disappear instantly (deepin-menu has no animations)
    opacity: root.visible && !root._closing ? 1.0 : 0.0
  }

  Flickable {
    id: flickable
    x: menuBackground.bodyRect.x + Style.marginS
    y: menuBackground.bodyRect.y + Style.marginS
    width: menuBackground.bodyRect.width - Style.margin2S
    height: menuBackground.bodyRect.height - Style.margin2S
    contentHeight: columnLayout.implicitHeight
    interactive: true
    clip: true
    opacity: root.visible && !root._closing ? 1.0 : 0.0

    ColumnLayout {
      id: columnLayout
      width: flickable.width
      spacing: 0

      Repeater {
        id: repeater

        delegate: Rectangle {
          id: menuItem
          required property var modelData
          required property int index

          readonly property bool isSeparator: root._isSeparator(modelData)
          readonly property bool rowEnabled: modelData.enabled !== false
          readonly property bool hasSubmenu: root._hasSubmenu(modelData)
          readonly property bool active: rowEnabled && (mouseArea.containsMouse || root.highlightIndex === index)
          property var subMenu: null

          // Open this row's submenu beside the parent menu. The child is a
          // nested PopupWindow anchored to this row (TrayMenu.qml pattern).
          function _openSubmenu() {
            if (menuItem.subMenu || !menuItem.hasSubmenu)
              return;
            var sub = Qt.createComponent("NPopupContextMenu.qml").createObject(root, {
                                                                                 "isSubmenu": true,
                                                                                 "variant": root.variant,
                                                                                 "screen": root.screen,
                                                                                 "minWidth": root.minWidth,
                                                                                 "submenuAnchorX": menuItem.width - Style.marginS,
                                                                                 "submenuAnchorY": 0,
                                                                                 "anchorItem": menuItem,
                                                                                 "model": menuItem.modelData.submenu || []
                                                                               });
            if (!sub)
              return;
            menuItem.subMenu = sub;
            sub.triggered.connect(function (action, item) {
              root.triggered(action, item);
            });
            sub.visible = true;
            Qt.callLater(() => {
                           if (menuItem.subMenu)
                           menuItem.subMenu.anchor.updateAnchor();
                         });
          }

          Timer {
            id: submenuOpenTimer
            interval: 250
            repeat: false
            onTriggered: menuItem._openSubmenu()
          }

          Component.onDestruction: {
            if (subMenu) {
              subMenu.close();
              subMenu.destroy();
              subMenu = null;
            }
          }

          Layout.preferredWidth: parent.width
          Layout.preferredHeight: modelData.visible !== false ? (isSeparator ? Style.marginS : root._rowHeight) : 0
          visible: modelData.visible !== false
          color: "transparent"

          // Separator: 6px row with the DDE two-line groove (dark over light, inset 4)
          Rectangle {
            visible: menuItem.isSeparator
            anchors.centerIn: parent
            width: parent.width - Style.margin2XS
            height: 2
            color: "transparent"

            Rectangle {
              width: parent.width
              height: 1
              color: Qt.rgba(0, 0, 0, 0.1)
            }
            Rectangle {
              y: 1
              width: parent.width
              height: 1
              color: Qt.rgba(1, 1, 1, 0.1)
            }
          }

          Rectangle {
            id: innerRect
            anchors.fill: parent
            visible: !menuItem.isSeparator
            color: menuItem.active ? Color.accent : "transparent"
            radius: Style.radiusRow

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.itemPadding
              anchors.rightMargin: root.itemPadding
              spacing: Style.marginS

              NIcon {
                visible: modelData.icon !== undefined
                icon: modelData.icon || ""
                pointSize: Style.fontSizeS
                applyUiScale: false
                color: !menuItem.rowEnabled ? root._disabledColor : menuItem.active ? Color.onAccent : root._textColor
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              NText {
                text: modelData.label || modelData.text || ""
                pointSize: Style.fontSizeS
                color: !menuItem.rowEnabled ? root._disabledColor : menuItem.active ? Color.onAccent : root._textColor
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              // Check mark / submenu chevron, 12px on the right
              NIcon {
                visible: modelData.checked === true || menuItem.hasSubmenu || modelData.hasSubmenu === true
                icon: (menuItem.hasSubmenu || modelData.hasSubmenu === true) ? "chevron-right" : "check"
                pointSize: Style.fontSizeXL
                color: !menuItem.rowEnabled ? root._disabledColor : menuItem.active ? Color.onAccent : Color.accent
              }
            }

            MouseArea {
              id: mouseArea
              anchors.fill: parent
              hoverEnabled: true
              enabled: menuItem.rowEnabled && root.visible
              cursorShape: Qt.PointingHandCursor

              onEntered: {
                if (menuItem.hasSubmenu) {
                  root._closeSubmenusExcept(menuItem);
                  submenuOpenTimer.restart();
                } else {
                  root._closeSubmenus();
                }
              }

              onExited: {
                submenuOpenTimer.stop();
              }

              onClicked: {
                if (menuItem.hasSubmenu) {
                  menuItem._openSubmenu();
                  return;
                }
                if (menuItem.modelData.enabled !== false) {
                  root.triggered(menuItem.modelData.action || menuItem.modelData.key || menuItem.index.toString(), menuItem.modelData);
                  // Don't call root.close() here - let the parent PopupMenuWindow handle closing
                }
              }
            }
          }
        }
      }
    }
  }

  // Helper function to open context menu anchored to an item
  // Position is calculated automatically based on bar position and screen boundaries
  // Optional centerOnItem: if provided, menu will be horizontally centered on this item instead of anchorItem
  function openAtItem(item, itemScreen, centerOnItem) {
    if (!item) {
      Logger.w("NPopupContextMenu", "anchorItem is undefined, won't show menu.");
      return;
    }

    // Set anchor and screen first
    anchorItem = item;
    screen = itemScreen || null;
    highlightIndex = -1;

    // Compute target offset and dimensions from centerOnItem
    if (centerOnItem && centerOnItem !== item) {
      const relPos = centerOnItem.mapToItem(item, 0, 0);
      targetOffsetX = relPos.x;
      targetOffsetY = relPos.y;
      targetWidth = centerOnItem.width;
      targetHeight = centerOnItem.height;
    } else {
      targetOffsetX = 0;
      targetOffsetY = 0;
      targetWidth = 0;
      targetHeight = 0;
    }

    // Calculate menu width after anchor is set
    calculateWidth();

    // Reopening while the fade-out is still running
    _closing = false;
    hideTimer.stop();

    visible = true;

    // Force anchor recalculation after showing
    Qt.callLater(() => {
                   anchor.updateAnchor();
                 });
  }

  onVisibleChanged: {
    if (!visible)
      _closeSubmenus();
  }

  // Fade-out before the popup surface unmaps: _closing drops the content
  // opacity (the Behavior animates it), the timer then flips visible.
  property bool _closing: false
  Timer {
    id: hideTimer
    interval: Style.animationFast
    onTriggered: {
      root.visible = false;
      root._closing = false;
    }
  }

  function close() {
    if (_closing)
      return;
    _closing = true;
    _closeSubmenus();
    hideTimer.restart();
  }

  function closeMenu() {
    close();
  }
}
