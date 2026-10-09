import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

/*
* NContextMenu - Popup-based context menu for use inside panels and dialogs
*
* Use this component when you need a context menu inside:
* - Settings panels
* - Dialogs
* - Repeater delegates
* - Any nested component context
*
* For bar widgets and top-level window contexts, use NPopupContextMenu instead,
* which provides better screen boundary handling and compositor integration.
*
* Usage:
*   NContextMenu {
*     id: contextMenu
*     parent: Overlay.overlay
*     model: [
*       { "label": "Action 1", "action": "action1", "icon": "icon-name" },
*       { "label": "Action 2", "action": "action2" }
*     ]
*     onTriggered: action => { Logger.i("MyModule", "Selected:", action) }
*   }
*
*   MouseArea {
*     onClicked: contextMenu.openAtItem(parent, mouse.x, mouse.y)
*   }
*
* DDE deepin-menu look (DESIGN §3.3): arrowed dark popup, full-row accent hover,
* 20px side padding, font-height+8 rows, two-line groove separators.
*/
Popup {
  id: root

  property var model: []
  property real itemHeight: -1 // -1 = auto: font height + 8
  property real itemPadding: Style.menuItemPadding
  property int verticalPolicy: ScrollBar.AsNeeded
  property int horizontalPolicy: ScrollBar.AsNeeded
  // Optional: explicit item whose bounds the menu must stay within.
  // When unset, openAtItem auto-detects the nearest clipping ancestor.
  property Item constrainTo: null
  property Item _detectedConstraint: null

  // DDE menu variants (DESIGN §3.3): "dark" (default) or "light"
  property string variant: "dark"
  // Arrowed popup plumbing; callers set these when they anchor the menu
  property string arrowEdge: ""
  property real arrowPosition: -1 // -1 = centered

  readonly property bool _light: variant === "light"
  readonly property color _bgColor: _light ? Color.popupLight : Color.popupShell
  readonly property color _borderColor: _light ? Color.popupLightBorder : Color.borderShell
  readonly property real _radius: _light ? Style.radiusRow : Style.radiusPopup
  readonly property var _shadow: _light ? Style.shadowMenuLight : Style.shadowPopup
  readonly property color _textColor: _light ? Color.popupLightText : Color.onShell
  readonly property color _disabledColor: _light ? Color.popupLightDisabled : Color.textDisabledDark
  readonly property real _rowHeight: itemHeight > 0 ? itemHeight : rowMeasure.implicitHeight + 8

  signal triggered(string action)

  NText {
    id: rowMeasure
    visible: false
    text: "Ag"
    pointSize: Style.fontSizeM
  }

  // Filter out hidden items to avoid spacing artifacts from zero-height items
  readonly property var filteredModel: {
    if (!model || model.length === 0)
      return [];
    var filtered = [];
    for (var i = 0; i < model.length; i++) {
      if (model[i].visible !== false) {
        filtered.push(model[i]);
      }
    }
    return filtered;
  }

  width: 180
  padding: Style.marginS
  topPadding: Style.marginS + (arrowEdge === "top" ? Style.popupArrowHeight : 0)
  bottomPadding: Style.marginS + (arrowEdge === "bottom" ? Style.popupArrowHeight : 0)
  leftPadding: Style.marginS + (arrowEdge === "left" ? Style.popupArrowHeight : 0)
  rightPadding: Style.marginS + (arrowEdge === "right" ? Style.popupArrowHeight : 0)

  background: NArrowRect {
    arrowEdge: root.arrowEdge
    arrowPosition: root.arrowPosition
    radius: root._radius
    fillColor: root._bgColor
    borderColor: root._borderColor
    borderWidth: Style.borderS
    shadow: root._shadow
  }

  contentItem: NListView {
    gradientColor: "transparent"
    id: listView
    implicitHeight: Math.max(contentHeight, root._rowHeight)
    spacing: 0
    interactive: contentHeight > root.height
    verticalPolicy: root.verticalPolicy
    horizontalPolicy: root.horizontalPolicy
    reserveScrollbarSpace: false
    model: root.filteredModel
    highlightFollowsCurrentItem: true
    focus: true

    // Keyboard navigation: Up/Down move, Enter triggers, Escape closes
    Keys.onUpPressed: {
      var n = listView.count;
      if (n === 0)
        return;
      var i = listView.currentIndex;
      var steps = 0;
      do {
        i = (i <= 0) ? n - 1 : i - 1;
        steps++;
      } while (steps < n && !_isActivatable(i))
      listView.currentIndex = i;
    }
    Keys.onDownPressed: {
      var n = listView.count;
      if (n === 0)
        return;
      var i = listView.currentIndex;
      var steps = 0;
      do {
        i = (i >= n - 1) ? 0 : i + 1;
        steps++;
      } while (steps < n && !_isActivatable(i))
      listView.currentIndex = i;
    }
    Keys.onReturnPressed: _activate(listView.currentIndex)
    Keys.onEnterPressed: _activate(listView.currentIndex)
    Keys.onEscapePressed: root.close()

    function _isSeparator(item) {
      return item && (item.separator === true || item.type === "separator" || item.action === "separator");
    }

    function _isActivatable(index) {
      var item = root.filteredModel[index];
      return item && !_isSeparator(item) && item.enabled !== false;
    }

    function _activate(index) {
      var item = root.filteredModel[index];
      if (_isActivatable(index)) {
        root.triggered(item.action || item.key || index.toString());
        root.close();
      }
    }

    delegate: ItemDelegate {
      id: menuItem
      width: listView.availableWidth
      height: listView._isSeparator(modelData) ? Style.marginS : root._rowHeight
      enabled: !listView._isSeparator(modelData) && modelData.enabled !== false
      highlighted: listView.currentIndex === index && menuItem.enabled

      // Store reference to the popup
      property var popup: root

      background: Item {
        // Separator: 6px row with the DDE two-line groove (dark over light, inset 4)
        Rectangle {
          visible: listView._isSeparator(modelData)
          anchors.centerIn: parent
          width: parent.width - Style.margin2XS
          height: 1
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

        // Full-row accent hover, no radius (menu corners clip it)
        Rectangle {
          visible: !listView._isSeparator(modelData)
          anchors.fill: parent
          color: menuItem.highlighted || (menuItem.hovered && menuItem.enabled) ? Color.accent : "transparent"
          radius: 0

          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }
        }
      }

      contentItem: RowLayout {
        spacing: Style.marginS
        visible: !listView._isSeparator(modelData)

        // Optional icon
        NIcon {
          visible: modelData.icon !== undefined
          icon: modelData.icon || ""
          pointSize: Style.fontSizeM
          color: !menuItem.enabled ? root._disabledColor : (menuItem.highlighted || menuItem.hovered) ? Color.onAccent : root._textColor
          Layout.leftMargin: root.itemPadding

          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }
        }

        NText {
          text: modelData.label || modelData.text || ""
          pointSize: Style.fontSizeM
          color: !menuItem.enabled ? root._disabledColor : (menuItem.highlighted || menuItem.hovered) ? Color.onAccent : root._textColor
          verticalAlignment: Text.AlignVCenter
          Layout.fillWidth: true
          Layout.leftMargin: modelData.icon === undefined ? root.itemPadding : 0

          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }
        }

        // Check mark / submenu chevron, 12px on the right
        NIcon {
          visible: modelData.checked === true || modelData.hasSubmenu === true
          icon: modelData.hasSubmenu === true ? "chevron-right" : "check"
          pointSize: Style.fontSizeXL
          color: !menuItem.enabled ? root._disabledColor : (menuItem.highlighted || menuItem.hovered) ? Color.onAccent : Color.accent
          Layout.rightMargin: root.itemPadding
        }
      }

      onClicked: {
        if (enabled) {
          popup.triggered(modelData.action || modelData.key || index.toString());
          popup.close();
        }
      }
    }
  }

  // Helper function to open at mouse position
  function openAt(x, y) {
    if (root.parent) {
      var menuWidth = root.width;
      var itemCount = root.filteredModel.length;
      var menuHeight = Math.max(itemCount * root._rowHeight, root._rowHeight) + root.topPadding + root.bottomPadding;
      var constraint = root.constrainTo || root._detectedConstraint;
      if (constraint) {
        var tl = constraint.mapToItem(root.parent, 0, 0);
        x = Math.max(tl.x, Math.min(x, tl.x + constraint.width - menuWidth));
        y = Math.max(tl.y, Math.min(y, tl.y + constraint.height - menuHeight));
      } else {
        x = Math.max(0, Math.min(x, root.parent.width - menuWidth));
        y = Math.max(0, Math.min(y, root.parent.height - menuHeight));
      }
    }
    root.x = x;
    root.y = y;
    root.open();
  }

  // Helper function to open at item
  function openAtItem(item, mouseX, mouseY) {
    if (!root.constrainTo) {
      root._detectedConstraint = null;
      var p = item;
      while (p && p !== root.parent) {
        if (p.clip && p.width > 0 && p.height > 0) {
          root._detectedConstraint = p;
          break;
        }
        p = p.parent;
      }
    }
    var pos = item.mapToItem(root.parent, mouseX || 0, mouseY || 0);
    openAt(pos.x, pos.y);
  }
}
