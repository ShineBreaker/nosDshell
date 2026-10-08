import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.ControlCenter
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // The "centered"/"attached" settings surface hosts the same two-column DDE
  // module view as the control-center frame (rail + 640 px content).
  // Hold the loaded tabs across close/open cycles: reopening is instant.
  keepContentAlive: true
  preferredWidth: Style.settingsRailWidth + Style.settingsWindowContentWidth
  preferredHeight: Math.round(910 * Style.uiScaleRatio)

  // Settings panel mode: "controlCenter", "centered", "attached", "window"
  readonly property string settingsPanelMode: Settings.data.ui.settingsPanelMode
  readonly property bool isWindowMode: settingsPanelMode === "window"
  readonly property bool attachToBar: settingsPanelMode === "attached"

  readonly property string barDensity: Settings.data.bar.density
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool barFloating: Settings.getEffectiveBarType() === "floating"
  readonly property real barMarginH: barFloating ? Math.ceil(Settings.data.bar.marginHorizontal) : 0
  readonly property real barMarginV: barFloating ? Math.ceil(Settings.data.bar.marginVertical) : 0

  forceAttachToBar: attachToBar
  panelAnchorHorizontalCenter: !root.useButtonPosition && (attachToBar ? (barPosition === "top" || barPosition === "bottom") : true)
  panelAnchorVerticalCenter: !root.useButtonPosition && (attachToBar ? (barPosition === "left" || barPosition === "right") : true)
  panelAnchorTop: !root.useButtonPosition && attachToBar && barPosition === "top"
  panelAnchorBottom: !root.useButtonPosition && attachToBar && barPosition === "bottom"
  panelAnchorLeft: !root.useButtonPosition && attachToBar && barPosition === "left"
  panelAnchorRight: !root.useButtonPosition && attachToBar && barPosition === "right"

  onAttachToBarChanged: {
    if (isPanelOpen) {
      Qt.callLater(root.setPosition);
    }
  }

  onBarPositionChanged: {
    if (isPanelOpen) {
      Qt.callLater(root.setPosition);
    }
  }

  onBarDensityChanged: {
    if (isPanelOpen) {
      Qt.callLater(root.setPosition);
    }
  }

  onBarFloatingChanged: {
    if (isPanelOpen) {
      Qt.callLater(root.setPosition);
    }
  }

  onBarMarginHChanged: {
    if (isPanelOpen) {
      Qt.callLater(root.setPosition);
    }
  }

  onBarMarginVChanged: {
    if (isPanelOpen) {
      Qt.callLater(root.setPosition);
    }
  }

  // Tabs enumeration, order is NOT relevant
  enum Tab {
    Advanced,
    About,
    Audio,
    Bar,
    ColorScheme,
    LockScreen,
    ControlCenter,
    DesktopWidgets,
    OSD,
    Display,
    Dock,
    General,
    Hooks,
    Idle,
    Launcher,
    Location,
    Connections,
    Notifications,
    Plugins,
    SessionMenu,
    System,
    UserInterface,
    Wallpaper
  }

  property int requestedTab: SettingsPanel.Tab.General
  property int requestedSubTab: -1
  property var requestedEntry: null

  // Internal reference to the module view (set when panel content loads)
  property var _settingsContent: null

  // Override toggle to handle window and controlCenter modes
  function toggle(buttonItem, buttonName) {
    if (settingsPanelMode === "controlCenter") {
      SettingsPanelService.toggle(requestedTab, requestedSubTab, screen);
      return;
    }
    if (isWindowMode) {
      SettingsPanelService.toggleWindow(requestedTab);
      return;
    }
    // Call parent toggle
    if (isPanelOpen) {
      close();
    } else {
      open(buttonItem, buttonName);
    }
  }

  // Override open to handle window and controlCenter modes
  function open(buttonItem, buttonName) {
    if (settingsPanelMode === "controlCenter") {
      // This surface never shows in controlCenter mode; the frame carries the
      // all-settings page instead (DESIGN §3.5.3).
      SettingsPanelService.openToTab(requestedTab, requestedSubTab, screen);
      return;
    }
    if (isWindowMode) {
      SettingsPanelService.openWindow(requestedTab);
      return;
    }

    // Panel mode: replicate SmartPanel.open() logic
    if (!buttonItem && buttonName) {
      if (typeof buttonName === "object" && buttonName.x !== undefined && buttonName.y !== undefined) {
        root.buttonItem = null;
        root.buttonPosition = buttonName;
        root.buttonWidth = 0;
        root.buttonHeight = 0;
        root.useButtonPosition = true;
      } else {
        buttonItem = BarService.lookupWidget(buttonName, screen.name);
      }
    }

    if (buttonItem) {
      root.buttonItem = buttonItem;
      var buttonPos = buttonItem.mapToItem(null, 0, 0);
      root.buttonPosition = Qt.point(buttonPos.x, buttonPos.y);
      root.buttonWidth = buttonItem.width;
      root.buttonHeight = buttonItem.height;
      root.useButtonPosition = true;
    } else if (!(buttonName && typeof buttonName === "object" && buttonName.x !== undefined && buttonName.y !== undefined)) {
      root.buttonItem = null;
      root.useButtonPosition = false;
    }

    isPanelOpen = true;
    PanelService.willOpenPanel(root);
  }

  // Open to a specific tab and optionally a subtab
  function openToTab(tab, subTab, buttonItem, buttonName) {
    requestedTab = tab !== undefined ? tab : SettingsPanel.Tab.General;
    requestedSubTab = subTab !== undefined ? subTab : -1;
    open(buttonItem, buttonName);
  }

  // When the panel opens, highlight and scroll to the requested module
  onOpened: {
    if (!_settingsContent)
      return;
    var tab = requestedTab;
    var sub = requestedSubTab;
    if (requestedEntry) {
      tab = requestedEntry.tab;
      sub = (requestedEntry.subTab !== undefined && requestedEntry.subTab !== null) ? requestedEntry.subTab : -1;
      requestedEntry = null;
    }
    requestedSubTab = -1;
    const target = ControlCenterModules.targetForTab(tab, sub);
    if (target)
      _settingsContent.openModuleAt(target.module, target.slot, target.inner, false);
  }

  // Scroll functions - delegate to content
  function scrollDown() {
    if (_settingsContent)
      _settingsContent.scrollDown();
  }

  function scrollUp() {
    if (_settingsContent)
      _settingsContent.scrollUp();
  }

  function scrollPageDown() {
    if (_settingsContent)
      _settingsContent.scrollPageDown();
  }

  function scrollPageUp() {
    if (_settingsContent)
      _settingsContent.scrollPageUp();
  }

  // Navigation functions - delegate to the module view
  function selectNextTab() {
    if (_settingsContent)
      _settingsContent.selectNextModule();
  }

  function selectPreviousTab() {
    if (_settingsContent)
      _settingsContent.selectPreviousModule();
  }

  // Override keyboard handlers from SmartPanel
  function onTabPressed() {
    selectNextTab();
  }

  function onBackTabPressed() {
    selectPreviousTab();
  }

  function onUpPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "") {
      _settingsContent.searchSelectPrevious();
    } else {
      scrollUp();
    }
  }

  function onDownPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "") {
      _settingsContent.searchSelectNext();
    } else {
      scrollDown();
    }
  }

  function onPageUpPressed() {
    scrollPageUp();
  }

  function onPageDownPressed() {
    scrollPageDown();
  }

  function onCtrlJPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "") {
      _settingsContent.searchSelectNext();
    } else {
      scrollDown();
    }
  }

  function onCtrlKPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "") {
      _settingsContent.searchSelectPrevious();
    } else {
      scrollUp();
    }
  }

  panelContent: Rectangle {
    id: panelContent
    color: "transparent"

    SettingsModuleView {
      id: moduleView
      anchors.fill: parent
      anchors.margins: Style.marginS
      contentWidth: Style.settingsWindowContentWidth
      // The standalone panel has no home page; back closes it.
      onBackRequested: root.close()
      Component.onCompleted: {
        root._settingsContent = moduleView;
      }
    }
  }
}
