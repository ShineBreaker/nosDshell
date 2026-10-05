import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Keyboard

// Niri backend implemented on top of `niri msg --json` instead of the
// (archived) noctalia-qs Quickshell.Niri module. The event stream replays the
// full workspace/window/keyboard-layout state on connect, so one long-lived
// process plus one-shot queries for outputs cover the whole data surface.
Item {
  id: root

  property int floatingWindowPosition: Number.MAX_SAFE_INTEGER

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1

  property bool overviewActive: false

  property var keyboardLayouts: []

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  property var outputCache: ({})
  property var workspaceCache: ({})

  property var _keyboardLayoutNames: []
  property var _rawWindows: []
  property bool _workspacesDirty: false
  property bool _windowsDirty: false

  function initialize() {
    outputsQuery.running = true;
    eventStream.running = true;

    Logger.i("NiriService", "Service started (niri msg IPC)");
  }

  // All actions go through `niri msg action` (same argv the C++ module used).
  function dispatch(args) {
    Quickshell.execDetached(["niri", "msg", "action"].concat(args));
  }

  // Long-lived event stream; niri sends the full state first, then deltas.
  Process {
    id: eventStream
    command: ["niri", "msg", "--json", "event-stream"]
    running: false

    stdout: SplitParser {
      onRead: line => {
                if (!line || line.length === 0)
                return;
                var ev;
                try {
                  ev = JSON.parse(line);
                } catch (e) {
                  return;
                }
                root.handleEvent(ev);
              }
    }

    onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0) {
                  Logger.w("NiriService", "event-stream exited with code", exitCode, "- retrying");
                  streamRetry.restart();
                }
              }
  }

  Timer {
    id: streamRetry
    interval: 2000
    repeat: false
    onTriggered: {
      outputsQuery.running = true;
      eventStream.running = true;
    }
  }

  // Outputs are not replayed by the event stream; query them directly.
  Process {
    id: outputsQuery
    command: ["niri", "msg", "--json", "outputs"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.applyOutputs(JSON.parse(text));
        } catch (e) {
          Logger.w("NiriService", "Failed to parse outputs:", e);
        }
      }
    }
  }

  // One-shot refresh queries used for events that only carry a delta.
  Process {
    id: workspacesQuery
    command: ["niri", "msg", "--json", "workspaces"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.applyWorkspaces(JSON.parse(text));
        } catch (e) {
          Logger.w("NiriService", "Failed to parse workspaces:", e);
        }
      }
    }
    onExited: {
      if (root._workspacesDirty)
        refreshTimer.restart();
    }
  }

  Process {
    id: windowsQuery
    command: ["niri", "msg", "--json", "windows"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.applyWindows(JSON.parse(text));
        } catch (e) {
          Logger.w("NiriService", "Failed to parse windows:", e);
        }
      }
    }
    onExited: {
      if (root._windowsDirty)
        refreshTimer.restart();
    }
  }

  // Coalesce bursty events into a single refresh cycle.
  Timer {
    id: refreshTimer
    interval: 80
    repeat: false
    onTriggered: {
      if (root._workspacesDirty) {
        if (workspacesQuery.running) {
          restart();
        } else {
          root._workspacesDirty = false;
          workspacesQuery.running = true;
        }
      }
      if (root._windowsDirty) {
        if (windowsQuery.running) {
          restart();
        } else {
          root._windowsDirty = false;
          windowsQuery.running = true;
        }
      }
    }
  }

  function handleEvent(ev) {
    if (!ev)
      return;

    if (ev.WorkspacesChanged) {
      applyWorkspaces(ev.WorkspacesChanged.workspaces);
    } else if (ev.WindowsChanged) {
      applyWindows(ev.WindowsChanged.windows);
    } else if (ev.WorkspaceActivated !== undefined || ev.WorkspaceActiveWindowChanged !== undefined || ev.WorkspaceUrgencyChanged !== undefined) {
      _workspacesDirty = true;
      _windowsDirty = true;
      refreshTimer.restart();
    } else if (ev.WindowOpenedOrChanged !== undefined || ev.WindowClosed !== undefined || ev.WindowFocusChanged !== undefined) {
      _windowsDirty = true;
      refreshTimer.restart();
    } else if (ev.KeyboardLayoutsChanged) {
      applyKeyboardLayouts(ev.KeyboardLayoutsChanged.keyboard_layouts);
    } else if (ev.KeyboardLayoutSwitched !== undefined) {
      const name = _keyboardLayoutNames[ev.KeyboardLayoutSwitched.idx];
      if (name) {
        KeyboardLayoutService.setCurrentLayout(name);
      }
      Logger.d("NiriService", "Keyboard layout switched:", name || ev.KeyboardLayoutSwitched.idx);
    } else if (ev.OverviewOpenedOrClosed !== undefined) {
      overviewActive = ev.OverviewOpenedOrClosed.is_open;
    } else if (ev.OutputsChanged) {
      applyOutputs(ev.OutputsChanged.outputs);
      queryDisplayScales();
    } else if (ev.OutputConnected !== undefined || ev.OutputRemoved !== undefined) {
      outputsQuery.running = true;
    }
    // ConfigLoaded, CastsChanged, WindowFocusTimestampChanged etc. are ignored.
  }

  function applyKeyboardLayouts(kbd) {
    if (!kbd)
      return;
    _keyboardLayoutNames = kbd.names || [];
    keyboardLayouts = _keyboardLayoutNames;
    const name = _keyboardLayoutNames[kbd.current_idx];
    if (name) {
      KeyboardLayoutService.setCurrentLayout(name);
    }
    Logger.d("NiriService", "Keyboard layouts changed:", keyboardLayouts.toString());
  }

  function applyOutputs(niriOutputs) {
    outputCache = {};
    if (!niriOutputs)
      return;

    for (var name in niriOutputs) {
      const output = niriOutputs[name];
      const logical = output.logical || {};
      const mode = (output.modes && output.current_mode !== undefined) ? output.modes[output.current_mode] : null;
      const phys = output.physical_size || [0, 0];
      outputCache[output.name] = {
        "name": output.name,
        "connected": true,
        "scale": logical.scale || 1.0,
        "width": logical.width || 0,
        "height": logical.height || 0,
        "x": logical.x || 0,
        "y": logical.y || 0,
        "physical_width": phys[0] || 0,
        "physical_height": phys[1] || 0,
        "refresh_rate": mode ? (mode.refresh_rate || 0) / 1000.0 : 0,
        "vrr_supported": output.vrr_supported || false,
        "vrr_enabled": output.vrr_enabled || false,
        "transform": logical.transform || "Normal"
      };
    }
  }

  function _workspaceSortKey(ws) {
    const output = outputCache[ws.output];
    // Sort by output position first (like windows), then by workspace index.
    return ((output ? output.x : 0) * 100000 + (output ? output.y : 0)) * 1000 + ws.idx;
  }

  function applyWorkspaces(niriWorkspaces) {
    if (!niriWorkspaces)
      return;
    workspaceCache = {};

    const workspacesList = [];
    for (var i = 0; i < niriWorkspaces.length; i++) {
      const ws = niriWorkspaces[i];
      const wsData = {
        "id": ws.id,
        "idx": ws.idx,
        "name": ws.name,
        "output": ws.output,
        "isFocused": ws.is_focused,
        "isActive": ws.is_active,
        "isUrgent": ws.is_urgent,
        "isOccupied": ws.active_window_id !== null || _hasWindowOnWorkspace(ws.id)
      };
      workspacesList.push(wsData);
      workspaceCache[ws.id] = wsData;
    }

    workspacesList.sort((a, b) => _workspaceSortKey(a) - _workspaceSortKey(b));

    workspaces.clear();
    for (var j = 0; j < workspacesList.length; j++) {
      workspaces.append(workspacesList[j]);
    }
    workspaceChanged();
  }

  function _hasWindowOnWorkspace(workspaceId) {
    for (var i = 0; i < _rawWindows.length; i++) {
      if (_rawWindows[i].workspace_id === workspaceId)
        return true;
    }
    return false;
  }

  function getWindowOutput(win) {
    for (var i = 0; i < workspaces.count; i++) {
      if (workspaces.get(i).id === win.workspaceId) {
        return workspaces.get(i).output;
      }
    }
    return null;
  }

  function toSortedWindowList(windowList) {
    return windowList.map(win => {
                            const workspace = workspaceCache[win.workspaceId];
                            const output = (workspace && workspace.output) ? outputCache[workspace.output] : null;

                            return {
                              window: win,
                              workspaceIdx: workspace ? workspace.idx : 0,
                              outputX: output ? output.x : 0,
                              outputY: output ? output.y : 0
                            };
                          }).sort((a, b) => {
                                    // Sort by output position first
                                    if (a.outputX !== b.outputX) {
                                      return a.outputX - b.outputX;
                                    }
                                    if (a.outputY !== b.outputY) {
                                      return a.outputY - b.outputY;
                                    }
                                    // Then by workspace index
                                    if (a.workspaceIdx !== b.workspaceIdx) {
                                      return a.workspaceIdx - b.workspaceIdx;
                                    }
                                    // Then by window position
                                    if (a.window.position.x !== b.window.position.x) {
                                      return a.window.position.x - b.window.position.x;
                                    }
                                    if (a.window.position.y !== b.window.position.y) {
                                      return a.window.position.y - b.window.position.y;
                                    }
                                    // Finally by window ID to ensure consistent ordering
                                    return a.window.id - b.window.id;
                                  }).map(info => info.window);
  }

  function applyWindows(niriWindows) {
    if (!niriWindows)
      return;
    _rawWindows = niriWindows;
    const windowsList = [];

    for (var i = 0; i < niriWindows.length; i++) {
      const win = niriWindows[i];
      const pos = (win.layout && win.layout.pos_in_scrolling_layout) || [0, 0];
      windowsList.push({
                         "id": win.id,
                         "title": win.title || "",
                         "appId": win.app_id || "",
                         "workspaceId": win.workspace_id || -1,
                         "isFocused": win.is_focused,
                         "output": getWindowOutput({
                                                     "workspaceId": win.workspace_id
                                                   }) || "",
                         "position": {
                           "x": win.is_floating ? floatingWindowPosition : pos[0],
                           "y": win.is_floating ? floatingWindowPosition : pos[1]
                         }
                       });
    }

    windows = toSortedWindowList(windowsList);
    safeUpdateFocusedWindow();
    windowListChanged();
    activeWindowChanged();
  }

  function safeUpdateFocusedWindow() {
    focusedWindowIndex = -1;
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].isFocused) {
        focusedWindowIndex = i;
        break;
      }
    }
  }

  function queryDisplayScales() {
    if (CompositorService && CompositorService.onDisplayScalesUpdated) {
      CompositorService.onDisplayScalesUpdated(outputCache);
    }
  }

  function switchToWorkspace(workspace) {
    try {
      dispatch(["focus-workspace", workspace.idx.toString()]);
    } catch (e) {
      Logger.e("NiriService", "Failed to switch workspace:", e);
    }
  }

  function scrollWorkspaceContent(direction) {
    try {
      var action = direction < 0 ? "focus-column-left" : "focus-column-right";
      dispatch([action]);
    } catch (e) {
      Logger.e("NiriService", "Failed to scroll workspace content:", e);
    }
  }

  function focusWindow(window) {
    try {
      dispatch(["focus-window", "--id", window.id.toString()]);
    } catch (e) {
      Logger.e("NiriService", "Failed to switch window:", e);
    }
  }

  function closeWindow(window) {
    try {
      dispatch(["close-window", "--id", window.id.toString()]);
    } catch (e) {
      Logger.e("NiriService", "Failed to close window:", e);
    }
  }

  function turnOffMonitors() {
    try {
      dispatch(["power-off-monitors"]);
    } catch (e) {
      Logger.e("NiriService", "Failed to turn off monitors:", e);
    }
  }

  function turnOnMonitors() {
    try {
      dispatch(["power-on-monitors"]);
    } catch (e) {
      Logger.e("NiriService", "Failed to turn on monitors:", e);
    }
  }

  function logout() {
    try {
      dispatch(["quit", "--skip-confirmation"]);
    } catch (e) {
      Logger.e("NiriService", "Failed to logout:", e);
    }
  }

  function cycleKeyboardLayout() {
    try {
      dispatch(["switch-layout", "next"]);
    } catch (e) {
      Logger.e("NiriService", "Failed to cycle keyboard layout:", e);
    }
  }

  function getFocusedScreen() {
    // On niri the code below only works when you have an actual app selected on that screen.
    return null;
  }

  function spawn(command) {
    try {
      const niriArgs = ["spawn", "--"].concat(command);
      Logger.d("NiriService", "Calling niri spawn: niri msg action " + niriArgs.join(" "));
      dispatch(niriArgs);
    } catch (e) {
      Logger.e("NiriService", "Failed to spawn command:", e);
    }
  }

  function toggleOverview() {
    try {
      dispatch(["toggle-overview"]);
    } catch (e) {
      Logger.e("NiriService", "Failed to toggle overview:", e);
    }
  }
}
