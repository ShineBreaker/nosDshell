import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

Item {
  id: root

  // Public properties
  property string text: ""
  property string icon: ""
  property var tooltipText
  property color backgroundColor: Colors.overlay("strong")
  property color textColor: Colors.onShell
  property color hoverColor: Colors.overlay("press")
  property color textHoverColor: Colors.onShell
  property real fontSize: Style.fontSizeM
  property int fontWeight: Style.fontWeightMedium
  property real iconSize: Style.fontSizeL
  // Kept for API compatibility: DDE has no outlined variant, so `outlined`
  // renders exactly like the normal RoundedButton.
  property bool outlined: false
  property int horizontalAlignment: Qt.AlignHCenter
  // DDE RoundedButton (DESIGN §3.5.4): a 15 px capsule — the second of the two
  // places a pill is allowed — filled white x 0.2, white x 0.5 on hover,
  // accent while pressed.
  property real buttonRadius: Style.radiusPill
  // Recommended action: the label turns accent. Existing callers get this for
  // free by passing `backgroundColor: Colors.mPrimary`; setting `primary`
  // directly is the explicit form.
  property bool primary: false

  // Signals
  signal clicked
  signal rightClicked
  signal middleClicked
  signal entered
  signal exited

  // Internal properties
  property bool hovered: false
  readonly property bool pressed: mouseArea.pressed
  // Callers that pass the accent color as background get the "recommended" look (DESIGN §3.5.4)
  readonly property bool isPrimary: root.primary || Qt.colorEqual(root.backgroundColor, Colors.mPrimary)
  readonly property color contentColor: {
    if (!root.enabled) {
      return Colors.onShellTertiary;
    }
    if (root.pressed) {
      return Colors.mOnPrimary;
    }
    if (root.isPrimary) {
      return Colors.accent;
    }
    if (root.hovered) {
      return root.textHoverColor;
    }
    return root.textColor;
  }

  // Dimensions - include margin so border renders cleanly at fractional scales
  implicitWidth: bg.implicitWidth + 2 * Style.borderS
  implicitHeight: bg.implicitHeight + 2 * Style.borderS

  opacity: enabled ? 1.0 : 0.6

  NPressScale {
    id: press
    pressed: root.pressed && root.enabled
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    anchors.margins: Style.borderS
    scale: press.value

    implicitWidth: contentRow.implicitWidth + (root.fontSize * 2)
    implicitHeight: contentRow.implicitHeight + (root.fontSize)

    radius: root.buttonRadius
    color: {
      if (!root.enabled)
        return Colors.overlay("idle");
      if (root.pressed)
        return Colors.accent;
      if (root.hovered)
        return root.hoverColor;
      if (root.isPrimary)
        return Colors.overlay("strong");
      return root.backgroundColor;
    }

    Behavior on color {
      enabled: !Colors.isTransitioning
      NColorAnim {
        duration: Style.motionPointer
        curve: "swift"
      }
    }

    // Content
    RowLayout {
      id: contentRow
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: root.horizontalAlignment === Qt.AlignLeft ? parent.left : undefined
      anchors.horizontalCenter: root.horizontalAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
      anchors.leftMargin: root.horizontalAlignment === Qt.AlignLeft ? Style.marginL : 0
      spacing: Style.marginXS

      // Icon (optional)
      NIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.icon !== ""
        icon: root.icon
        pointSize: root.iconSize
        color: root.contentColor

        Behavior on color {
          enabled: !Colors.isTransitioning
          NColorAnim {
            duration: Style.motionPointer
            curve: "swift"
          }
        }
      }

      // Text
      NText {
        Layout.alignment: Qt.AlignVCenter
        visible: root.text !== ""
        text: root.text
        pointSize: root.fontSize
        font.weight: root.fontWeight
        color: root.contentColor
        autoDim: false

        Behavior on color {
          enabled: !Colors.isTransitioning
          NColorAnim {
            duration: Style.motionPointer
            curve: "swift"
          }
        }
      }
    }

    // Mouse interaction
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      enabled: root.enabled
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

      onEntered: {
        root.hovered = root.enabled ? true : false;
        root.entered();
        if (root.hovered && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.show(root, root.tooltipText);
        }
      }
      onExited: {
        root.hovered = false;
        root.exited();
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
      onPressed: mouse => {
                   if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
                     TooltipService.hide();
                   }
                   if (mouse.button === Qt.LeftButton) {
                     root.clicked();
                   } else if (mouse.button == Qt.RightButton) {
                     root.rightClicked();
                   } else if (mouse.button == Qt.MiddleButton) {
                     root.middleClicked();
                   }
                 }

      onCanceled: {
        root.hovered = false;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }
  }
}
