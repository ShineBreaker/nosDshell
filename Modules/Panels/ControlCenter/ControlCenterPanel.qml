import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.ControlCenter
import qs.Services.Media
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterPanel - DDE 15 control center (DESIGN §3.5).
*
* Implemented as a SmartPanel variant (rather than a dedicated layer window):
* it keeps PanelService semantics — one open panel, the shared click-outside
* dimmer, Esc handling, blur regions and background/shadow rendering — while
* presenting the DDE frame: 408 px wide, full screen height, flush right edge,
* square corners, maskShell, left-side Style.shadowControlCenter, sliding in
* from the right with Style.motionEnter (OutCubic). Always on the right,
* regardless of controlCenter.position; with the taskbar on the right the frame
* sits on its inner side.
*/
SmartPanel {
  id: root

  // The DDE frame has no arrow and no grow animation of its own.
  arrowPopup: false

  // Present as a full-height edge sheet (DESIGN §3.5.1) with its own shadow.
  edgeSheet: true
  panelShadow: Style.shadowControlCenter

  // Which middle page the bell shows
  property bool notificationPage: false

  // Which module the middle area shows (null = home page, DESIGN §3.5.3)
  property var activeModule: null

  // Quick-control page requested from IPC (applied when the frame opens, or
  // immediately when it is already open)
  property string pendingQuickPage: ""

  // Module requested from IPC (applied when the frame opens)
  property var pendingModule: null
  property int pendingSubTab: -1

  // The settings view registers itself here: panelContent is a separate
  // Component scope, so ids inside it are invisible to root functions.
  property var _moduleView: null

  // Open the all-settings page scrolled to a module (DESIGN §3.5.3, from the
  // home grid, IPC "settings openTab", or the header settings button).
  // subTab scrolls to the matching tab section inside the module.
  function openModule(module, subTab) {
    if (!module)
      return;
    notificationPage = false;
    activeModule = module;
    pendingSubTab = (subTab === undefined || subTab === null) ? -1 : subTab;
    if (root._moduleView)
      root._moduleView.openModuleAt(module, pendingSubTab);
  }

  // Page state resets on close. This must live at the root: the closed signal
  // is emitted after isPanelOpen=false unloads panelContent, so a handler
  // inside the content would already be destroyed.
  onClosed: {
    MediaService.autoSwitchingPaused = false;
    notificationPage = false;
    activeModule = null;
    pendingQuickPage = "";
  }

  // Positioning: flush right edge, full height, square corners.
  panelAnchorRight: true
  panelAnchorVerticalCenter: false
  panelAnchorHorizontalCenter: false

  // Frame geometry: 408 wide, full screen height (frame.cpp:517-523).
  // controlCenter.position is inert (DESIGN §3.5.1): the frame is always on
  // the right, inset by the taskbar when that is on the right too.
  preferredWidth: Style.controlCenterWidth
  preferredHeight: root.screen?.height ?? 0

  panelBackgroundColor: Color.maskShell
  // The frame's own corners are square; PanelBackground needs state -1.
  panelContent: Item {
    id: frameContent
    anchors.fill: parent
    focus: true

    Component.onCompleted: root._moduleView = moduleView

    readonly property var contentPreferredWidth: undefined
    readonly property var contentPreferredHeight: undefined

    // Never attach the frame to the taskbar; SmartPanel's default attachment
    // math is tuned for popups, not a full-height edge sheet.
    readonly property bool allowAttach: false

    // Quick-control page selection, reached from the panel (IPC "quickPage")
    function openQuickPage(page) {
      quickControl.openPage(page);
    }

    Connections {
      target: root
      function onOpened() {
        Qt.callLater(() => frameContent.forceActiveFocus());
        MediaService.autoSwitchingPaused = true;
        // A module requested while closed (IPC) is applied on open.
        if (root.pendingModule) {
          root.openModule(root.pendingModule, root.pendingSubTab);
          root.pendingModule = null;
          root.pendingSubTab = -1;
        }
      }
      function onNotificationPageChanged() {
        if (root.notificationPage)
          root.activeModule = null;
      }
    }

    // Esc closes the control center (DESIGN §3.5.1)
    function onEscapePressed() {
      root.close();
    }

    // ---- content ----
    ColumnLayout {
      id: frame
      anchors.fill: parent
      spacing: 0

      // 1. Header (140 px); hidden while the all-settings page is open
      // so the two settings columns take the full frame height (§3.5.3).
      ControlCenterHeader {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.controlCenterHeaderHeight
        visible: root.activeModule === null
        screen: root.screen
        notificationPage: root.notificationPage
        onNotificationToggled: root.notificationPage = !root.notificationPage
        onAvatarRequested: root.openModule(ControlCenterModules.moduleByName("accounts"))
        onSettingsRequested: {
          // Open the accounts module inside the frame (DESIGN §3.5.3)
          openModule(ControlCenterModules.moduleByName("accounts"));
        }
        onSessionRequested: {
          PanelService.getPanel("sessionMenuPanel", root.screen)?.open();
          root.close();
        }
      }

      // 2. Middle area: home page / module view / notification page.
      // The home content slides out left while the module view slides in from
      // the right (DESIGN §3.5.3, Style.motionPanel), fading with travel.
      Item {
        id: middleArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Style.marginS
        clip: true

        readonly property bool moduleShown: root.activeModule !== null
        // The module view spans the full frame width (56 rail + 352 content);
        // the home page keeps its side margins.
        readonly property real travel: root.width

        // Home: cards + module grid
        ControlCenterModulesPage {
          id: modulesPage
          anchors.fill: parent
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          screen: root.screen
          opacity: root.notificationPage || middleArea.moduleShown ? 0 : 1
          visible: opacity > 0
          x: middleArea.moduleShown ? -middleArea.travel : 0
          onModuleSelected: function (module) {
            root.openModule(module, -1);
          }

          Behavior on x {
            enabled: !Color.isTransitioning
            NumberAnimation {
              duration: Style.motionPanel
              easing.type: Easing.InOutCubic
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: Style.motionPanel
              easing.type: Easing.InOutCubic
            }
          }
        }

        // Module view (rail + settings content)
        SettingsModuleView {
          id: moduleView
          anchors.fill: parent
          contentWidth: Style.settingsModuleContentWidth
          // Highlight/scroll target is pushed imperatively via openModuleAt so
          // scroll-sync inside the view never fights an outside binding.
          opacity: middleArea.moduleShown ? 1 : 0
          visible: opacity > 0
          enabled: middleArea.moduleShown
          x: middleArea.moduleShown ? 0 : middleArea.travel
          onBackRequested: root.activeModule = null

          Behavior on x {
            enabled: !Color.isTransitioning
            NumberAnimation {
              duration: Style.motionPanel
              easing.type: Easing.InOutCubic
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: Style.motionPanel
              easing.type: Easing.InOutCubic
            }
          }
        }

        ControlCenterNotificationPage {
          id: notificationPageItem
          anchors.fill: parent
          screen: root.screen
          opacity: root.notificationPage && !middleArea.moduleShown ? 1 : 0
          visible: opacity > 0
          enabled: root.notificationPage && !middleArea.moduleShown
          closeOnAction: () => root.close()

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationFast
            }
          }
        }
      }

      // 4. Quick control panel (bottom, fixed): hidden while the all-settings
      // page is open so the two settings columns take the full height (§3.5.3).
      ControlCenterQuickControl {
        id: quickControl
        Layout.fillWidth: true
        Layout.preferredHeight: Style.quickControlPanelHeight + Style.pageIndicatorHeight
        visible: root.activeModule === null
        screen: root.screen
        Layout.alignment: Qt.AlignBottom

        // IPC-requested page: applied on load and whenever it changes
        property string requestedPage: root.pendingQuickPage
        onRequestedPageChanged: if (requestedPage)
                                  quickControl.openPage(requestedPage)
        Component.onCompleted: if (requestedPage)
                                 quickControl.openPage(requestedPage)
      }
    }
  }
}
