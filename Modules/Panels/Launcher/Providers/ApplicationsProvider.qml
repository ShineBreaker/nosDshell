import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.System

Item {
  id: root

  property var launcher: null
  property string name: I18n.tr("launcher.providers.applications")
  property bool handleSearch: true
  property var entries: []
  // All installed applications (unfiltered) — the DDE mini view's category list
  // filters this by DDE bucket.
  readonly property var allApps: (DesktopEntries.applications ? DesktopEntries.applications.values : []) || []
  property string supportedLayouts: "both"
  property bool isDefaultProvider: true // This provider handles empty search
  property bool ignoreDensity: false // Apps should scale with launcher density
  property bool trackUsage: true // Track usage frequency for "most used" sorting

  // Category support
  property string selectedCategory: "all"
  property bool showsCategories: true // Default to showing categories
  property var categories: ["all", "Pinned", "AudioVideo", "Chat", "Development", "Education", "Game", "Graphics", "Network", "Office", "System", "Misc", "WebBrowser"]
  property var availableCategories: ["all"] // Reactive property for available categories

  // DDE views select one of the 11 DDE buckets (ddeCategories); "all" is the
  // default every-apps view DDE opens on.
  property string ddeCategory: "all"

  property var categoryIcons: ({
                                 "all": "apps",
                                 "Pinned": "pin",
                                 "AudioVideo": "music",
                                 "Chat": "message-circle",
                                 "Development": "code",
                                 "Education": "school" // Includes Science
                                              ,
                                 "Game": "device-gamepad",
                                 "Graphics": "brush",
                                 "Network": "wifi",
                                 "Office": "file-text",
                                 "System": "device-desktop" // Includes Settings and Utility
                                           ,
                                 "Misc": "dots",
                                 "WebBrowser": "world"
                               })

  function getCategoryName(category) {
    const names = {
      "all": I18n.tr("launcher.categories.all"),
      "Pinned": I18n.tr("launcher.categories.pinned"),
      "AudioVideo": I18n.tr("launcher.categories.audiovideo"),
      "Chat": I18n.tr("launcher.categories.chat"),
      "Development": I18n.tr("launcher.categories.development"),
      "Education": I18n.tr("launcher.categories.education"),
      "Game": I18n.tr("launcher.categories.game"),
      "Graphics": I18n.tr("launcher.categories.graphics"),
      "Network": I18n.tr("common.network"),
      "Office": I18n.tr("launcher.categories.office"),
      "System": I18n.tr("launcher.categories.system"),
      "Misc": I18n.tr("launcher.categories.misc"),
      "WebBrowser": I18n.tr("launcher.categories.webbrowser")
    };
    return names[category] || getDDECategoryName(category);
  }

  // ---------------------------------------------------------------
  // DDE 15 categories (DESIGN §3.4.1). The 11 DDE buckets replace the
  // Noctalia category set in the fullscreen/mini DDE views; the legacy
  // lists above stay for the legacy panel and for search filtering.
  // Mapping mirrors deepin-daemon launcher/category.go (xCategories).
  // ---------------------------------------------------------------
  readonly property var ddeCategories: ["Internet", "Chat", "Music", "Video", "Graphics", "Game", "Office", "Reading", "Development", "System", "Others"]

  // desktop-entry Categories (lowercase) -> DDE bucket; unmapped keys fall
  // back to the most frequent mapped key, ignoring Others
  readonly property var ddeCategoryMap: ({
                                           "network": "Internet",
                                           "webbrowser": "Internet",
                                           "email": "Internet",
                                           "instantmessaging": "Chat",
                                           "chat": "Chat",
                                           "audio": "Music",
                                           "music": "Music",
                                           "player": "Music",
                                           "video": "Video",
                                           "audiovideo": "Video",
                                           "graphics": "Graphics",
                                           "2dgraphics": "Graphics",
                                           "3dgraphics": "Graphics",
                                           "photography": "Graphics",
                                           "game": "Game",
                                           "actiongame": "Game",
                                           "adventuregame": "Game",
                                           "arcadegame": "Game",
                                           "boardgame": "Game",
                                           "office": "Office",
                                           "wordprocessor": "Office",
                                           "spreadsheet": "Office",
                                           "science": "Office",
                                           "education": "Office",
                                           "news": "Reading",
                                           "translation": "Reading",
                                           "development": "Development",
                                           "ide": "Development",
                                           "webdevelopment": "Development",
                                           "system": "System",
                                           "settings": "System",
                                           "utility": "System",
                                           "filemanager": "System",
                                           "terminalemulator": "System"
                                         })

  function getDDECategoryName(category) {
    const names = {
      // No bucket selected yet: the nav and the pinned title say "all apps"
      // rather than leaking the internal key (miniframeswitchbtn.cpp:52-70).
      "all": I18n.tr("launcher.dde.all-apps"),
      "Internet": I18n.tr("launcher.dde.categories.internet"),
      "Chat": I18n.tr("launcher.dde.categories.chat"),
      "Music": I18n.tr("launcher.dde.categories.music"),
      "Video": I18n.tr("launcher.dde.categories.video"),
      "Graphics": I18n.tr("launcher.dde.categories.graphics"),
      "Game": I18n.tr("launcher.dde.categories.game"),
      "Office": I18n.tr("launcher.dde.categories.office"),
      "Reading": I18n.tr("launcher.dde.categories.reading"),
      "Development": I18n.tr("launcher.dde.categories.development"),
      "System": I18n.tr("launcher.dde.categories.system"),
      "Others": I18n.tr("launcher.dde.categories.others")
    };
    return names[category] || category;
  }

  // Primary DDE bucket for an app (entry.Categories).
  // Single category -> its mapping; multiple -> most frequent, Others ignored.
  function getDDECategory(app) {
    if (!app)
      return "Others";

    const raw = getAppCategories(app);
    if (raw.length === 0)
      return "Others";

    if (raw.length === 1) {
      const mapped = ddeCategoryMap[raw[0].toLowerCase()];
      return mapped || "Others";
    }

    const counts = {};
    let best = "Others";
    let bestCount = 0;
    for (const cat of raw) {
      const mapped = ddeCategoryMap[cat.toLowerCase()];
      if (!mapped || mapped === "Others")
        continue;
      counts[mapped] = (counts[mapped] || 0) + 1;
      if (counts[mapped] > bestCount) {
        bestCount = counts[mapped];
        best = mapped;
      }
    }
    return best;
  }

  function appMatchesDDECategory(app, category) {
    if (category === "all")
      return true;
    if (category === "Others")
      return getDDECategory(app) === "Others";
    return getDDECategory(app) === category;
  }

  function init() {
    loadApplications();
    migrateLegacyUsageKeys();
  }

  function onOpened() {
    // Just update available categories in case pinned apps changed
    updateAvailableCategories();
    // Default to Pinned if there are pinned apps, otherwise all
    if (availableCategories.includes("Pinned")) {
      selectedCategory = "Pinned";
    } else {
      selectedCategory = "all";
    }
    // Set category mode initially (will be updated when getResults is called)
    showsCategories = true;
  }

  // Reload applications when desktop entries change on disk. DesktopEntries
  // emits valuesChanged once per discovered entry during its async scan, so
  // reloads are debounced — reloading the full list per emission is O(n²) and
  // stalls the UI thread for minutes on a cold start.
  Timer {
    id: rescanDebounce
    interval: 400
    onTriggered: {
      Logger.d("ApplicationsProvider", "Desktop entries changed, reloading applications");
      loadApplications();
    }
  }

  Connections {
    target: typeof DesktopEntries !== 'undefined' ? DesktopEntries.applications : null
    function onValuesChanged() {
      rescanDebounce.restart();
    }
  }

  function selectCategory(category) {
    selectedCategory = category;
    if (launcher) {
      launcher.updateResults();
    }
  }

  // DDE views select one of the 11 buckets; the legacy selectedCategory is
  // left untouched so switching back to the legacy view keeps its state.
  function selectDDECategory(category) {
    if (ddeCategory !== category) {
      ddeCategory = category;
    }
    if (launcher) {
      launcher.updateResults();
    }
  }

  function getAppCategories(app) {
    if (!app)
      return [];

    const result = [];

    if (app.categories) {
      if (Array.isArray(app.categories)) {
        for (let cat of app.categories) {
          if (cat && cat.trim && cat.trim() !== '') {
            result.push(cat.trim());
          } else if (cat && typeof cat === 'string' && cat.trim() !== '') {
            result.push(cat.trim());
          }
        }
      } else if (typeof app.categories === 'string') {
        const cats = app.categories.split(';').filter(c => c && c.trim() !== '');
        for (let cat of cats) {
          const trimmed = cat.trim();
          if (trimmed && !result.includes(trimmed)) {
            result.push(trimmed);
          }
        }
      } else if (app.categories.length !== undefined) {
        try {
          for (let i = 0; i < app.categories.length; i++) {
            const cat = app.categories[i];
            if (cat && cat.trim && typeof cat.trim === 'function' && cat.trim() !== '') {
              result.push(cat.trim());
            } else if (cat && typeof cat === 'string' && cat.trim() !== '') {
              result.push(cat.trim());
            }
          }
        } catch (e) {}
      }
    }

    if (app.Categories) {
      const cats = app.Categories.split(';').filter(c => c && c.trim() !== '');
      for (let cat of cats) {
        const trimmed = cat.trim();
        if (trimmed && !result.includes(trimmed)) {
          result.push(trimmed);
        }
      }
    }

    return result;
  }

  function getAppCategory(app) {
    const appCategories = getAppCategories(app);
    if (appCategories.length === 0)
      return null;

    const priorityCategories = ["AudioVideo", "Chat", "WebBrowser", "Game", "Development", "Graphics", "Office", "Education", "System", "Network", "Misc"];

    for (let cat of appCategories) {
      if (cat === "AudioVideo" || cat === "Audio" || cat === "Video") {
        return "AudioVideo";
      }
    }

    if (appCategories.includes("Chat") || appCategories.includes("InstantMessaging")) {
      return "Chat";
    }

    if (appCategories.includes("WebBrowser")) {
      return "WebBrowser";
    }

    // Map Science to Education
    if (appCategories.includes("Science")) {
      return "Education";
    }

    // Map Settings to System
    if (appCategories.includes("Settings")) {
      return "System";
    }

    // Map Utility to System
    if (appCategories.includes("Utility")) {
      return "System";
    }

    for (let priorityCat of priorityCategories) {
      if (appCategories.includes(priorityCat) && root.categories.includes(priorityCat)) {
        return priorityCat;
      }
    }

    return "Misc";
  }

  // Helper function to normalize app IDs for case-insensitive matching
  function normalizeAppId(appId) {
    if (!appId || typeof appId !== 'string')
      return "";
    return appId.toLowerCase().trim();
  }

  // Helper function to check if an app is pinned
  function isAppPinned(app) {
    if (!app)
      return false;
    const pinnedApps = Settings.data.appLauncher.pinnedApps || [];
    const appId = getAppKey(app);
    const normalizedId = normalizeAppId(appId);
    return pinnedApps.some(pinnedId => normalizeAppId(pinnedId) === normalizedId);
  }

  function appMatchesCategory(app, category) {
    // Check if app matches the selected category
    if (category === "all")
      return true;

    // Handle Pinned category separately
    if (category === "Pinned") {
      return isAppPinned(app);
    }

    // Get the primary category for this app (first matching standard category)
    const primaryCategory = getAppCategory(app);

    // If app has no matching standard category, don't show it in any category (only in "all")
    if (!primaryCategory)
      return false;

    // Map Audio/Video to AudioVideo
    if (category === "AudioVideo") {
      const appCategories = getAppCategories(app);
      // Show if app has AudioVideo, Audio, or Video
      return appCategories.includes("AudioVideo") || appCategories.includes("Audio") || appCategories.includes("Video");
    }

    // Map Science to Education
    if (category === "Education") {
      const appCategories = getAppCategories(app);
      return appCategories.includes("Education") || appCategories.includes("Science");
    }

    // Map Settings and Utility to System
    if (category === "System") {
      const appCategories = getAppCategories(app);
      return appCategories.includes("System") || appCategories.includes("Settings") || appCategories.includes("Utility");
    }

    // Only show app in its primary category to avoid overlap
    // This ensures each app appears in exactly one category tab
    return category === primaryCategory;
  }

  function getAvailableCategories() {
    const categorySet = new Set();
    let hasAudioVideo = false;
    let hasEducation = false;
    let hasSystem = false;
    let hasPinned = false;

    // Check if there are any pinned apps
    const pinnedApps = Settings.data.appLauncher.pinnedApps || [];
    if (pinnedApps.length > 0) {
      // Verify that at least one pinned app exists in entries
      for (let app of entries) {
        if (isAppPinned(app)) {
          hasPinned = true;
          break;
        }
      }
    }

    for (let app of entries) {
      const appCategories = getAppCategories(app);
      const primaryCategory = getAppCategory(app);

      if (appCategories.includes("AudioVideo") || appCategories.includes("Audio") || appCategories.includes("Video")) {
        hasAudioVideo = true;
      } else if (appCategories.includes("Education") || appCategories.includes("Science")) {
        hasEducation = true;
      } else if (appCategories.includes("System") || appCategories.includes("Settings") || appCategories.includes("Utility")) {
        hasSystem = true;
      } else if (primaryCategory && root.categories.includes(primaryCategory)) {
        categorySet.add(primaryCategory);
      }
    }

    const result = [];

    // Add Pinned category first if there are pinned apps
    if (hasPinned) {
      result.push("Pinned");
    }

    result.push("all");

    if (hasAudioVideo) {
      categorySet.add("AudioVideo");
    }
    if (hasEducation) {
      categorySet.add("Education");
    }
    if (hasSystem) {
      categorySet.add("System");
    }

    for (let cat of root.categories) {
      if (cat !== "all" && cat !== "Pinned" && cat !== "Misc" && categorySet.has(cat)) {
        result.push(cat);
      }
    }

    if (categorySet.has("Misc")) {
      result.push("Misc");
    }

    if (result.length === 1) {
      const fallback = root.categories.filter(c => c !== "Misc");
      fallback.push("Misc");
      return fallback;
    }

    return result;
  }

  function loadApplications() {
    if (typeof DesktopEntries === 'undefined') {
      Logger.w("ApplicationsProvider", "DesktopEntries service not available");
      return;
    }

    const allApps = DesktopEntries.applications.values || [];
    const seen = new Map(); // Map of appId -> exec command

    entries = allApps.filter(app => {
                               if (!app || app.noDisplay || app.hidden)
                               return false;

                               const appId = app.id || app.name;
                               const execCmd = getExecutableName(app);

                               // Check if we've seen this app ID before
                               if (seen.has(appId)) {
                                 const previousExec = seen.get(appId);

                                 // If exec is different, it's a legitimate different entry - keep it
                                 if (previousExec !== execCmd) {
                                   Logger.d("ApplicationsProvider", `Keeping variant of ${appId}: ${execCmd} (differs from ${previousExec})`);
                                   // Add with modified ID to make it unique
                                   app.id = `${appId}_${execCmd}`;
                                   seen.set(app.id, execCmd);
                                   return true;
                                 }

                                 // Same appId AND same exec = true duplicate, skip it
                                 Logger.d("ApplicationsProvider", `Skipping duplicate: ${appId}`);
                                 return false;
                               }

                               seen.set(appId, execCmd);
                               return true;
                             }).map(app => {
                                      app.executableName = getExecutableName(app);
                                      return app;
                                    });

    Logger.d("ApplicationsProvider", `Loaded ${entries.length} applications`);
    updateAvailableCategories();
    // Entries can be (re)loaded after the launcher already rendered its last
    // result set — refresh the view so a late XDG scan is not invisible.
    if (launcher && launcher.updateResults)
      launcher.updateResults();
  }

  function updateAvailableCategories() {
    availableCategories = getAvailableCategories();
  }

  Connections {
    target: Settings.data.appLauncher
    function onPinnedAppsChanged() {
      const wasViewingPinned = selectedCategory === "Pinned";
      updateAvailableCategories();

      // If we were viewing Pinned category and it's no longer available, switch to "all"
      if (wasViewingPinned && !availableCategories.includes("Pinned")) {
        selectedCategory = "all";
      }

      // Update results if we're currently viewing the Pinned category
      if (selectedCategory === "Pinned" && launcher) {
        launcher.updateResults();
      } else if (wasViewingPinned && selectedCategory === "all" && launcher) {
        // Also update results when switching to "all"
        launcher.updateResults();
      }
    }
  }

  function getExecutableName(app) {
    if (!app)
      return "";

    // Try to get executable name from command array
    if (app.command && Array.isArray(app.command) && app.command.length > 0) {
      const cmd = app.command[0];
      // Extract just the executable name from the full path
      const parts = cmd.split('/');
      const executable = parts[parts.length - 1];
      // Remove any arguments or parameters
      return executable.split(' ')[0];
    }

    // Try to get from exec property if available
    if (app.exec) {
      const parts = app.exec.split('/');
      const executable = parts[parts.length - 1];
      return executable.split(' ')[0];
    }

    // Fallback to app id (desktop file name without .desktop)
    if (app.id) {
      return app.id.replace('.desktop', '');
    }

    return "";
  }

  function getResults(query) {
    if (!entries || entries.length === 0)
      return [];

    // Set category mode based on whether there's a query
    const isSearching = !!(query && query.trim() !== "");
    showsCategories = !isSearching;

    // Filter by category only when NOT searching.
    // DDE views (displayMode/fullscreen/mini) use the 11-bucket filtering;
    // the legacy panel keeps the Noctalia category set.
    const useDDECategories = Settings.data.appLauncher.displayMode === "category" || Settings.data.appLauncher.mode === "mini" || Settings.data.appLauncher.mode === "fullscreen";

    let filteredEntries = entries;
    if (!isSearching) {
      if (useDDECategories) {
        filteredEntries = entries.filter(app => appMatchesDDECategory(app, ddeCategory));
      } else if (selectedCategory && selectedCategory !== "all") {
        filteredEntries = entries.filter(app => appMatchesCategory(app, selectedCategory));
      }
    }

    if (!query || query.trim() === "") {
      // Return filtered apps, optionally sorted by usage
      let sorted;
      if (Settings.data.appLauncher.sortByMostUsed) {
        sorted = filteredEntries.slice().sort((a, b) => {
                                                // Pinned first
                                                const aPinned = isAppPinned(a);
                                                const bPinned = isAppPinned(b);
                                                if (aPinned !== bPinned)
                                                return aPinned ? -1 : 1;

                                                const ua = getUsageCount(a);
                                                const ub = getUsageCount(b);
                                                if (ub !== ua)
                                                return ub - ua;
                                                return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
                                              });
      } else {
        sorted = filteredEntries.slice().sort((a, b) => {
                                                const aPinned = isAppPinned(a);
                                                const bPinned = isAppPinned(b);
                                                if (aPinned !== bPinned)
                                                return aPinned ? -1 : 1;
                                                return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
                                              });
      }
      return sorted.map(app => createResultEntry(app));
    }

    // Use fuzzy search if available, fallback to simple search
    if (typeof FuzzySort !== 'undefined') {
      const fuzzyResults = FuzzySort.go(query, filteredEntries, {
                                          "keys": ["name", "comment", "genericName", "executableName"],
                                          "limit": 20
                                        });

      // Sort pinned first within fuzzy results while preserving fuzzysort order otherwise
      const pinned = [];
      const nonPinned = [];
      for (const r of fuzzyResults) {
        const app = r.obj;
        if (isAppPinned(app))
          pinned.push(r);
        else
          nonPinned.push(r);
      }
      return pinned.concat(nonPinned).map(result => createResultEntry(result.obj, result.score));
    } else {
      // Fallback to simple search
      const searchTerm = query.toLowerCase();
      return filteredEntries.filter(app => {
                                      const name = (app.name || "").toLowerCase();
                                      const comment = (app.comment || "").toLowerCase();
                                      const generic = (app.genericName || "").toLowerCase();
                                      const executable = getExecutableName(app).toLowerCase();
                                      return name.includes(searchTerm) || comment.includes(searchTerm) || generic.includes(searchTerm) || executable.includes(searchTerm);
                                    }).sort((a, b) => {
                                              // Prioritize name matches, then executable matches
                                              const aName = a.name.toLowerCase();
                                              const bName = b.name.toLowerCase();
                                              const aExecutable = getExecutableName(a).toLowerCase();
                                              const bExecutable = getExecutableName(b).toLowerCase();
                                              const aStarts = aName.startsWith(searchTerm);
                                              const bStarts = bName.startsWith(searchTerm);
                                              const aExecStarts = aExecutable.startsWith(searchTerm);
                                              const bExecStarts = bExecutable.startsWith(searchTerm);

                                              // Prioritize name matches first
                                              if (aStarts && !bStarts)
                                              return -1;
                                              if (!aStarts && bStarts)
                                              return 1;

                                              // Then prioritize executable matches
                                              if (aExecStarts && !bExecStarts)
                                              return -1;
                                              if (!aExecStarts && bExecStarts)
                                              return 1;

                                              return aName.localeCompare(bName);
                                            }).slice(0, 20).map(app => createResultEntry(app));
    }
  }

  function createResultEntry(app, score) {
    return {
      "appId": getAppKey(app),
      "usageKey": getAppKey(app),
      "name": app.name || "Unknown",
      "description": app.genericName || app.comment || "",
      "icon": app.icon || "application-x-executable",
      "isImage": false,
      "_score": (score !== undefined ? score : 0),
      "provider": root,
      "onActivate": function () {
        // Close the launcher/SmartPanel immediately without any animations.
        // Ensures we are not preventing the future focusing of the app
        launcher.closeImmediately();

        // Defer execution to next event loop iteration to ensure panel is fully closed
        Qt.callLater(() => {
                       Logger.d("ApplicationsProvider", `Launching: ${app.name} (App ID: ${app.id || "unknown"})`);

                       const execString = (app.exec !== undefined && app.exec !== null) ? String(app.exec) : "";
                       const commandArgs = Array.isArray(app.command) ? app.command : (app.command && app.command.length !== undefined) ? Array.from(app.command) : [];
                       let hasQuotedArgs = execString.includes("\"") || execString.includes("'");
                       let hasSpaceArgs = false;
                       if (!hasQuotedArgs) {
                         hasQuotedArgs = commandArgs.some(arg => {
                                                            const text = String(arg);
                                                            return text.includes("\"") || text.includes("'");
                                                          });
                       }
                       if (!hasSpaceArgs) {
                         hasSpaceArgs = commandArgs.some(arg => String(arg).includes(" "));
                       }
                       if (app.execute && (hasQuotedArgs || hasSpaceArgs)) {
                         Logger.d("ApplicationsProvider", `Detected quoted/space arguments in Exec for ${app.name}, using app.execute()`);
                         app.execute();
                         return;
                       }

                       if (Settings.data.appLauncher.customLaunchPrefixEnabled && Settings.data.appLauncher.customLaunchPrefix.trim() !== "") {
                         // Use custom launch prefix
                         const prefix = Settings.data.appLauncher.customLaunchPrefix.trim().split(" ");
                         Logger.d("ApplicationsProvider", `Using custom launch prefix: ${Settings.data.appLauncher.customLaunchPrefix.trim()}`);

                         if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
                           const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
                           const command = prefix.concat(terminal.concat(app.command));
                           Logger.d("ApplicationsProvider", `Executing command (with prefix and terminal): ${command.join(" ")}`);
                           Quickshell.execDetached(command);
                         } else {
                           const command = prefix.concat(app.command);
                           Logger.d("ApplicationsProvider", `Executing command (with prefix): ${command.join(" ")}`);
                           Quickshell.execDetached(command);
                         }
                       } else {
                         if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
                           Logger.d("ApplicationsProvider", "Executing terminal app manually: " + app.name);
                           const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
                           const command = terminal.concat(app.command);
                           Logger.d("ApplicationsProvider", "Executing command (manual terminal): " + command.join(" "));
                           CompositorService.spawn(command);
                         } else if (app.command && app.command.length > 0) {
                           Logger.d("ApplicationsProvider", "Executing command: " + app.command.join(" "));
                           CompositorService.spawn(app.command);
                         } else if (app.execute) {
                           Logger.d("ApplicationsProvider", "Calling app.execute() for: " + app.name);
                           app.execute();
                         } else {
                           Logger.w("ApplicationsProvider", `Could not launch: ${app.name}. No valid launch method.`);
                         }
                       }
                     });
      }
    };
  }

  // -------------------------
  // Item actions for launcher delegate
  function getItemActions(item) {
    if (!item || !item.appId)
      return [];
    return [
          {
            "icon": isAppPinned({
                                  "id": item.appId
                                }) ? "unpin" : "pin",
            "tooltip": isAppPinned({
                                     "id": item.appId
                                   }) ? I18n.tr("common.unpin") : I18n.tr("common.pin"),
            "action": function () {
              togglePin(item.appId);
            }
          }
        ];
  }

  // 产品语义:启动器 Pinned 分类与任务栏 pinnedApps 是两套独立存储(不重构)。
  // 置顶 ID 以 normalizeAppId(小写+trim)比对,与 DockMenu.getDesktopEntryId
  // 归一化后的 desktop entry ID 同一口径。启动器置顶单向同步到 dock:
  // pin 时若 dock 缺该 ID 则追加;launcher 取消置顶不碰 dock(dock 由 DockMenu 单独管理)。
  function togglePin(appId) {
    if (!appId)
      return;
    const normalizedId = normalizeAppId(appId);
    let arr = (Settings.data.appLauncher.pinnedApps || []).slice();
    const idx = arr.findIndex(pinnedId => normalizeAppId(pinnedId) === normalizedId);
    if (idx >= 0) {
      arr.splice(idx, 1);
    } else {
      arr.push(appId);
      try {
        const dockPinned = (Settings.data.dock.pinnedApps || []).slice();
        const dockHit = dockPinned.some(pinnedId => normalizeAppId(pinnedId) === normalizedId);
        if (!dockHit) {
          dockPinned.push(appId);
          Settings.data.dock.pinnedApps = dockPinned;
        }
      } catch (e) {
        Logger.w("ApplicationsProvider", "sync pin to dock failed: " + e);
      }
    }
    Settings.data.appLauncher.pinnedApps = arr;
  }

  // -------------------------
  // Usage tracking helpers
  function getAppKey(app) {
    if (app && app.id)
      return String(app.id);
    if (app && app.command && app.command.join)
      return app.command.join(" ");
    return String(app && app.name ? app.name : "unknown");
  }

  function getUsageCount(app) {
    return ShellState.getLauncherUsageCount(getAppKey(app));
  }

  // Migrate legacy command-based usage keys to canonical app-id keys at startup
  function migrateLegacyUsageKeys() {
    for (let i = 0; i < entries.length; i++) {
      const app = entries[i];
      if (app && app.id && app.command && app.command.join) {
        const key = getAppKey(app);
        const legacyKey = app.command.join(" ");
        if (legacyKey !== key && ShellState.getLauncherUsageCount(legacyKey) > 0) {
          ShellState.migrateLauncherUsage(legacyKey, key);
          Logger.d("ApplicationsProvider", `Migrated usage: "${legacyKey}" → "${key}"`);
        }
      }
    }
  }
}
