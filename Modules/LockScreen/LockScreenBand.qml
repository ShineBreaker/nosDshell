import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Services.Media
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

  // Weather + battery live to the right of the clock as onShellSecondary text
  // (DESIGN §3.9, brief §2 Noctalia extras), so the auth block keeps its focus.
  Row {
    anchors.left: clockColumn.right
    anchors.leftMargin: controlSpacing * 2
    anchors.bottom: parent.bottom
    anchors.bottomMargin: bandEdgeMargin + Style.marginM
    spacing: controlSpacing
    visible: Settings.data.location.weatherEnabled || batteryIndicator.isReady

    NText {
      anchors.verticalCenter: parent.verticalCenter
      text: LocationService.data.weather?.current?.temperature ? Math.round(Settings.data.location.useFahrenheit ? LocationService.celsiusToFahrenheit(LocationService.data.weather.current.temperature) : LocationService.data.weather.current.temperature) + "°" : ""
      color: Color.onShellSecondary
      pointSize: Style.fontSizeM
      visible: text.length > 0 && Settings.data.location.weatherEnabled
    }

    NText {
      anchors.verticalCenter: parent.verticalCenter
      text: batteryIndicator.isReady ? Math.round(batteryIndicator.percent) + "%" : ""
      color: Color.onShellSecondary
      pointSize: Style.fontSizeM
      visible: text.length > 0
    }
  }

  // ---- control row, bottom-right ------------------------------------------
  Row {
    id: controlRow
    anchors.right: parent.right
    anchors.rightMargin: controlTrailingMargin
    anchors.bottom: parent.bottom
    anchors.bottomMargin: bandEdgeMargin
    spacing: controlSpacing

    // Optional MPRIS media controls (brief §2, controlwidget.cpp)
    Loader {
      anchors.verticalCenter: parent.verticalCenter
      active: Settings.data.general.enableLockScreenMediaControls
      sourceComponent: MediaControlsLayout {}
    }

    NIconButton {
      icon: "power"
      tooltipText: I18n.tr("common.shutdown")
      baseSize: buttonSize
      colorBg: Qt.alpha("white", 0.12)
      colorFg: "white"
      colorBgHover: Qt.alpha("white", 0.2)
      onClicked: root.powerRowOpen = !root.powerRowOpen
    }
  }

  // Keyboard-layout and switch-user buttons are omitted on purpose: the shell
  // exposes no layout-switching API (KeyboardLayoutService only reports the
  // current layout, already shown by the panel) and CompositorService has no
  // switch-user action, so both would be dead controls.

  // --- panel pieces -------------------------------------------------------

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
