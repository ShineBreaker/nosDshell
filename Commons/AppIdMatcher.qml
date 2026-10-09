pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Shared appId/pin helpers for dock, taskbar, dock menu and workspace widget.
// The four call sites used to carry diverging copies of this family; the
// differences are parameterized so each caller keeps its current behaviour:
//   stripDesktopSuffix — the fashion dock normalizes pinned keys without the
//     ".desktop" suffix; bar-side callers keep raw IDs.
//   resolveEntry — strong match also resolves the appId through the desktop
//     entry heuristic (StartupWMClass != .desktop filename); the weak match
//     compares normalized IDs directly.
//   useDesktopEntryId — toggleAppPin stores the resolved desktop entry ID as
//     the pinned key (taskbar/dock menu); the workspace widget stores the raw
//     appId.
Singleton {
  id: root

  // Desktop entry ID resolution cache (cleared when DesktopEntries change)
  property var _desktopEntryIdCache: ({})

  Connections {
    target: DesktopEntries.applications

    function onValuesChanged() {
      root._desktopEntryIdCache = {};
    }
  }

  // Helper function to normalize app IDs for case-insensitive matching
  function normalizeAppId(appId, opts) {
    if (!appId || typeof appId !== 'string')
      return "";
    let id = appId.toLowerCase().trim();
    if (opts && opts.stripDesktopSuffix && id.endsWith(".desktop"))
      id = id.substring(0, id.length - 8);
    return id;
  }

  // Helper function to check if an app ID matches a pinned app (case-insensitive)
  function isAppIdPinned(appId, pinnedApps, opts) {
    if (!appId || !pinnedApps || pinnedApps.length === 0)
      return false;
    const normalizedId = normalizeAppId(appId, opts);
    // Direct match
    if (pinnedApps.some(pinnedId => normalizeAppId(pinnedId, opts) === normalizedId))
      return true;
    if (!opts || !opts.resolveEntry)
      return false;
    // Resolve via desktop entry lookup (handles StartupWMClass != .desktop filename)
    const resolved = resolveToDesktopEntryId(appId);
    if (resolved !== appId) {
      const normalizedResolved = normalizeAppId(resolved, opts);
      return pinnedApps.some(pinnedId => normalizeAppId(pinnedId, opts) === normalizedResolved);
    }
    return false;
  }

  // Helper function to check if an app is pinned against the dock settings
  function isAppPinned(appId, opts) {
    if (!appId)
      return false;
    return isAppIdPinned(appId, Settings.data.dock.pinnedApps || [], opts);
  }

  // Resolve a toplevel appId to its canonical .desktop entry ID via heuristic lookup.
  // This handles cases where the Wayland appId (e.g. "zen" from StartupWMClass)
  // differs from the .desktop filename (e.g. "zen-browser-bin").
  function resolveToDesktopEntryId(appId) {
    if (!appId)
      return appId;
    if (_desktopEntryIdCache.hasOwnProperty(appId))
      return _desktopEntryIdCache[appId];
    try {
      if (typeof DesktopEntries !== 'undefined' && DesktopEntries.heuristicLookup) {
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.id) {
          _desktopEntryIdCache[appId] = entry.id;
          return entry.id;
        }
      }
    } catch (e) {}
    _desktopEntryIdCache[appId] = appId;
    return appId;
  }

  // Helper function to get app name from desktop entry
  function getAppNameFromDesktopEntry(appId) {
    if (!appId)
      return appId;

    try {
      if (typeof DesktopEntries !== 'undefined' && DesktopEntries.heuristicLookup) {
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.name) {
          return entry.name;
        }
      }

      if (typeof DesktopEntries !== 'undefined' && DesktopEntries.byId) {
        const entry = DesktopEntries.byId(appId);
        if (entry && entry.name) {
          return entry.name;
        }
      }
    } catch (e)
      // Fall through to return original appId
    {}

    // Return original appId if we can't find a desktop entry
    return appId;
  }

  // Helper function to get desktop entry ID from an app ID
  function getDesktopEntryId(appId) {
    if (!appId)
      return appId;

    // Try to find the desktop entry using heuristic lookup
    if (typeof DesktopEntries !== 'undefined' && DesktopEntries.heuristicLookup) {
      try {
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.id) {
          return entry.id;
        }
      } catch (e)
        // Fall through to return original appId
      {}
    }

    // Try direct lookup
    if (typeof DesktopEntries !== 'undefined' && DesktopEntries.byId) {
      try {
        const entry = DesktopEntries.byId(appId);
        if (entry && entry.id) {
          return entry.id;
        }
      } catch (e)
        // Fall through to return original appId
      {}
    }

    // Return original appId if we can't find a desktop entry
    return appId;
  }

  // Helper function to toggle app pin/unpin
  function toggleAppPin(appId, opts) {
    if (!appId)
      return;

    // Get the desktop entry ID for consistent pinning
    const pinnedKey = opts && opts.useDesktopEntryId ? getDesktopEntryId(appId) : appId;
    const normalizedId = normalizeAppId(pinnedKey);

    let pinnedApps = (Settings.data.dock.pinnedApps || []).slice(); // Create a copy

    // Find existing pinned app with case-insensitive matching
    const existingIndex = pinnedApps.findIndex(pinnedId => normalizeAppId(pinnedId) === normalizedId);
    const isPinned = existingIndex >= 0;

    if (isPinned) {
      // Unpin: remove from array
      pinnedApps.splice(existingIndex, 1);
    } else {
      // Pin: add the pinned key to array
      pinnedApps.push(pinnedKey);
    }

    // Update the settings
    Settings.data.dock.pinnedApps = pinnedApps;
  }
}
