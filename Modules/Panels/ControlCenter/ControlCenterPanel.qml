import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.ControlCenter
import qs.Services.Debug
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
* from the right with Style.motionEnter (OutCubic). Always on the right —
* Noctalia's controlCenter.position option was removed (Migration78); with
* the taskbar on the right the frame sits on its inner side.
*/
SmartPanel {
  id: root

  // The DDE frame has no arrow and no grow animation of its own.
  arrowPopup: false

  // Hold the frame content across close/open cycles: the all-settings page
  // and notification history keep their loaded state, reopening is instant.
  keepContentAlive: true

  // Present as a full-height edge sheet (DESIGN §3.5.1) with its own shadow.
  edgeSheet: true
  panelShadow: Style.shadowControlCenter

  // Which middle page shows when no module is open: false = the home page
  // (the notification list — the DDE default; the cards live in the
  // quick-control pager below), true = the all-settings module grid
  // (〔演进〕 grid is a settings entry page, not the landing view).
  property bool allSettingsPage: false

  // Scene forensics: the whole frame registers as "cc-<screen>" so
  // `qs ipc call debug tree cc-HEADLESS-1` dumps the paint/delivery order.
  property string _dbgName: ""
  Component.onDestruction: {
    if (root._dbgName !== "")
      DebugService.unregisterRoot(root._dbgName);
  }
  onScreenChanged: {
    if (root._dbgName !== "")
      DebugService.unregisterRoot(root._dbgName);
    if (screen && screen.name) {
      root._dbgName = "cc-" + screen.name;
      DebugService.registerRoot(root._dbgName, root);
      Logger.d("Debug", "registered", root._dbgName, "for", root.objectName);
    }
  }

  // Which module the middle area shows (null = home page, DESIGN §3.5.3)
  property var activeModule: null

  // Quick-control page requested from IPC (applied when the frame opens, or
  // immediately when it is already open)
  property string pendingQuickPage: ""

  // Module requested from IPC (applied when the frame opens). pendingSubTab
  // is the tab slot inside the module; pendingInner the stacked sub-group
  // inside that tab (see ControlCenterModules.targetForTab).
  property var pendingModule: null
  property int pendingSubTab: -1
  property int pendingInner: -1

  // The settings view registers itself here: panelContent is a separate
  // Component scope, so ids inside it are invisible to root functions.
  property var _moduleView: null

  // Open the module view scrolled to a module (DESIGN §3.5.3, from the
  // all-settings grid, IPC "settings openTab", or a deep link).
  // subTab scrolls to the matching tab section inside the module, inner to
  // a stacked sub-group inside that tab.
  // Home-area page helpers: the two bare-frame pages are the notifications
  // view and the all-settings grid.
  function showNotifications() {
    activeModule = null;
    allSettingsPage = false;
  }

  function showAllSettings() {
    activeModule = null;
    allSettingsPage = true;
  }

  function openModule(module, subTab, inner) {
    if (!module)
      return;
    // Modules are entered from the all-settings grid; backing out lands
    // there too.
    allSettingsPage = true;
    activeModule = module;
    pendingSubTab = (subTab === undefined || subTab === null) ? -1 : subTab;
    pendingInner = (inner === undefined || inner === null) ? -1 : inner;
    if (root._moduleView)
      root._moduleView.openModuleAt(module, pendingSubTab, pendingInner, false);
  }

  // Page state resets on close. This must live at the root: the closed signal
  // is emitted after isPanelOpen=false unloads panelContent, so a handler
  // inside the content would already be destroyed.
  onClosed: {
    MediaService.autoSwitchingPaused = false;
    allSettingsPage = false;
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

  panelBackgroundColor: Colors.maskShell
  // maskShell already carries the final alpha (blur ? setting : 0.8 fallback);
  // rendering under the effectivePanelOpacity layer would multiply it again.
  ownBackgroundAlpha: true
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
          root.openModule(root.pendingModule, root.pendingSubTab, root.pendingInner);
          root.pendingModule = null;
          root.pendingSubTab = -1;
          root.pendingInner = -1;
        }
      }
      function onAllSettingsPageChanged() {
        if (root.allSettingsPage)
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

      // 1. Header (140 px); hidden while a module view is open so the
      // two settings columns take the full frame height (§3.5.3).
      ControlCenterHeader {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.controlCenterHeaderHeight
        visible: root.activeModule === null
        screen: root.screen
        // The bell accents while the notifications view is showing; it
        // toggles between it and the all-settings grid.
        notificationPage: !root.allSettingsPage
        onNotificationToggled: root.allSettingsPage = !root.allSettingsPage
        onAvatarRequested: root.openModule(ControlCenterModules.moduleByName("accounts"))
        onSettingsRequested: {
          // The gear opens the all-settings grid (DESIGN §3.5.3)
          root.showAllSettings();
        }
        onSessionRequested: {
          PanelService.getPanel("sessionMenuPanel", root.screen)?.open();
          root.close();
        }
      }

      // 2. Middle area: notifications home / all-settings grid / module view.
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

        // All-settings page: the module grid (〔演进〕 no longer the landing
        // view — reached from the gear, the bell or settings entries)
        ControlCenterModulesPage {
          id: modulesPage
          anchors.fill: parent
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          screen: root.screen
          opacity: root.allSettingsPage && !middleArea.moduleShown ? 1 : 0
          visible: opacity > 0
          enabled: root.allSettingsPage && !middleArea.moduleShown
          x: middleArea.moduleShown ? -middleArea.travel : 0
          onModuleSelected: function (module) {
            root.openModule(module, -1);
          }

          // The !Colors.isTransitioning guard elsewhere exists to freeze *color*
          // Behaviors during a theme swap — geometry slides must still run.
          Behavior on x {
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

        // Home (default): the notification list (〔演进〕 notification-first;
        // the content cards moved into the quick-control pager as page 0)
        ControlCenterNotificationPage {
          id: notificationPageItem
          anchors.fill: parent
          screen: root.screen
          opacity: !root.allSettingsPage && !middleArea.moduleShown ? 1 : 0
          visible: opacity > 0
          enabled: !root.allSettingsPage && !middleArea.moduleShown
          closeOnAction: () => root.close()
          x: middleArea.moduleShown ? -middleArea.travel : 0

          Behavior on x {
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
      }

      // 4. Quick control panel (bottom, fixed): belongs to the notifications
      // home page — hidden while a module view or the all-settings grid is
      // open (§3.5.3; the grid is a settings picker, not a control surface).
      ControlCenterQuickControl {
        id: quickControl
        Layout.fillWidth: true
        Layout.preferredHeight: quickControl.implicitHeight
        visible: root.activeModule === null && !root.allSettingsPage
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
