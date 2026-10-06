pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Panels.ControlCenter
import qs.Services.UI

Singleton {
  id: root

  // Track if the settings window is open
  property bool isWindowOpen: false

  // Reference to the window (set by SettingsPanelWindow)
  property var settingsWindow: null

  // Requested tab when opening
  property int requestedTab: 0

  // Requested subtab when opening (-1 means no specific subtab)
  property int requestedSubTab: -1

  // Requested entry for search navigation
  property var requestedEntry: null

  signal windowOpened
  signal windowClosed

  function openToEntry(entry, screen) {
    if (Settings.data.ui.settingsPanelMode === "window") {
      requestedEntry = entry;
      if (settingsWindow) {
        settingsWindow.visible = true;
        isWindowOpen = true;
        windowOpened();
        settingsWindow.navigateToEntry(entry);
      }
    } else if (Settings.data.ui.settingsPanelMode === "controlCenter") {
      if (!screen || !entry || entry.tab === undefined) {
        Logger.w("SettingsPanelService", "Screen and entry required for controlCenter mode");
        return;
      }
      var ccPanel = PanelService.getPanel("controlCenterPanel", screen);
      var target = ControlCenterModules.targetForTab(entry.tab, entry.subTab);
      if (!ccPanel || !target)
        return;
      if (ccPanel.isPanelOpen)
        ccPanel.openModule(target.module, target.slot, target.inner);
      else {
        ccPanel.pendingModule = target.module;
        ccPanel.pendingSubTab = target.slot;
        ccPanel.pendingInner = target.inner;
        ccPanel.open();
      }
    } else {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for panel mode");
        return;
      }
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      if (settingsPanel) {
        settingsPanel.requestedEntry = entry;
        settingsPanel.open();
      }
    }
  }

  // Unified function to open settings to a specific tab and subtab
  // Respects user's settingsPanelMode setting (window vs panel vs controlCenter)
  // For panel and controlCenter modes, screen parameter is required
  function openToTab(tab, subTab, screen) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = subTab !== undefined ? subTab : -1;

    if (Settings.data.ui.settingsPanelMode === "window") {
      requestedTab = tabId;
      requestedSubTab = subTabId;
      if (settingsWindow) {
        settingsWindow.visible = true;
        isWindowOpen = true;
        windowOpened();
        settingsWindow.navigateTo(tabId, subTabId);
      }
    } else if (Settings.data.ui.settingsPanelMode === "controlCenter") {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for controlCenter mode");
        return;
      }
      var ccPanel = PanelService.getPanel("controlCenterPanel", screen);
      if (!ccPanel)
        return;
      // The frame carries the module view; open it (or apply immediately).
      var target = ControlCenterModules.targetForTab(tabId, subTabId);
      if (!target) {
        Logger.w("SettingsPanelService", "No module maps to tab", tabId, "subTab", subTabId);
        return;
      }
      if (ccPanel.isPanelOpen)
        ccPanel.openModule(target.module, target.slot, target.inner);
      else {
        ccPanel.pendingModule = target.module;
        ccPanel.pendingSubTab = target.slot;
        ccPanel.pendingInner = target.inner;
        ccPanel.open();
      }
    } else {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for panel mode");
        return;
      }
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      if (settingsPanel) {
        settingsPanel.openToTab(tabId, subTabId);
      }
    }
  }

  function openWindow(tab) {
    requestedTab = tab !== undefined ? tab : 0;
    requestedSubTab = -1;
    if (settingsWindow) {
      settingsWindow.visible = true;
      isWindowOpen = true;
      windowOpened();
      settingsWindow.navigateTo(requestedTab, -1);
    }
  }

  function closeWindow() {
    if (settingsWindow) {
      settingsWindow.visible = false;
      isWindowOpen = false;
      windowClosed();
    }
  }

  function toggleWindow(tab) {
    if (isWindowOpen) {
      closeWindow();
    } else {
      openWindow(tab);
    }
  }

  // Unified toggle: opens to tab/subtab if closed, closes if open
  // Respects settingsPanelMode setting
  function toggle(tab, subTab, screen) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = subTab !== undefined ? subTab : -1;

    if (Settings.data.ui.settingsPanelMode === "window") {
      if (isWindowOpen) {
        closeWindow();
      } else {
        openToTab(tabId, subTabId);
      }
    } else if (Settings.data.ui.settingsPanelMode === "controlCenter") {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for controlCenter mode");
        return;
      }
      var ccPanel = PanelService.getPanel("controlCenterPanel", screen);
      if (ccPanel?.isPanelOpen) {
        ccPanel.close();
      } else {
        openToTab(tabId, subTabId, screen);
      }
    } else {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for panel mode");
        return;
      }
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      if (settingsPanel?.isPanelOpen) {
        settingsPanel.close();
      } else {
        settingsPanel?.openToTab(tabId, subTabId);
      }
    }
  }

  // Unified close for both modes
  function close(screen) {
    if (Settings.data.ui.settingsPanelMode === "window") {
      closeWindow();
    } else if (Settings.data.ui.settingsPanelMode === "controlCenter") {
      if (!screen)
        return;
      PanelService.getPanel("controlCenterPanel", screen)?.close();
    } else {
      if (!screen)
        return;
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      settingsPanel?.close();
    }
  }
}
