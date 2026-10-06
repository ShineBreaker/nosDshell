pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor

// DebugService — shell-side forensics for live debugging.
//
// Modules volunteer named scene roots (registerRoot); the service can then
// dump any subtree — children[] is the exact paint-order list Qt's hover
// delivery snapshots, so phantom children Qt inserts (layer effect source /
// effect items, grab items) show up here without a core dump — or attach
// Component.destruction watchers over a whole tree so a mid-delivery
// destroyer names itself in the log. Reachable over IPC:
//   qs ipc call debug toggle|status|list|tree <name>|watch <name>|unwatch <name>|dump
Singleton {
  id: root

  // name -> item. Modules register their interesting scene roots; refs die
  // with the items, so a stale entry only means the screen/module is gone.
  property var roots: ({})

  // name -> array of {item, fn} destruction watcher bindings
  property var _watches: ({})

  function registerRoot(name, item) {
    roots[name] = item;
  }

  function unregisterRoot(name) {
    delete roots[name];
    unwatchTree(name);
  }

  function rootNames() {
    return Object.keys(roots).join(", ");
  }

  // One-line descriptor: QML type + pointer + objectName + geometry + flags.
  // The pointer is what lets a log line be matched against a gdb/core frame.
  function describe(item) {
    if (!item) {
      return "<null>";
    }
    var s = String(item); // "Item_QML_45(0x55…)" / "QQuickItem(0x…)"
    try {
      if (item.objectName) {
        s += " \"" + item.objectName + "\"";
      }
      if (item.width !== undefined) {
        s += " " + Math.round(item.width) + "x" + Math.round(item.height);
      }
      if (item.visible === false) {
        s += " hidden";
      }
      if (item.z) {
        s += " z:" + item.z;
      }
      if (item.layer && item.layer.enabled) {
        s += " layer";
      }
    } catch (e) {}
    return s;
  }

  function _dumpInto(item, depth, maxDepth, lines) {
    var indent = "  ".repeat(depth);
    lines.push(indent + describe(item));
    var kids = [];
    try {
      kids = item.children || [];
    } catch (e) {}
    if (depth >= maxDepth) {
      if (kids.length > 0) {
        lines.push(indent + "  … (" + kids.length + " more)");
      }
      return;
    }
    for (var i = 0; i < kids.length; i++) {
      _dumpInto(kids[i], depth + 1, maxDepth, lines);
    }
  }

  // Dumps the paint-order child tree; prints to the log AND returns the text
  // so IPC callers see it on stdout. maxDepth defaults to 8.
  function dumpItemTree(item, maxDepth) {
    var lines = [];
    _dumpInto(item, 0, maxDepth === undefined ? 8 : maxDepth, lines);
    var out = lines.join("\n");
    console.info(out);
    return out;
  }

  function dumpRegisteredRoot(name, maxDepth) {
    var item = roots[name];
    if (!item) {
      return "unknown root '" + name + "' (known: " + rootNames() + ")";
    }
    return dumpItemTree(item, maxDepth);
  }

  function dumpAllRoots(maxDepth) {
    var names = Object.keys(roots);
    var parts = [];
    for (var i = 0; i < names.length; i++) {
      parts.push("== " + names[i] + " ==\n" + dumpItemTree(roots[names[i]], maxDepth));
    }
    return parts.join("\n");
  }

  // Lifecycle forensics: attach Component.destruction on every item in a
  // registered subtree. When anything in that tree dies mid-frame the log
  // names it — this is the instrument that identified the layer-effect UAF.
  function watchTree(name) {
    var item = roots[name];
    if (!item) {
      return "unknown root '" + name + "' (known: " + rootNames() + ")";
    }
    unwatchTree(name);
    var watchers = [];
    _walkItems(item, 0, function (it) {
      var label = describe(it);
      var fn = function () {
        Logger.w("DbgWatch", name + " destroyed: " + label);
      };
      try {
        it.Component.destruction.connect(fn);
        watchers.push({
                        "item": it,
                        "fn": fn
                      });
      } catch (e) {}
    });
    _watches[name] = watchers;
    Logger.i("DbgWatch", name + ": " + watchers.length + " destruction watchers installed");
    return watchers.length + " watchers on " + name;
  }

  function unwatchTree(name) {
    var watchers = _watches[name];
    if (!watchers) {
      return;
    }
    for (var i = 0; i < watchers.length; i++) {
      try {
        watchers[i].item.Component.destruction.disconnect(watchers[i].fn);
      } catch (e) {}
    }
    delete _watches[name];
  }

  function _walkItems(item, depth, fn) {
    if (depth > 64) {
      return;
    }
    fn(item);
    var kids = [];
    try {
      kids = item.children || [];
    } catch (e) {}
    for (var i = 0; i < kids.length; i++) {
      _walkItems(kids[i], depth + 1, fn);
    }
  }

  // Compact "what the shell thinks the world looks like" snapshot.
  function statusText() {
    var screens = [];
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var s = Quickshell.screens[i];
      screens.push(s.name + " " + s.width + "x" + s.height);
    }
    var toplevels = 0;
    try {
      toplevels = ToplevelManager ? (ToplevelManager.toplevels.values || []).length : -1;
    } catch (e) {}
    var lines = ["isDebug=" + Settings.isDebug + " (env=" + Settings.envDebug + " persisted=" + (Settings.data.debug.enabled ?? false) + ")", "modules='" + Settings.data.debug.modules + "' logLevel=" + Settings.data.debug.logLevel, "screens=" + screens.join(" | "), "toplevels=" + toplevels, "roots=" + (rootNames() || "<none>"), "watches=" + (Object.keys(_watches).join(", ") || "<none>"), "qtTrace= QT_LOGGING_RULES env must be set before launch — e.g. qt.quick.hover.trace=true"];
    return lines.join("\n");
  }
}
