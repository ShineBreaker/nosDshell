import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

// DDE trash plugin: user-trash / user-trash-full themed icon reflecting
// $XDG_DATA_HOME/Trash/files, left click opens trash:///, context menu
// offers Open and a confirmed "Empty trash" (gio trash --empty).
NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen ? screen.name : ""
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // "fashion" = DDE fashion dock presentation (square item, icon at 0.8)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool onShellSurface: efficientMode || fashionMode

  readonly property string trashFilesDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Trash/files"
  property bool isFull: false

  baseSize: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screenName))
  applyUiScale: false
  customRadius: onShellSurface ? Style.radiusPopup : Style.radiusL
  icon: isFull ? "trash-x" : "trash"
  iconSource: fashionMode ? ThemeIcons.fashionFor(isFull ? "user-trash-full" : "user-trash") : (efficientMode ? ThemeIcons.symbolicOnly(isFull ? "user-trash-full" : "user-trash") : "")
  recolorIcon: efficientMode || (fashionMode && iconSource.indexOf("-symbolic") >= 0)
  iconRatio: fashionMode ? 0.8 : (efficientMode ? 16.0 / baseSize : 0.48)
  colorBg: fashionMode ? "transparent" : Style.capsuleColor
  colorFg: onShellSurface ? Color.onShell : Color.mOnSurface
  border.color: Style.capsuleBorderColor
  border.width: fashionMode ? 0 : Style.capsuleBorderWidth
  tooltipText: I18n.tr("tooltips.trash")
  tooltipDirection: BarService.getTooltipDirection(screenName)
  onClicked: root.openTrash()
  onRightClicked: PanelService.showContextMenu(contextMenu, root, screen)

  function openTrash() {
    Quickshell.execDetached(["xdg-open", "trash:///"]);
  }

  function refresh() {
    listProc.running = true;
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  Process {
    id: listProc
    command: ["ls", "-A", root.trashFilesDir]
    stdout: StdioCollector {
      onStreamFinished: root.isFull = this.text.trim() !== ""
    }
    onExited: (exitCode, exitStatus) => {
                // Missing trash directory just means the trash is empty
                if (exitCode !== 0)
                root.isFull = false;
              }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.open-trash"),
        "action": "open",
        "icon": "trash"
      },
      {
        "label": I18n.tr("actions.empty-trash"),
        "action": "empty-trash",
        "icon": "trash-x"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);
                   if (action === "open") {
                     root.openTrash();
                   } else if (action === "empty-trash") {
                     PanelService.showContextMenu(confirmMenu, root, screen);
                   }
                 }
  }

  // Confirmation step for the destructive action
  NPopupContextMenu {
    id: confirmMenu

    model: [
      {
        "label": I18n.tr("actions.confirm-empty-trash"),
        "action": "confirm-empty",
        "icon": "trash-x"
      },
      {
        "label": I18n.tr("common.cancel"),
        "action": "cancel",
        "icon": "x"
      },
    ]

    onTriggered: action => {
                   confirmMenu.close();
                   PanelService.closeContextMenu(screen);
                   if (action === "confirm-empty") {
                     Quickshell.execDetached(["gio", "trash", "--empty"]);
                     root.refresh();
                   }
                 }
  }
}
