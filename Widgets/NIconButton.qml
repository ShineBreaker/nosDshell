import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property real baseSize: Style.baseWidgetSize
  // Painted tile size (-1 = same as buttonSize). The dock's fashion plugin
  // buttons are a smaller rounded square inside the item slot.
  property real bgSize: -1
  property bool applyUiScale: true

  property string icon
  // Themed icon path (e.g. *-symbolic); takes precedence over the glyph icon
  property string iconSource: ""
  // When true (default), iconSource is recolored to a flat colorFg silhouette;
  // false renders the themed icon as-is (fashion dock uses full-color icons).
  property bool recolorIcon: true
  // Glyph/icon size as a fraction of buttonSize (DDE launcher uses 0.7)
  property real iconRatio: 0.48
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool allowClickWhenDisabled: false
  property bool handleWheel: false
  property bool hovering: false

  property bool checked: false

  property color colorBg: "transparent"
  property color colorFg: Color.onShellSecondary
  property color colorBgHover: Color.overlay("hover")
  property color colorFgHover: Color.onShell
  property color colorBorder: "transparent"
  property color colorBorderHover: "transparent"
  property real customRadius: -1 // -1 means use default (radiusRow), otherwise use this value

  // Expose border properties for backwards compatibility (aliases to visualButton)
  property alias border: visualButton.border
  property alias radius: visualButton.radius
  property alias color: visualButton.color

  signal entered
  signal exited
  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheel(int angleDelta)

  // Calculate button size based on settings
  readonly property real buttonSize: applyUiScale ? Style.toOdd(baseSize * Style.uiScaleRatio) : Style.toOdd(baseSize)

  // Size: use implicit width/height which layout can override
  // BarWidgetLoader sets explicit width/height to extend click area
  implicitWidth: buttonSize
  implicitHeight: buttonSize

  opacity: enabled ? 1.0 : 0.6

  // Visual button - stays at buttonSize, centered in parent (or the smaller
  // bgSize tile when set, e.g. the fashion plugin chip)
  Rectangle {
    id: visualButton
    width: root.bgSize >= 0 ? Math.round(root.bgSize * Style.uiScaleRatio) : root.buttonSize
    height: width
    anchors.centerIn: parent

    readonly property bool pressed: mouseArea.pressed

    color: {
      if (root.enabled && root.checked)
        return Color.overlay("checked");
      return root.enabled && root.hovering ? colorBgHover : colorBg;
    }
    radius: Math.min((customRadius >= 0 ? customRadius : Style.radiusRow), width / 2)
    border.color: root.enabled && root.hovering ? colorBorderHover : colorBorder
    border.width: Style.borderS

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }

    IconImage {
      visible: root.iconSource !== ""
      source: root.iconSource
      implicitSize: Math.max(1, Math.round(visualButton.width * root.iconRatio))
      x: Style.pixelAlignCenter(visualButton.width, width)
      y: Style.pixelAlignCenter(visualButton.height, height)

      // Themed *-symbolic icons are recolored to the foreground color
      layer.enabled: root.iconSource !== "" && root.recolorIcon
      layer.effect: ShaderEffect {
        property color targetColor: root.enabled && visualButton.pressed ? Color.accent : (root.enabled && root.hovering ? colorFgHover : colorFg)
        property real colorizeMode: 3.0
        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
      }
    }

    NIcon {
      visible: root.iconSource === ""
      icon: root.icon
      pointSize: Style.toOdd(visualButton.width * root.iconRatio)
      applyUiScale: root.applyUiScale
      color: root.enabled && visualButton.pressed ? Color.accent : (root.enabled && root.hovering ? colorFgHover : colorFg)
      // Pixel-perfect centering
      x: Style.pixelAlignCenter(visualButton.width, width)
      y: Style.pixelAlignCenter(visualButton.height, contentHeight)

      Behavior on color {
        enabled: !Color.isTransitioning
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  // MouseArea fills root (extends beyond visual button for bar click area)
  MouseArea {
    id: mouseArea
    // Always enabled to allow hover/tooltip even when the button is disabled
    enabled: true
    anchors.fill: parent
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    onEntered: {
      hovering = root.enabled ? true : false;
      if (hovering && tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.show(root, tooltipText, tooltipDirection);
      }
      root.entered();
    }
    onExited: {
      hovering = false;
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide(root);
      }
      root.exited();
    }
    onClicked: mouse => {
                 if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
                   TooltipService.hide(root);
                 }
                 if (!root.enabled && !allowClickWhenDisabled) {
                   return;
                 }
                 if (mouse.button === Qt.LeftButton) {
                   root.clicked();
                 } else if (mouse.button === Qt.RightButton) {
                   root.rightClicked();
                 } else if (mouse.button === Qt.MiddleButton) {
                   root.middleClicked();
                 }
               }
    onWheel: wheel => {
               if (root.handleWheel) {
                 root.wheel(wheel.angleDelta.y);
               }
               wheel.accepted = false;
             }
  }
}
