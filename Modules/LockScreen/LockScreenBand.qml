import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.SessionMenu
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

// DDE lock screen bottom band (DESIGN §3.9, dde-lock lockframe.cpp + controlwidget.cpp).
// Owns the clock column on the left and the control row on the right inside a
// single 132 px band with 33 px top/bottom margins. The password block lives in
// LockScreenPanel, vertically centred above this band.
Item {
  id: root

  // Battery state comes from the owning lock screen so this band stays a pure
  // layout component (LockScreen.qml owns the battery probe).
  required property var batteryIndicator

  // --- DDE geometry ------------------------------------------------------
  // lockframe.cpp: 132 px band ending 33 px above the screen bottom.
  // timewidget.cpp: clock 48 px from the left edge. controlwidget.cpp: control
  // row 60 px trailing, 26 px between buttons.
  readonly property int bandHeight: Math.round(132 * Style.uiScaleRatio)
  readonly property int bandEdgeMargin: Math.round(33 * Style.uiScaleRatio)
  readonly property int clockLeftMargin: Math.round(48 * Style.uiScaleRatio)
  readonly property int controlTrailingMargin: Math.round(60 * Style.uiScaleRatio)
  readonly property int controlSpacing: Math.round(26 * Style.uiScaleRatio)
  readonly property int buttonSize: Math.round(36 * Style.uiScaleRatio)

  // The power button opens the DDE shutdown row; Esc closes it again.
  property bool powerRowOpen: false

  readonly property string ddeWidgetIcons: Quickshell.shellDir + "/Assets/DDE/gxde-session-ui/widgets/img/"
  readonly property bool switchUserAvailable: actions.switchUserAvailable

  ShutdownActions {
    id: actions
  }

  anchors.left: parent.left
  anchors.right: parent.right
  anchors.bottom: parent.bottom
  height: bandHeight

  // ---- clock column, bottom-left -----------------------------------------
  LockScreenHeader {
    id: clockColumn
    anchors.left: parent.left
    anchors.leftMargin: clockLeftMargin
    anchors.bottom: parent.bottom
    anchors.bottomMargin: bandEdgeMargin
  }

  // ---- control row, bottom-right ------------------------------------------
  // DDE order (controlwidget.cpp:59-69): media controls, then switch user, then
  // power as the right-most button; 26 px between them, 60 px trailing.
  Row {
    id: controlRow
    anchors.right: parent.right
    anchors.rightMargin: controlTrailingMargin
    anchors.bottom: parent.bottom
    anchors.bottomMargin: bandEdgeMargin
    spacing: controlSpacing

    // Optional MPRIS media controls — only when enabled and a player exists
    Loader {
      anchors.verticalCenter: parent.verticalCenter
      active: Settings.data.general.enableLockScreenMediaControls && MediaService.currentPlayer !== null
      sourceComponent: MediaControlsLayout {}
    }

    // DDEImageButton with the original artwork (controlwidget.cpp:59-62).
    // Hidden when the compositor cannot switch users — nosDshell has no such action.
    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: root.switchUserAvailable ? buttonSize : 0
      visible: root.switchUserAvailable

      BottomActionButton {
        id: switchUserButton
        anchors.fill: parent
        artworkStem: root.ddeWidgetIcons + "bottom_actions/userswitch"
        tooltipText: I18n.tr("session-menu.switch-user")
        onClicked: actions.execute("switchUser")
      }
    }

    // DDEImageButton with the original artwork (controlwidget.cpp:63-66).
    // Opens the dde-shutdown button row inside the lock screen (DESIGN §3.9).
    BottomActionButton {
      id: powerButton
      anchors.verticalCenter: parent.verticalCenter
      artworkStem: root.ddeWidgetIcons + "bottom_actions/shutdown"
      tooltipText: I18n.tr("common.shutdown")
      onClicked: root.powerRowOpen = !root.powerRowOpen
    }
  }

  // Keyboard-layout switching is omitted on purpose: KeyboardLayoutService only
  // reports the current layout (already shown by the panel) and exposes no
  // switch API, so the button would be a dead control.

  // Weather / battery are Noctalia extras that DESIGN §3.9's last line says to
  // keep off by default. They had no per-user toggle, so rather than ship an
  // always-on element (or add a new setting outside this task's file scope) they
  // are gone from the band; the launcher and control center still show them.

  // --- panel pieces -------------------------------------------------------

  // DDEImageButton (session-widgets/dimagebutton.cpp + controlwidget.cpp): 36 px
  // circle, translucent white plate that deepens on hover, and the original
  // normal / hover / press SVG swapped in — no tinting or dimming of the glyph.
  component BottomActionButton: Rectangle {
    id: actionButton

    // Path prefix without the state suffix, e.g. ".../bottom_actions/shutdown"
    property string artworkStem: ""
    property string tooltipText: ""
    property bool pressed: false

    signal clicked

    readonly property bool hovered: area.containsMouse && !pressed
    readonly property string artworkState: pressed ? "press" : (hovered ? "hover" : "normal")

    width: root.buttonSize
    height: width
    radius: width / 2
    color: pressed ? Qt.alpha("white", 0.3) : (hovered ? Qt.alpha("white", 0.2) : Qt.alpha("white", 0.12))

    Image {
      anchors.centerIn: parent
      width: Math.round(parent.width * 2 / 3)
      height: width
      source: actionButton.artworkStem + "_" + actionButton.artworkState + ".svg"
      sourceSize.width: width
      sourceSize.height: height
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
      cache: true
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: actionButton.pressed = true
      onReleased: actionButton.pressed = false
      onExited: actionButton.pressed = false
      onEntered: {
        if (actionButton.tooltipText) {
          TooltipService.show(actionButton, actionButton.tooltipText, "bottom");
        }
      }
      onClicked: actionButton.clicked()
    }
  }

  component MediaControlsLayout: Row {
    spacing: controlSpacing

    NIconButton {
      icon: "media-previous"
      tooltipText: I18n.tr("common.previous")
      baseSize: buttonSize
      colorBg: Qt.alpha("white", 0.12)
      colorFg: "white"
      colorBgHover: Qt.alpha("white", 0.2)
      onClicked: MediaService.canGoPrevious && MediaService.previous()
    }

    NIconButton {
      icon: MediaService.isPlaying ? "media-pause" : "media-play"
      tooltipText: MediaService.isPlaying ? I18n.tr("common.pause") : I18n.tr("common.play")
      baseSize: buttonSize
      colorBg: Qt.alpha("white", 0.12)
      colorFg: "white"
      colorBgHover: Qt.alpha("white", 0.2)
      onClicked: MediaService.playPause()
    }

    NIconButton {
      icon: "media-next"
      tooltipText: I18n.tr("common.next")
      baseSize: buttonSize
      colorBg: Qt.alpha("white", 0.12)
      colorFg: "white"
      colorBgHover: Qt.alpha("white", 0.2)
      onClicked: MediaService.canGoNext && MediaService.next()
    }
  }
}
