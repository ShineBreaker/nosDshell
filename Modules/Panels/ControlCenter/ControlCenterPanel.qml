import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.ControlCenter
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Noctalia
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

  // Quick-control page requested from IPC (applied when the frame opens, or
  // immediately when it is already open)
  property string pendingQuickPage: ""

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
      }
      function onClosed() {
        MediaService.autoSwitchingPaused = false;
        root.notificationPage = false;
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

      // 1. Header (140 px)
      ControlCenterHeader {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.controlCenterHeaderHeight
        screen: root.screen
        notificationPage: root.notificationPage
        onNotificationToggled: root.notificationPage = !root.notificationPage
        onSettingsRequested: {
          root.close();
          SettingsPanelService.openToTab(SettingsPanel.Tab.General, -1, root.screen);
        }
        onSessionRequested: {
          PanelService.getPanel("sessionMenuPanel", root.screen)?.open();
          root.close();
        }
      }

      // 2. Update bar (when an update is available)
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.detailRowHeight
        Layout.leftMargin: Style.marginS
        Layout.rightMargin: Style.marginS
        Layout.topMargin: Style.marginXXS
        radius: Style.radiusRow
        visible: updateAvailable
        color: updateArea.containsMouse ? Color.overlay("hover") : Color.overlay("idle")

        readonly property bool updateAvailable: {
          const latest = GitHubService.latestVersion;
          const current = UpdateService.currentVersion;
          if (!latest || !current || latest === I18n.tr("common.unknown") || current.endsWith("-git"))
            return false;
          return UpdateService.compareVersions(latest, current) > 0;
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          spacing: Style.marginS

          NIcon {
            icon: "refresh"
            pointSize: Style.fontSizeL
            color: Color.onShellSecondary
          }

          NText {
            Layout.fillWidth: true
            text: I18n.tr("control-center.update-available", {
                            "version": GitHubService.latestVersion
                          })
            pointSize: Style.fontSizeS
            color: Color.onShell
            elide: Text.ElideRight
          }

          NIcon {
            icon: "chevron-right"
            pointSize: Style.fontSizeL
            color: Color.onShellSecondary
          }
        }

        MouseArea {
          id: updateArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.close();
            var panel = PanelService.getPanel("settingsPanel", root.screen);
            panel.requestedTab = SettingsPanel.Tab.About;
            panel.open();
          }
        }

        Behavior on color {
          enabled: !Color.isTransitioning
          ColorAnimation {
            duration: Style.animationFast
          }
        }
      }

      // 3. Middle area: modules page or notification page
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Style.marginS

        ControlCenterModulesPage {
          id: modulesPage
          anchors.fill: parent
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          screen: root.screen
          opacity: root.notificationPage ? 0 : 1
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationFast
            }
          }
        }

        ControlCenterNotificationPage {
          id: notificationPageItem
          anchors.fill: parent
          screen: root.screen
          opacity: root.notificationPage ? 1 : 0
          visible: opacity > 0
          closeOnAction: () => root.close()

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationFast
            }
          }
        }
      }

      // 4. Quick control panel (bottom, fixed): basic page + page indicator
      ControlCenterQuickControl {
        id: quickControl
        Layout.fillWidth: true
        Layout.preferredHeight: Style.quickControlPanelHeight + Style.pageIndicatorHeight
        screen: root.screen
        Layout.alignment: Qt.AlignBottom

        // IPC-requested page: applied on load and whenever it changes
        property string requestedPage: root.pendingQuickPage
        onRequestedPageChanged: if (requestedPage) quickControl.openPage(requestedPage);
        Component.onCompleted: if (requestedPage) quickControl.openPage(requestedPage);
      }
    }
  }
}
