pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.UI

// Single owner of the DDE launcher (DESIGN §3.4). Both views — the fullscreen
// layer surfaces and the mini window — open through here, so the taskbar item,
// IPC and the in-view toggle buttons all share one state machine.
Singleton {
  id: root

  // "fullscreen" | "mini" — persisted in Settings.data.appLauncher.mode
  readonly property string mode: Settings.data.appLauncher.mode

  property bool fullscreenOpen: false
  property var fullscreenScreen: null
  property bool miniOpen: false
  property var miniScreen: null

  // Both views live for the whole session (their layer surfaces persist), so
  // each registers its LauncherModel into its own slot; the open flag decides
  // which one is active — creation order must not matter.
  property var fullscreenModel: null
  property var miniModel: null
  readonly property var activeModel: fullscreenOpen ? fullscreenModel : (miniOpen ? miniModel : null)
  property var _pendingSearch: null

  readonly property bool anyOpen: fullscreenOpen || miniOpen

  signal opened
  signal closed

  // ---- state queries ----

  function isOpen(screen) {
    if (!screen)
      return false;
    if (fullscreenOpen && fullscreenScreen === screen)
      return true;
    if (miniOpen && miniScreen === screen)
      return true;
    return false;
  }

  function isOpenOnAnyScreen() {
    return anyOpen;
  }

  function modelForScreen(screen) {
    if (!screen)
      return null;
    if (!isOpen(screen))
      return null;
    return activeModel;
  }

  // ---- state transitions ----

  function open(screen) {
    openWithSearch(screen, "");
  }

  function openWithSearch(screen, searchText) {
    if (!screen)
      return;

    if (isOpen(screen)) {
      if (searchText && activeModel)
        activeModel.setSearchText(searchText);
      return;
    }

    closeAll();

    if (mode === "mini") {
      miniScreen = screen;
      miniOpen = true;
    } else {
      fullscreenScreen = screen;
      fullscreenOpen = true;
    }

    _pendingSearch = {
      "text": searchText || ""
    };
    takePendingSearch();
    opened();
  }

  function toggle(screen) {
    if (isOpen(screen)) {
      close(screen);
    } else {
      open(screen);
    }
  }

  function close(screen) {
    if (screen && !isOpen(screen))
      return;
    const wasOpen = anyOpen;
    closeAll();
    if (wasOpen)
      closed();
  }

  function closeAll() {
    fullscreenOpen = false;
    fullscreenScreen = null;
    miniOpen = false;
    miniScreen = null;
    _pendingSearch = null;
  }

  // ---- model handshake ----

  // Called by a view when its LauncherModel exists; applies the primed search.
  function registerModel(viewMode, model) {
    if (viewMode === "mini")
      miniModel = model;
    else
      fullscreenModel = model;
    takePendingSearch();
  }

  function unregisterModel(viewMode, model) {
    if (viewMode === "mini" && miniModel === model)
      miniModel = null;
    if (viewMode === "fullscreen" && fullscreenModel === model)
      fullscreenModel = null;
  }

  function takePendingSearch() {
    const pending = _pendingSearch;
    // Don't consume pending until the target model exists — the view may
    // register a beat after openWithSearch primed the search.
    if (!pending || !activeModel)
      return;
    _pendingSearch = null;
    activeModel.setSearchText(pending.text);
  }

  // Switch mode (persisted) — used by the toggle buttons inside both views.
  // Upstream swaps the live window when the launcher is open
  // (gxde-launcher launchersys.cpp:238-246); do the same and carry the search
  // text across so a mid-search switch doesn't lose the query.
  function setMode(newMode) {
    if (newMode !== "fullscreen" && newMode !== "mini")
      return;
    if (Settings.data.appLauncher.mode === newMode)
      return;

    const carryText = activeModel ? activeModel.searchText : "";
    const screen = miniOpen ? miniScreen : fullscreenScreen;

    Settings.data.appLauncher.mode = newMode;

    if (!screen)
      return;

    closeAll();
    if (newMode === "mini") {
      miniScreen = screen;
      miniOpen = true;
    } else {
      fullscreenScreen = screen;
      fullscreenOpen = true;
    }
    _pendingSearch = {
      "text": carryText
    };
    takePendingSearch();
    opened();
  }

  function showSessionMenu(screen) {
    const panel = PanelService.getPanel("sessionMenuPanel", screen);
    if (panel)
      panel.toggle();
  }

  function showSettings(screen) {
    SettingsPanelService.openToTab(SettingsPanel.Tab.Launcher, -1, screen);
  }
}
