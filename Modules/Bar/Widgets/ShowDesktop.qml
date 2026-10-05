import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

// DDE efficient-mode show-desktop strip: a thin bar at the far end of the
// taskbar. Click shows the desktop (or toggles the compositor overview when
// the backend has no show-desktop action); if neither exists the widget
// hides itself.
Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)

  // 10 px strip along the bar's long axis plus a 1 px gap before it
  readonly property int stripThickness: 10
  readonly property int stripGap: 1
  // The strip keeps its full 10 px thickness but is inset 1 px on both sides
  // of the cross axis so it never touches the taskbar's outer edges
  // (gxde-dock showdesktopitem.cpp:77-86 marginsRemoved; same rule as the
  // efficient app-item fill in Taskbar.qml)
  readonly property int crossInset: 1

  implicitWidth: isVertical ? barHeight : stripThickness + stripGap
  implicitHeight: isVertical ? stripThickness + stripGap : barHeight

  // The widget hides itself when the backend cannot show the desktop or toggle an overview
  property bool hidden: false
  visible: !hidden

  function backendSupportsAction() {
    var backend = CompositorService.backend;
    return backend && (backend.toggleShowDesktop || backend.toggleOverview);
  }

  Component.onCompleted: {
    if (!backendSupportsAction())
      root.hidden = true;
  }

  Connections {
    target: CompositorService
    function onBackendChanged() {
      root.hidden = !root.backendSupportsAction();
    }
  }

  Rectangle {
    id: strip
    x: root.isVertical ? root.crossInset : root.stripGap
    y: root.isVertical ? root.stripGap : root.crossInset
    width: root.isVertical ? Math.max(0, parent.width - root.crossInset * 2) : root.stripThickness
    height: root.isVertical ? root.stripThickness : Math.max(0, parent.height - root.crossInset * 2)
    color: mouseArea.pressed ? Color.accent : (mouseArea.containsMouse ? Color.overlay("strong") : Color.overlay("hover"))

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    onEntered: TooltipService.show(strip, I18n.tr("tooltips.show-desktop"), BarService.getTooltipDirection(root.screen?.name))
    onExited: TooltipService.hide()
    onClicked: {
      TooltipService.hide();
      if (!CompositorService.toggleShowDesktop())
        root.hidden = true;
    }
  }
}
