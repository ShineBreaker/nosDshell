import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Modules.Panels.Settings.Tabs
import qs.Modules.Panels.Settings.Tabs.About
import qs.Modules.Panels.Settings.Tabs.Audio
import qs.Modules.Panels.Settings.Tabs.Bar
import qs.Modules.Panels.Settings.Tabs.ColorScheme
import qs.Modules.Panels.Settings.Tabs.Connections
import qs.Modules.Panels.Settings.Tabs.ControlCenter
import qs.Modules.Panels.Settings.Tabs.Display
import qs.Modules.Panels.Settings.Tabs.Dock
import qs.Modules.Panels.Settings.Tabs.Hooks
import qs.Modules.Panels.Settings.Tabs.Idle
import qs.Modules.Panels.Settings.Tabs.Launcher
import qs.Modules.Panels.Settings.Tabs.LockScreen
import qs.Modules.Panels.Settings.Tabs.Notifications
import qs.Modules.Panels.Settings.Tabs.Osd
import qs.Modules.Panels.Settings.Tabs.Plugins
import qs.Modules.Panels.Settings.Tabs.Region
import qs.Modules.Panels.Settings.Tabs.SessionMenu
import qs.Modules.Panels.Settings.Tabs.SystemMonitor
import qs.Modules.Panels.Settings.Tabs.UserInterface
import qs.Modules.Panels.Settings.Tabs.Wallpaper
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

