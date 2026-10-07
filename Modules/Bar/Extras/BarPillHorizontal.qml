import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  required property ShellScreen screen

  property string icon: ""
  // Themed icon path (e.g. *-symbolic); takes precedence over the glyph icon
  property string iconSource: ""
  property string text: ""
  property string suffix: ""
  property var tooltipText
  property bool autoHide: false
  property bool forceOpen: false
  property bool forceClose: false
  property bool oppositeDirection: false
  property string iconPosition: ""
  property bool hovered: false
  // "fashion" = DDE fashion dock presentation: square item, icon only at 0.8,
  // full-color themed icon (symbolic variants are tinted onShell)
  property string dockPresentation: ""
  property color customBackgroundColor: "transparent"
  property color customTextIconColor: "transparent"
  property color customIconColor: "transparent"
  property color customTextColor: "transparent"

  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool collapseToIcon: fashionMode || (forceClose && !forceOpen)

  // Effective shown state (true if hovered/animated open or forced)
  readonly property bool revealed: !fashionMode && !forceClose && (forceOpen || showPill)
  readonly property bool hasIcon: root.icon !== "" || root.iconSource !== ""

  signal shown
  signal hidden
  signal entered
  signal exited
  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheel(int delta)

  // Internal state
  property bool showPill: false
  property bool shouldAnimateHide: false

  readonly property int pillHeight: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screen?.name))
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)
  readonly property int pillPaddingHorizontal: Math.round(pillHeight * 0.2)
  readonly property int pillOverlap: Math.round(pillHeight * 0.5)
  readonly property int pillMaxWidth: Math.max(1, Math.round(textItem.implicitWidth + pillPaddingHorizontal * 2 + pillOverlap))

  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"

  // Always prioritize hover color, then the custom one and finally the fallback color.
  // DDE plugin buttons: fashion draws a rounded "subtle" tile chip inside
  // the item slot; efficient is bare icon with an overlay("hover") hover fill
  // (gxde-dock pluginsitem.cpp paints no idle background).
  readonly property bool onShellSurface: efficientMode || fashionMode
  readonly property color bgColor: hovered ? (onShellSurface ? Color.overlay("hover") : Color.mHover) : (customBackgroundColor.a > 0) ? customBackgroundColor : (fashionMode ? Color.overlay("subtle") : (efficientMode ? "transparent" : Style.capsuleColor))
  readonly property color fgColor: onShellSurface ? Color.onShell : (hovered ? Color.mOnHover : (customTextIconColor.a > 0) ? customTextIconColor : Color.mOnSurface)
  readonly property color iconFgColor: onShellSurface ? Color.onShell : (hovered ? Color.mOnHover : (customIconColor.a > 0) ? customIconColor : (customTextIconColor.a > 0) ? customTextIconColor : Color.mOnSurface)
  readonly property color textFgColor: onShellSurface ? Color.onShell : (hovered ? Color.mOnHover : (customTextColor.a > 0) ? customTextColor : (customTextIconColor.a > 0) ? customTextIconColor : Color.mOnSurface)

  // Painted tile size: fashion is a 36px chip inside the 54px item slot
  // (same ratio as the tray pill); efficient covers the full 26px cell.
  readonly property real tileSize: fashionMode ? Math.round(pillHeight * 0.66) : pillHeight

  // DDE status icons are 16 px in both dock modes
  readonly property real iconSize: onShellSurface ? 16 : Style.toOdd(pillHeight * 0.48)

  // Content width calculation (for implicit sizing)
  readonly property real contentWidth: {
    if (collapseToIcon) {
      return hasIcon ? pillHeight : 0;
    }
    var overlap = hasIcon ? pillOverlap : 0;
    var baseWidth = hasIcon ? pillHeight : 0;
    return baseWidth + Math.max(0, pill.width - overlap);
  }

  // Fill parent to extend click area to full bar height
  // Visual content is centered vertically within
  anchors.fill: parent
  implicitWidth: contentWidth
  implicitHeight: pillHeight

  Connections {
    target: root
    function onTooltipTextChanged() {
      if (hovered) {
        TooltipService.updateText(root.tooltipText);
      }
    }
  }

  // Unified background for the entire pill area to avoid overlapping opacity
  Rectangle {
    id: pillBackground
    width: collapseToIcon ? tileSize : root.width
    height: tileSize
    // Fashion tile is a smaller chip centered in the item slot
    x: collapseToIcon ? Math.round((root.width - width) / 2) : 0
    // DDE plugin-item hover: rounded overlay sized to the widget's own content area
    radius: onShellSurface ? Style.radiusPopup : Style.radiusM
    color: root.bgColor
    anchors.verticalCenter: parent.verticalCenter
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: pill

    width: revealed ? pillMaxWidth : 1
    height: pillHeight

    x: {
      if (!hasIcon)
        return 0;
      // iconPosition takes precedence, fallback to oppositeDirection
      if (iconPosition === "right")
        return (iconCircle.x + iconCircle.width / 2) - width;
      if (iconPosition === "left")
        return (iconCircle.x + iconCircle.width / 2);
      return oppositeDirection ? (iconCircle.x + iconCircle.width / 2) : (iconCircle.x + iconCircle.width / 2) - width;
    }

    opacity: revealed ? Style.opacityFull : Style.opacityNone
    color: "transparent" // Make pill background transparent to avoid double opacity

    // iconPosition takes precedence, fallback to oppositeDirection
    topLeftRadius: iconPosition ? (iconPosition === "right" ? Style.radiusM : 0) : (oppositeDirection ? 0 : Style.radiusM)
    bottomLeftRadius: iconPosition ? (iconPosition === "right" ? Style.radiusM : 0) : (oppositeDirection ? 0 : Style.radiusM)
    topRightRadius: iconPosition ? (iconPosition === "right" ? 0 : Style.radiusM) : (oppositeDirection ? Style.radiusM : 0)
    bottomRightRadius: iconPosition ? (iconPosition === "right" ? 0 : Style.radiusM) : (oppositeDirection ? Style.radiusM : 0)
    anchors.verticalCenter: parent.verticalCenter

    NText {
      id: textItem
      anchors.verticalCenter: parent.verticalCenter
      x: {
        if (!hasIcon)
          return (parent.width - width) / 2;

        // Better text horizontal centering
        var centerX = (parent.width - width) / 2;
        // iconPosition takes precedence, fallback to oppositeDirection
        var offset;
        if (iconPosition === "right")
          offset = -Style.marginXS;
        else if (iconPosition === "left")
          offset = Style.marginXS;
        else
          offset = oppositeDirection ? Style.marginXS : -Style.marginXS;
        if (forceOpen) {
          // If its force open, the icon disc background is the same color as the bg pill move text slightly
          offset += iconPosition === "right" ? Style.marginXXS : (iconPosition === "left" ? -Style.marginXXS : oppositeDirection ? -Style.marginXXS : Style.marginXXS);
        }
        return centerX + offset;
      }
      text: root.text + root.suffix
      family: Settings.data.ui.fontFixed
      pointSize: root.barFontSize
      applyUiScale: false
      color: root.textFgColor
      visible: revealed
    }

    Behavior on width {
      enabled: showAnim.running || hideAnim.running
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on opacity {
      enabled: showAnim.running || hideAnim.running
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }
  }

  Rectangle {
    id: iconCircle
    width: hasIcon ? pillHeight : 0
    height: pillHeight
    radius: Math.min(Style.radiusL, width / 2)
    color: "transparent" // Make icon background transparent to avoid double opacity
    anchors.verticalCenter: parent.verticalCenter

    // iconPosition takes precedence, fallback to oppositeDirection
    x: iconPosition ? (iconPosition === "right" ? (parent.width - width) : 0) : (oppositeDirection ? 0 : (parent.width - width))

    IconImage {
      visible: root.iconSource !== ""
      source: root.iconSource
      implicitSize: root.iconSize
      x: (iconCircle.width - width) / 2
      y: (iconCircle.height - height) / 2

      // DDE plugin icons are monochrome white — recolor themed *-symbolic
      // icons to the on-shell foreground.
      layer.enabled: root.iconSource !== "" && root.onShellSurface
      layer.effect: ShaderEffect {
        property color targetColor: Color.onShell
        property real colorizeMode: 3.0
        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
      }
    }

    NIcon {
      visible: root.iconSource === ""
      icon: root.icon
      pointSize: iconSize
      applyUiScale: false
      color: root.iconFgColor
      // Center horizontally
      x: (iconCircle.width - width) / 2
      // Center vertically accounting for font metrics
      y: (iconCircle.height - height) / 2 + (height - contentHeight) / 2
    }
  }

  ParallelAnimation {
    id: showAnim
    running: false
    NumberAnimation {
      target: pill
      property: "width"
      from: 1
      to: pillMaxWidth
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: pill
      property: "opacity"
      from: 0
      to: 1
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
    onStarted: {
      showPill = true;
    }
    onStopped: {
      delayedHideAnim.start();
      root.shown();
    }
  }

  SequentialAnimation {
    id: delayedHideAnim
    running: false
    PauseAnimation {
      duration: 2500
    }
    ScriptAction {
      script: if (shouldAnimateHide) {
                hideAnim.start();
              }
    }
  }

  ParallelAnimation {
    id: hideAnim
    running: false
    NumberAnimation {
      target: pill
      property: "width"
      from: pillMaxWidth
      to: 1
      duration: Style.animationNormal
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: pill
      property: "opacity"
      from: 1
      to: 0
      duration: Style.animationFast
      easing.type: Easing.InCubic
    }
    onStopped: {
      showPill = false;
      shouldAnimateHide = false;
      root.hidden();
    }
  }

  Timer {
    id: showTimer
    interval: Style.pillDelay
    onTriggered: {
      if (!showPill) {
        showAnim.start();
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: root.clicked ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: {
      hovered = true;
      root.entered();
      TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screen?.name, root.fashionMode), root.onShellSurface ? Style.tooltipDelayDock : ((forceOpen || forceClose) ? Style.tooltipDelay : Style.tooltipDelayLong));
      if (forceClose) {
        return;
      }
      if (!forceOpen) {
        showDelayed();
      }
    }
    onExited: {
      hovered = false;
      root.exited();
      if (!forceOpen && !forceClose) {
        hide();
      }
      TooltipService.hide();
    }
    onClicked: mouse => {
                 TooltipService.hide();
                 if (mouse.button === Qt.LeftButton) {
                   root.clicked();
                 } else if (mouse.button === Qt.RightButton) {
                   root.rightClicked();
                 } else if (mouse.button === Qt.MiddleButton) {
                   root.middleClicked();
                 }
               }
    onWheel: wheel => root.wheel(wheel.angleDelta.y)
  }

  function show() {
    if (collapseToIcon || root.text.trim().length === 0)
      return;
    if (!showPill) {
      shouldAnimateHide = autoHide;
      showAnim.start();
    } else {
      hideAnim.stop();
      delayedHideAnim.restart();
    }
  }

  function hide() {
    if (collapseToIcon)
      return;
    if (forceOpen) {
      return;
    }
    if (showPill) {
      hideAnim.start();
    }
    showTimer.stop();
  }

  function showDelayed() {
    if (collapseToIcon || root.text.trim().length === 0)
      return;
    if (!showPill) {
      shouldAnimateHide = autoHide;
      showTimer.start();
    } else {
      hideAnim.stop();
      delayedHideAnim.restart();
    }
  }

  onForceOpenChanged: {
    if (forceOpen) {
      // Immediately lock open without animations
      showAnim.stop();
      hideAnim.stop();
      delayedHideAnim.stop();
      showPill = true;
    } else {
      hide();
    }
  }
}
