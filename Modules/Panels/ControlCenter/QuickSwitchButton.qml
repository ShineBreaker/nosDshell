import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

/**
* QuickSwitchButton - 70x72 quick switch (DESIGN §3.5.2).
*
* Icon 24 px, bottom-aligned 32 px above the bottom (gxde-control-center
* quickswitchbutton.cpp:41-46), with a one-line name 12 px above the bottom
* so an icon-only cell is still recognisable without hovering. The name comes
* from ControlCenterWidgetRegistry.widgetDisplayName — the same API the
* settings → control center shortcut list uses, so both surfaces call a
* switch by the same word (plugin widgets resolve to their manifest name).
* The tooltip still carries the widget's dynamic description (e.g. the
* network currently connected to), which the name cannot.
*
* On state draws a radiusPopup block with a 5 px bottom margin behind the
* glyph; hover is overlay("hover").
*
* The switch drives the same registry widget as Noctalia's shortcuts card, so
* all existing shortcut behaviour (left/right/middle click, on-state logic)
* is preserved; only the visuals are DDE-styled.
*/
Item {
  id: root

  property string widgetId: ""
  property var widgetScreen: null
  property var widgetProps: null

  readonly property var widgetMeta: ControlCenterWidgetRegistry.widgetMetadata[widgetId] ?? {}

  signal clicked
  signal rightClicked
  signal middleClicked

  width: Style.quickSwitchWidth
  height: Style.quickSwitchHeight

  ControlCenterWidgetLoader {
    id: widgetLoader
    anchors.fill: parent
    widgetId: root.widgetId
    widgetScreen: root.widgetScreen
    widgetProps: root.widgetProps ?? {}
    visible: false
  }

  // On state: the registry widget decides (hot / checkable widgets toggle on click)
  readonly property bool hot: {
    const item = widgetLoader.loadedItem;
    if (!item)
      return false;
    if (item.hot !== undefined)
      return item.hot;
    if (item.checked !== undefined)
      return item.checked;
    return false;
  }

  readonly property var tooltipText: {
    const item = widgetLoader.loadedItem;
    if (item && item.tooltipText !== undefined)
      return item.tooltipText;
    return "";
  }

  function forward(button) {
    const item = widgetLoader.loadedItem;
    if (!item)
      return;
    if (item[button] !== undefined && typeof item[button] === "function")
      item[button]();
  }

  // On-state block: radiusPopup, 5 px above the bottom edge. Button-class
  // colour feedback, so hover <-> on animates (DESIGN §1.7).
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.quickSwitchBlockBottomMargin
    height: parent.height - Style.quickSwitchBlockBottomMargin
    radius: Style.radiusPopup
    color: root.hot ? Colors.overlay("strong") : (hoverArea.containsMouse ? Colors.overlay("hover") : "transparent")
    visible: root.hot || hoverArea.containsMouse

    Behavior on color {
      enabled: !Colors.isTransitioning
      NColorAnim {
        duration: Style.motionPointer
        curve: "swift"
      }
    }
  }

  NIcon {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.quickSwitchIconBottomMargin
    // The registry widget carries the glyph; metadata only covers CustomButton
    icon: {
      const item = widgetLoader.loadedItem;
      return (item && item.icon !== undefined) ? item.icon : (widgetMeta.icon ?? "");
    }
    pointSize: Style.quickSwitchIconSize
    applyUiScale: false
    color: root.hot ? Colors.onShell : Colors.onShellSecondary
  }

  // Name under the icon — the same word the settings shortcut list shows.
  Text {
    anchors.left: parent.left
    anchors.leftMargin: Style.quickSwitchLabelSideMargin
    anchors.right: parent.right
    anchors.rightMargin: Style.quickSwitchLabelSideMargin
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.quickSwitchLabelBottomMargin
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    maximumLineCount: 1
    font.pixelSize: Math.round(Style.fontSizeXS * Style.uiScaleRatio)
    color: root.hot ? Colors.onShell : Colors.onShellSecondary
    text: ControlCenterWidgetRegistry.widgetDisplayName(root.widgetId)
  }

  // Button class (DESIGN §1.11): the whole cell squishes while pressed
  scale: press.value
  NPressScale {
    id: press
    pressed: hoverArea.pressed
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      if (root.tooltipText)
        TooltipService.show(parent, root.tooltipText);
    }
    onExited: TooltipService.hide()
    onPressed: TooltipService.hide()

    onClicked: mouse => {
                 if (mouse.button === Qt.LeftButton)
                 root.forward("clicked");
                 else if (mouse.button === Qt.RightButton)
                 root.forward("rightClicked");
                 else if (mouse.button === Qt.MiddleButton)
                 root.forward("middleClicked");
               }
  }
}
