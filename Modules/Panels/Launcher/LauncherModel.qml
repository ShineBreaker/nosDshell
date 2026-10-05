import QtQuick
import Quickshell
import "Helpers/LauncherNavigation.js" as LauncherNav
import "Providers"

import qs.Commons
import qs.Services.Keyboard
import qs.Services.UI
import qs.Widgets

// Non-visual launcher state: providers, search text, results, selection,
// activation, plugin-provider sync, usage sorting. The fullscreen and mini DDE
// views consume one instance each and only build UI on top of it.
// Root is an (invisible) Item so the provider Items can be children.
// The legacy LauncherCore (Noctalia panel view) stays for overviewLayer mode.
Item {
  id: root
  visible: false

  // ---------------------------------------------------------------
  // Owner hooks (set by the view)
  // ---------------------------------------------------------------
  signal requestClose            // soft close (with animation)
  signal requestCloseImmediately  // immediate close, used on app launch

  property var screen: null
  property bool isOpen: false

  readonly property string searchText: _searchText
  readonly property int selectedIndex: _selectedIndex
  readonly property var results: _results
  readonly property var providers: _providers
  readonly property var activeProvider: _activeProvider
  readonly property var currentProvider: _activeProvider || appsProvider
  readonly property var appsProvider: _providersById["appsProvider"] || null
  readonly property var clipboardProvider: _providersById["clipProvider"] || null

  // Provider id -> instance; id is the Item id (e.g. appsProvider)
  property var _providersById: ({})

  // Internal state — only mutated by the functions below
  property string _searchText: ""
  property int _selectedIndex: 0
  property var _results: []
  property var _providers: []
  property var _activeProvider: null
  property var _pluginProviderInstances: ({})

  // ---------------------------------------------------------------
  // Geometry helpers (DESIGN §3.4.1, gxde-launcher calculate_util.cpp)
  // ---------------------------------------------------------------
  // Cell width budget: screen <= 1440 -> 170 px, otherwise 200 px
  function cellBudget(screenWidth) {
    return screenWidth <= 1440 ? 170 : 200;
  }

  function cellSpacing(screenWidth) {
    return screenWidth <= 1440 ? 10 : 14;
  }

  // Columns for a grid of `gridWidth` px
  function gridColumnsFor(gridWidth, screenWidth) {
    const budget = cellBudget(screenWidth);
    return Math.max(1, Math.floor(gridWidth / budget));
  }

  function iconSizeFor(cellWidth) {
    return Math.round(cellWidth * Settings.data.appLauncher.iconRatio);
  }

  // Row height for list-like views (§3.4.2)
  readonly property int rowHeight: 36

  // ---------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------
  onIsOpenChanged: {
    if (isOpen) {
      onOpened();
    } else {
      onClosed();
    }
  }

  function onOpened() {
    // Results populate asynchronously as providers come up
    Qt.callLater(() => {
                   syncPluginProviders();
                   for (let provider of _providers) {
                     if (provider.onOpened)
                     provider.onOpened();
                   }
                   updateResults();
                 });
    focusSearchInput();
  }

  function onClosed() {
    _searchText = "";
    _selectedIndex = 0;
    _results = [];
    _activeProvider = null;
    for (let provider of _providers) {
      if (provider.onClosed)
        provider.onClosed();
    }
  }

  function close() {
    requestClose();
  }

  function closeImmediately() {
    requestCloseImmediately();
  }

  // The view assigns its search input item here (needs .inputItem)
  property var searchInput: null

  function focusSearchInput() {
    if (searchInput && searchInput.inputItem) {
      searchInput.inputItem.forceActiveFocus();
    }
  }

  // ---------------------------------------------------------------
  // Search / results
  // ---------------------------------------------------------------
  function setSearchText(text) {
    _searchText = text;
    updateResults();
  }

  function updateResults() {
    const text = _searchText;
    _results = [];
    let newActiveProvider = null;

    if (text.startsWith(">")) {
      for (let provider of _providers) {
        if (provider.handleCommand && provider.handleCommand(text)) {
          newActiveProvider = provider;
          _results = provider.getResults(text);
          break;
        }
      }

      if (!newActiveProvider) {
        let allCommands = [];
        for (let provider of _providers) {
          if (provider.commands)
            allCommands = allCommands.concat(provider.commands());
        }
        if (text === ">") {
          _results = allCommands;
        } else if (text.length > 1) {
          const query = text.substring(1);
          if (typeof FuzzySort !== 'undefined') {
            const fuzzyResults = FuzzySort.go(query, allCommands, {
                                                "keys": ["name"],
                                                "limit": 50
                                              });
            _results = fuzzyResults.map(result => result.obj);
          } else {
            const queryLower = query.toLowerCase();
            _results = allCommands.filter(cmd => (cmd.name || "").toLowerCase().includes(queryLower));
          }
        }
      }
    } else {
      let allResults = [];
      for (let provider of _providers) {
        if (provider.handleSearch) {
          const providerResults = provider.getResults(text);
          allResults = allResults.concat(providerResults);
        }
      }

      // Sort by _score (higher = better match); items without _score go first
      if (text.trim() !== "") {
        const boostByUsage = Settings.data.appLauncher.sortByMostUsed;

        allResults.sort((a, b) => {
                          let sa = a._score !== undefined ? a._score : 0;
                          let sb = b._score !== undefined ? b._score : 0;

                          // Boost frequently used items from tracked providers.
                          // _score is normalized 0-1, so the boost is scaled to
                          // nudge rather than overwhelm.
                          if (boostByUsage) {
                            if (a.provider && a.provider.trackUsage && a.usageKey) {
                              sa += 0.1 * Math.log2(1 + ShellState.getLauncherUsageCount(a.usageKey));
                            }
                            if (b.provider && b.provider.trackUsage && b.usageKey) {
                              sb += 0.1 * Math.log2(1 + ShellState.getLauncherUsageCount(b.usageKey));
                            }
                          }

                          return sb - sa;
                        });
      }
      _results = allResults;
    }

    _activeProvider = newActiveProvider;
    _selectedIndex = 0;
  }

  // ---------------------------------------------------------------
  // Provider registration — API kept identical for plugin providers
  // ---------------------------------------------------------------
  // Provider id -> instance, keyed by the explicit string passed here so the
  // views can look a provider up by a stable name (appsProvider etc.).
  function registerProvider(provider, id) {
    _providers.push(provider);
    provider.launcher = root;
    if (provider.init)
      provider.init();
    if (id) {
      _providersById[id] = provider;
      _providersById = _providersById; // trigger property change
    }
  }

  function registerProviderWithId(provider, id) {
    if (!id)
      return;
    registerProvider(provider, id);
  }

  function syncPluginProviders() {
    const registeredIds = LauncherProviderRegistry.getPluginProviders();
    let changed = false;

    // Remove providers that are no longer registered
    for (let existingId in _pluginProviderInstances) {
      if (registeredIds.indexOf(existingId) === -1) {
        const idx = _providers.indexOf(_pluginProviderInstances[existingId]);
        if (idx >= 0)
          _providers.splice(idx, 1);
        delete _pluginProviderInstances[existingId];
        Logger.d("Launcher", "Removed plugin provider:", existingId);
        changed = true;
      }
    }

    // Adopt persistent instances from the registry
    for (let i = 0; i < registeredIds.length; i++) {
      const providerId = registeredIds[i];
      if (!_pluginProviderInstances[providerId]) {
        const instance = LauncherProviderRegistry.getProviderInstance(providerId);
        if (instance) {
          _pluginProviderInstances[providerId] = instance;
          _providers.push(instance);
          instance.launcher = root;
          if (instance.init)
            instance.init();
          _providersById[providerId] = instance;
          _providersById = _providersById;
          Logger.d("Launcher", "Adopted plugin provider:", providerId);
          changed = true;
        }
      }
    }

    if (changed && root.isOpen) {
      updateResults();
    }
  }

  Connections {
    target: LauncherProviderRegistry
    function onPluginProviderRegistryUpdated() {
      root.syncPluginProviders();
    }
  }

  // ---------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------
  function clampIndex() {
    if (_selectedIndex >= _results.length)
      _selectedIndex = Math.max(0, _results.length - 1);
    if (_selectedIndex < 0)
      _selectedIndex = 0;
  }

  function selectNextWrapped() {
    _selectedIndex = LauncherNav.selectNextWrapped(_selectedIndex, _results.length, true);
  }

  function selectPreviousWrapped() {
    _selectedIndex = LauncherNav.selectPreviousWrapped(_selectedIndex, _results.length, true);
  }

  function selectFirst() {
    _selectedIndex = LauncherNav.selectFirst();
  }

  function selectLast() {
    _selectedIndex = LauncherNav.selectLast(_results.length);
  }

  function selectNextPage(entryHeight) {
    _selectedIndex = LauncherNav.selectNextPage(_selectedIndex, _results.length, entryHeight || rowHeight);
  }

  function selectPreviousPage(entryHeight) {
    _selectedIndex = LauncherNav.selectPreviousPage(_selectedIndex, _results.length, entryHeight || rowHeight);
  }

  // Column is preserved across rows and (for the free view) sections
  function selectNextRow(columns) {
    _selectedIndex = LauncherNav.selectNextRow(_selectedIndex, _results.length, Math.max(1, columns));
  }

  function selectPreviousRow(columns) {
    _selectedIndex = LauncherNav.selectPreviousRow(_selectedIndex, _results.length, Math.max(1, columns));
  }

  function selectNextColumn(columns) {
    _selectedIndex = LauncherNav.selectNextColumn(_selectedIndex, _results.length, Math.max(1, columns));
  }

  function selectPreviousColumn(columns) {
    _selectedIndex = LauncherNav.selectPreviousColumn(_selectedIndex, _results.length, Math.max(1, columns));
  }

  function selectIndex(index) {
    if (index >= 0 && index < _results.length)
      _selectedIndex = index;
  }

  // ---------------------------------------------------------------
  // Activation
  // ---------------------------------------------------------------
  function activate() {
    clampIndex();
    if (_results.length === 0 || !_results[_selectedIndex])
      return;

    const item = _results[_selectedIndex];
    const provider = item.provider || currentProvider;

    // Usage tracking for providers that opt in ("most used" sorting)
    if (Settings.data.appLauncher.sortByMostUsed && provider && provider.trackUsage && item.usageKey) {
      ShellState.recordLauncherUsage(item.usageKey);
    }

    // Auto-paste (clipboard provider)
    if (Settings.data.appLauncher.autoPasteClipboard && provider && provider.supportsAutoPaste && item.autoPasteText) {
      if (item.onAutoPaste)
        item.onAutoPaste();
      closeImmediately();
      Qt.callLater(() => {
                     ClipboardService.pasteText(item.autoPasteText);
                   });
      return;
    }

    if (item.onActivate)
      item.onActivate();
  }

  // Delete selected item (clipboard entries)
  function deleteSelected() {
    clampIndex();
    if (_selectedIndex >= 0 && _results && _results[_selectedIndex]) {
      const item = _results[_selectedIndex];
      const provider = item.provider || currentProvider;
      if (provider && provider.canDeleteItem && provider.canDeleteItem(item))
        provider.deleteItem(item);
    }
  }

  function checkKey(event, settingName) {
    return Keybinds.checkKey(event, settingName, Settings);
  }

  // ---------------------------------------------------------------
  // Providers — files and API untouched so plugin providers keep working
  // ---------------------------------------------------------------
  ApplicationsProvider {
    id: appsProvider
    Component.onCompleted: {
      registerProviderWithId(this, "appsProvider");
      Logger.d("Launcher", "Registered: ApplicationsProvider");
    }
  }

  ClipboardProvider {
    id: clipProvider
    Component.onCompleted: {
      if (Settings.data.appLauncher.enableClipboardHistory) {
        registerProviderWithId(this, "clipProvider");
        Logger.d("Launcher", "Registered: ClipboardProvider");
      }
    }
  }

  CommandProvider {
    id: cmdProvider
    Component.onCompleted: {
      registerProviderWithId(this, "cmdProvider");
      Logger.d("Launcher", "Registered: CommandProvider");
    }
  }

  EmojiProvider {
    id: emojiProvider
    Component.onCompleted: {
      registerProviderWithId(this, "emojiProvider");
      Logger.d("Launcher", "Registered: EmojiProvider");
    }
  }

  CalculatorProvider {
    id: calcProvider
    Component.onCompleted: {
      registerProviderWithId(this, "calcProvider");
      Logger.d("Launcher", "Registered: CalculatorProvider");
    }
  }

  SettingsProvider {
    id: settingsProvider
    Component.onCompleted: {
      registerProviderWithId(this, "settingsProvider");
      Logger.d("Launcher", "Registered: SettingsProvider");
    }
  }

  SessionProvider {
    id: sessionProvider
    Component.onCompleted: {
      registerProviderWithId(this, "sessionProvider");
      Logger.d("Launcher", "Registered: SessionProvider");
    }
  }

  WindowsProvider {
    id: windowsProvider
    Component.onCompleted: {
      registerProviderWithId(this, "windowsProvider");
      Logger.d("Launcher", "Registered: WindowsProvider");
    }
  }
}