/**
* SettingsModuleView - a DDE settings module inside the control center frame
* (DESIGN §3.5.3–3.5.4).
*
* Two columns: a 56 px icon rail (module icons, spacing 20, hover white@0.2,
* selected white@0.3, radiusItem, left-pointing tooltip) and a 352 px content
* column. The content stacks the module's settings tabs; each tab's sub-tabs are
* laid out as SettingsGroups on one scrollable page (NTabBar.groupMode +
* NTabView.stacked) instead of a horizontal pill strip.
*
* The rail and the module mapping live in ControlCenterModules, so the home
* grid, the rail and `settings openTab` routing stay in sync.
*
* `backRequested` fires when the content header's back button is pressed.
*/
Item {
  id: root

  // The module currently shown (an entry of ControlCenterModules.modules).
  property var module: null
  // 352 in the frame, 640 in the centered window (DESIGN §3.5.3).
  property real contentWidth: Style.settingsModuleContentWidth

  signal backRequested

  readonly property var modules: ControlCenterModules.modules.filter(m => ControlCenterModules.isVisible(m))
  readonly property var activeModule: module ?? (modules.length > 0 ? modules[0] : null)
  readonly property string title: activeModule ? ControlCenterModules.tr(activeModule.label) : ""

  implicitWidth: Style.settingsRailWidth + root.contentWidth
  implicitHeight: contentLayout.implicitHeight

  function selectModule(mod) {
    if (mod && mod !== activeModule)
      module = mod;
  }

  function moduleIndex(mod) {
    for (var i = 0; i < modules.length; i++) {
      if (modules[i] === mod)
        return i;
    }
    return -1;
  }

  function selectNextModule() {
    const i = moduleIndex(activeModule);
    if (i >= 0 && i + 1 < modules.length)
      selectModule(modules[i + 1]);
  }

  function selectPreviousModule() {
    const i = moduleIndex(activeModule);
    if (i > 0)
      selectModule(modules[i - 1]);
  }

  // Sub-tabs of a tab are shown as SettingsGroups on one scrollable page
  // (DESIGN §3.5.3): find the tab's NTabBar / NTabView by objectName and flip
  // both into group mode. objectName lookup keeps tab files untouched.
  function _applyGroupMode(tabItem) {
    if (!tabItem)
      return;
    const bar = _findByObjectName(tabItem, "NTabBar");
    const view = _findByObjectName(tabItem, "NTabView");
    if (bar)
      bar.groupMode = true;
    if (view)
      view.stacked = true;
  }

  function _findByObjectName(item, name) {
    if (!item || !item.children)
      return null;
    for (var i = 0; i < item.children.length; i++) {
      const child = item.children[i];
      if (child.objectName === name)
        return child;
      const found = _findByObjectName(child, name);
      if (found)
        return found;
    }
    return null;
  }

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ---------------- left rail (56 px) ----------------
    Rectangle {
      Layout.preferredWidth: Style.settingsRailWidth
      Layout.fillHeight: true
      color: "transparent"

      NScrollView {
        anchors.fill: parent
        anchors.topMargin: Style.marginS
        anchors.bottomMargin: Style.marginS
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        showGradientMasks: false
        ScrollBar.vertical.visible: false

        Column {
          width: parent.width
          spacing: Style.settingsRailSpacing

          Repeater {
            model: root.modules

            delegate: Rectangle {
              required property var modelData
              required property int index

              readonly property bool selected: root.activeModule === modelData

              width: Style.settingsRailWidth
              height: Style.settingsRailWidth
              radius: Style.radiusItem
              color: {
                if (railArea.containsMouse)
                  return Qt.rgba(1, 1, 1, 0.3);
                if (selected)
                  return Qt.rgba(1, 1, 1, 0.3);
                return "transparent";
              }

              Behavior on color {
                enabled: !Color.isTransitioning
                ColorAnimation {
                  duration: Style.animationFast
                }
              }

              NIcon {
                anchors.centerIn: parent
                icon: modelData.icon
                pointSize: Style.fontSizeL
                applyUiScale: false
                color: parent.selected ? Color.onShell : Color.onShellSecondary
              }

              MouseArea {
                id: railArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: TooltipService.show(parent, ControlCenterModules.tr(modelData.label), "left")
                onExited: TooltipService.hide()
                onClicked: root.selectModule(modelData)
              }
            }
          }
        }
      }
    }

    // ---------------- content (352 px in the frame, 640 in the window) ----------------
    Item {
      Layout.preferredWidth: root.contentWidth
      Layout.fillHeight: true
      clip: true

      ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 0

        // Header: back button, centred title, separator 15 px below (DESIGN §3.5.3)
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize + Style.marginS

          NIconButton {
            id: backButton
            anchors.left: parent.left
            anchors.leftMargin: Style.marginS
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron-left"
            baseSize: Style.baseWidgetSize * 0.75
            tooltipText: I18n.tr("common.back")
            onClicked: root.backRequested()
          }

          NText {
            anchors.centerIn: parent
            text: root.title
            pointSize: Style.settingsModuleTitleSize
            font.weight: Style.fontWeightMedium
            color: Color.onShell
            elide: Text.ElideRight
            width: parent.width - Style.baseWidgetSize
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.borderS
          Layout.leftMargin: Style.settingsRowPaddingH
          Layout.rightMargin: Style.settingsRowPaddingH
          Layout.bottomMargin: Style.settingsModuleSeparatorGap
          color: Qt.rgba(1, 1, 1, Style.settingsHeadAlpha)
        }

        // Search (DESIGN §3.5.4 input: height 30, bg field, radiusItem, focus
        // 1 px accent). Noctalia's search index has no DDE counterpart; the
        // field lives in the module view so every mode keeps working.
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
          Layout.rightMargin: Style.marginS
          Layout.bottomMargin: Style.marginS
          Layout.preferredHeight: Math.round(30 * Style.uiScaleRatio)
          radius: Style.radiusItem
          color: Color.overlay("field")
          border.width: searchInput.activeFocus ? Style.borderS : 0
          border.color: Color.accent

          NIcon {
            anchors.left: parent.left
            anchors.leftMargin: Style.marginS
            anchors.verticalCenter: parent.verticalCenter
            icon: "search"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }

          TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Style.margin2S
            anchors.rightMargin: Style.marginS
            verticalAlignment: Text.AlignVCenter
            leftPadding: Style.margin2S
            color: Color.onShell
            font.pointSize: Style.fontSizeBody
            selectByMouse: true
            onAccepted: {
              if (searchResults.count > 0)
                searchResults.selectFirst();
            }
          }

          ListView {
            id: searchResults
            anchors.top: parent.bottom
            anchors.topMargin: Style.marginXS
            anchors.left: parent.left
            anchors.right: parent.right
            visible: count > 0 && searchInput.text.trim() !== ""
            height: visible ? Math.min(contentHeight, Style.controlCenterWidth) : 0
            clip: true
            model: SettingsSearchService.searchIndex.filter(function (entry) {
                    return SettingsSearchService.isEntryVisible(entry) && searchInput.text.trim() !== "" && I18n.tr(entry.labelKey).toLowerCase().includes(searchInput.text.trim().toLowerCase());
                  })
            z: 10

            function selectFirst() {
              if (currentItem)
                searchResultClicked(currentItem.entry);
            }

            delegate: Rectangle {
              required property var modelData
              readonly property var entry: modelData
              width: searchResults.width
              height: Style.detailRowHeight
              radius: itemMouse.containsMouse ? Style.radiusRow : 0
              color: itemMouse.containsMouse ? Color.overlay("checked") : Color.overlay("strong")

              NText {
                anchors.left: parent.left
                anchors.leftMargin: Style.marginS
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.margin2S
                text: I18n.tr(entry.labelKey)
                pointSize: Style.fontSizeBody
                color: Color.onShell
                elide: Text.ElideRight
              }

              MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: searchResultClicked(entry)
              }
            }
          }

          function searchResultClicked(entry) {
            const mod = ControlCenterModules.moduleForTab(entry.tab, entry.subTab);
            if (mod)
              root.selectModule(mod);
            searchInput.text = "";
          }
        }

        // The tabs of the active module, stacked as groups (DESIGN §3.5.3)
        NScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.leftMargin: Style.marginS
          Layout.rightMargin: Style.marginS
          Layout.bottomMargin: Style.marginM
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          reserveScrollbarSpace: false
          showGradientMasks: false
          gradientColor: Color.maskShell

          Column {
            id: tabColumn
            width: parent.width
            spacing: Style.marginM

            Repeater {
              model: root.activeModule ? (root.activeModule.tabs ?? [root.activeModule]) : []

              delegate: Loader {
                required property var modelData
                width: tabColumn.width
                sourceComponent: {
                  switch (modelData.tab) {
                  case SettingsPanel.Tab.About:
                    return aboutTab;
                  case SettingsPanel.Tab.Audio:
                    return audioTab;
                  case SettingsPanel.Tab.Bar:
                    return barTab;
                  case SettingsPanel.Tab.ColorScheme:
                    return colorSchemeTab;
                  case SettingsPanel.Tab.LockScreen:
                    return lockScreenTab;
                  case SettingsPanel.Tab.ControlCenter:
                    return controlCenterTab;
                  case SettingsPanel.Tab.DesktopWidgets:
                    return desktopWidgetsTab;
                  case SettingsPanel.Tab.OSD:
                    return osdTab;
                  case SettingsPanel.Tab.Display:
                    return displayTab;
                  case SettingsPanel.Tab.Dock:
                    return dockTab;
                  case SettingsPanel.Tab.General:
                    return generalTab;
                  case SettingsPanel.Tab.Hooks:
                    return hooksTab;
                  case SettingsPanel.Tab.Idle:
                    return idleTab;
                  case SettingsPanel.Tab.Launcher:
                    return launcherTab;
                  case SettingsPanel.Tab.Location:
                    return regionTab;
                  case SettingsPanel.Tab.Connections:
                    return connectionsTab;
                  case SettingsPanel.Tab.Notifications:
                    return notificationsTab;
                  case SettingsPanel.Tab.Plugins:
                    return pluginsTab;
                  case SettingsPanel.Tab.SessionMenu:
                    return sessionMenuTab;
                  case SettingsPanel.Tab.System:
                    return systemMonitorTab;
                  case SettingsPanel.Tab.UserInterface:
                    return userInterfaceTab;
                  case SettingsPanel.Tab.Wallpaper:
                    return wallpaperTab;
                  }
                  return aboutTab;
                }

                onLoaded: {
                  if (item === null)
                    return;
                  _applyGroupMode(item);
                  if (modelData.subTab !== undefined && modelData.subTab >= 0)
                    item.currentSubTabIndex = modelData.subTab;
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: aboutTab
    AboutTab {}
  }
  Component {
    id: audioTab
    AudioTab {}
  }
  Component {
    id: barTab
    BarTab {}
  }
  Component {
    id: colorSchemeTab
    ColorSchemeTab {}
  }
  Component {
    id: lockScreenTab
    LockScreenTab {}
  }
  Component {
    id: controlCenterTab
    ControlCenterTab {}
  }
  Component {
    id: desktopWidgetsTab
    DesktopWidgetsTab {}
  }
  Component {
    id: osdTab
    OsdTab {}
  }
  Component {
    id: displayTab
    DisplayTab {}
  }
  Component {
    id: dockTab
    DockTab {}
  }
  Component {
    id: generalTab
    GeneralTab {}
  }
  Component {
    id: hooksTab
    HooksTab {}
  }
  Component {
    id: idleTab
    IdleTab {}
  }
  Component {
    id: launcherTab
    LauncherTab {}
  }
  Component {
    id: regionTab
    RegionTab {}
  }
  Component {
    id: connectionsTab
    ConnectionsTab {}
  }
  Component {
    id: notificationsTab
    NotificationsTab {}
  }
  Component {
    id: pluginsTab
    PluginsTab {}
  }
  Component {
    id: sessionMenuTab
    SessionMenuTab {}
  }
  Component {
    id: systemMonitorTab
    SystemMonitorTab {}
  }
  Component {
    id: userInterfaceTab
    UserInterfaceTab {}
  }
  Component {
    id: wallpaperTab
    WallpaperTab {}
  }
}
