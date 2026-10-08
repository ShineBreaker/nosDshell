import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Panels.ControlCenter
import qs.Services.UI
import qs.Widgets

FloatingWindow {
  id: root

  title: "nosDshell"
  // 56 px rail + 640 px content (DESIGN §3.5.3), plus the DDE window padding.
  minimumSize: Qt.size((Style.settingsRailWidth + Style.settingsWindowContentWidth + Style.margin2M) * 1, 910 * Style.uiScaleRatio)
  implicitWidth: Math.round(Style.settingsRailWidth + Style.settingsWindowContentWidth + Style.margin2M)
  implicitHeight: Math.round(910 * Style.uiScaleRatio)
  color: "transparent"

  visible: false

  // Register with SettingsPanelService
  Component.onCompleted: {
    SettingsPanelService.settingsWindow = root;
  }

  // The module shown in the two-column view (null = first module)
  property var activeModule: null

  // Navigate to a specific tab and optional subtab.
  // Works whether the window is already visible or just becoming visible.
  function navigateTo(tab, subTab) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = (subTab !== undefined && subTab !== null && subTab >= 0) ? subTab : -1;
    const target = ControlCenterModules.targetForTab(tabId, subTabId);
    if (target) {
      activeModule = target.module;
      settingsModuleView.openModuleAt(target.module, target.slot, target.inner, false);
    }
  }

  // Navigate to a search result entry.
  // The two-column view has no per-entry journal, so entries land on their
  // module; the group the row lives in stays expanded on the page.
  function navigateToEntry(entry) {
    if (entry && entry.tab !== undefined)
      navigateTo(entry.tab, entry.subTab);
  }

  // Sync visibility with service
  onVisibleChanged: {
    SettingsPanelService.isWindowOpen = visible;
  }

  // Keyboard shortcuts
  Shortcut {
    sequence: "Escape"
    enabled: !PanelService.isKeybindRecording
    onActivated: SettingsPanelService.closeWindow()
  }

  Shortcut {
    sequence: "Tab"
    enabled: !PanelService.isKeybindRecording
    onActivated: settingsModuleView.selectNextModule()
  }

  Shortcut {
    sequence: "Backtab"
    enabled: !PanelService.isKeybindRecording
    onActivated: settingsModuleView.selectPreviousModule()
  }

  Shortcut {
    sequence: "Backspace"
    enabled: !PanelService.isKeybindRecording
    onActivated: SettingsPanelService.closeWindow()
  }

  // Main content
  Rectangle {
    anchors.fill: parent
    // DDialog-style window (DESIGN §3.5.3): maskShell carries the final alpha
    // itself (blur ? panelBackgroundOpacity : 0.8), so re-applying the setting
    // here would multiply it — same rule as ControlCenterPanel's ownBackgroundAlpha.
    color: Color.maskShell
    radius: Style.radiusWindow

    SettingsModuleView {
      id: settingsModuleView
      anchors.fill: parent
      anchors.margins: Style.marginS
      contentWidth: Style.settingsWindowContentWidth
      // Highlight/scroll target is pushed imperatively via openModuleAt (see
      // navigateTo); a binding here would fight the view's scroll-sync.
      // The window has no home page to go back to; Esc closes it instead.
      onBackRequested: SettingsPanelService.closeWindow()
    }
  }
}
