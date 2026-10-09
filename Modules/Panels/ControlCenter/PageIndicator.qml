import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

/**
* PageIndicator - quick-control page switcher (DESIGN §3.5.2).
*
* Height 40 with prev/next chevrons and dots (current white@0.8, others
* white@0.3). Mouse wheel switches pages with a 200 ms debounce
* (gxde-control-center indicatorwidget.cpp:68-74).
*/
Item {
  id: root

  property int pageCount: 1
  property int currentPage: 0

  implicitHeight: Style.pageIndicatorHeight

  signal nextRequested
  signal previousRequested

  function switchPage(delta) {
    if (wheelDebounce.restartIfActive())
      return;
    if (delta > 0)
      nextRequested();
    else
      previousRequested();
  }

  Timer {
    id: wheelDebounce
    interval: Style.pageSwitchDebounce
    repeat: false

    // Returns true when the event is swallowed by the debounce window.
    // A restart is enough: the timer is single-shot and non-repeating.
    // Declared inside the Timer so wheelDebounce.restartIfActive() resolves —
    // at root scope the callers threw TypeError and never emitted the signal.
    function restartIfActive() {
      if (running) {
        restart();
        return true;
      }
      restart();
      return false;
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
               const delta = wheel.angleDelta.y || wheel.angleDelta.x;
               if (delta !== 0)
               root.switchPage(delta > 0 ? 1 : -1);
             }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: Style.marginM

    NIconButtonHot {
      id: prevButton
      icon: "chevron-left"
      baseSize: Style.baseWidgetSize * 0.8
      applyUiScale: false
      visible: root.pageCount > 1
      colorFg: Color.onShellSecondary
      colorBg: "transparent"
      colorBgHover: Color.overlay("hover")
      colorFgHover: Color.onShell
      onClicked: {
        wheelDebounce.restartIfActive();
        root.previousRequested();
      }
    }

    Row {
      spacing: Style.marginS
      Layout.alignment: Qt.AlignVCenter

      Repeater {
        model: Math.max(1, root.pageCount)

        delegate: Rectangle {
          required property int index
          readonly property bool active: root.currentPage === index
          width: 8
          height: 8
          radius: 4
          color: active ? Qt.rgba(1, 1, 1, Style.pageDotCurrent) : Qt.rgba(1, 1, 1, Style.pageDotOther)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    NIconButtonHot {
      id: nextButton
      icon: "chevron-right"
      baseSize: Style.baseWidgetSize * 0.8
      applyUiScale: false
      visible: root.pageCount > 1
      colorFg: Color.onShellSecondary
      colorBg: "transparent"
      colorBgHover: Color.overlay("hover")
      colorFgHover: Color.onShell
      onClicked: {
        wheelDebounce.restartIfActive();
        root.nextRequested();
      }
    }
  }
}
