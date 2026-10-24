import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.Commons
import qs.Services.UI

Slider {
  id: root

  readonly property bool sliderActive: activeFocus || pressed
  property color fillColor: Colors.accent
  property bool snapAlways: true
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool hovering: false

  readonly property color effectiveFillColor: enabled ? fillColor : Colors.onShellTertiary

  // DSlider (DESIGN §3.5.4): 2px groove, 12px white knob, whole control >= 22px tall
  readonly property real knobDiameter: Math.max(4, Math.round(12 * Style.uiScaleRatio / 2) * 2)
  readonly property real trackHeight: Math.max(2, Math.round(2 * Style.uiScaleRatio))
  readonly property real trackRadius: trackHeight / 2

  padding: 0

  snapMode: snapAlways ? Slider.SnapAlways : Slider.SnapOnRelease
  implicitHeight: Math.max(Math.round(22 * Style.uiScaleRatio), Math.max(trackHeight, knobDiameter))

  background: Item {
    id: bgContainer
    x: root.leftPadding
    y: root.topPadding + Style.pixelAlignCenter(root.availableHeight, root.trackHeight)
    implicitWidth: Style.sliderWidth
    implicitHeight: root.trackHeight
    width: root.availableWidth
    height: root.trackHeight

    readonly property real fillWidth: root.visualPosition * width

    // Background track
    Shape {
      anchors.fill: parent
      visible: bgContainer.width > 0 && bgContainer.height > 0
      preferredRendererType: Shape.CurveRenderer
      asynchronous: true

      ShapePath {
        id: bgPath
        strokeColor: "transparent"
        strokeWidth: -1
        fillColor: Colors.overlay("strong")

        readonly property real w: bgContainer.width
        readonly property real h: bgContainer.height
        readonly property real r: root.trackRadius

        startX: r
        startY: 0

        PathLine {
          x: bgPath.w - bgPath.r
          y: 0
        }
        PathArc {
          x: bgPath.w
          y: bgPath.r
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
        PathLine {
          x: bgPath.w
          y: bgPath.h - bgPath.r
        }
        PathArc {
          x: bgPath.w - bgPath.r
          y: bgPath.h
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
        PathLine {
          x: bgPath.r
          y: bgPath.h
        }
        PathArc {
          x: 0
          y: bgPath.h - bgPath.r
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
        PathLine {
          x: 0
          y: bgPath.r
        }
        PathArc {
          x: bgPath.r
          y: 0
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
      }
    }

    // Active/filled track
    Shape {
      width: bgContainer.fillWidth
      height: bgContainer.height
      visible: bgContainer.fillWidth > 0 && bgContainer.height > 0
      preferredRendererType: Shape.CurveRenderer
      asynchronous: true
      clip: true

      ShapePath {
        id: fillPath
        strokeColor: "transparent"
        fillColor: root.effectiveFillColor

        readonly property real fullWidth: root.availableWidth
        readonly property real h: root.trackHeight
        readonly property real r: root.trackRadius

        startX: r
        startY: 0

        PathLine {
          x: fillPath.fullWidth - fillPath.r
          y: 0
        }
        PathArc {
          x: fillPath.fullWidth
          y: fillPath.r
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
        PathLine {
          x: fillPath.fullWidth
          y: fillPath.h - fillPath.r
        }
        PathArc {
          x: fillPath.fullWidth - fillPath.r
          y: fillPath.h
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
        PathLine {
          x: fillPath.r
          y: fillPath.h
        }
        PathArc {
          x: 0
          y: fillPath.h - fillPath.r
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
        PathLine {
          x: 0
          y: fillPath.r
        }
        PathArc {
          x: fillPath.r
          y: 0
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
      }
    }
  }

  handle: Item {
    implicitWidth: knobDiameter
    implicitHeight: knobDiameter
    x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      id: knob
      implicitWidth: knobDiameter
      implicitHeight: knobDiameter
      radius: width / 2
      color: Colors.knobFill
      border.color: Colors.knobBorder
      border.width: Style.borderS
      anchors.centerIn: parent
    }

    MouseArea {
      enabled: true
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      acceptedButtons: Qt.NoButton // Don't accept any mouse buttons - only hover
      propagateComposedEvents: true

      onEntered: {
        root.hovering = true;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.show(knob, root.tooltipText, root.tooltipDirection);
        }
      }

      onExited: {
        root.hovering = false;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }

    // Hide tooltip when slider is pressed (anywhere on the slider)
    Connections {
      target: root
      function onPressedChanged() {
        if (root.pressed && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }
  }
}
