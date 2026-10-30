pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

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

  function rootItem(name) {
    return roots[name] || null;
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
      // Scene position catches items painted outside their parent's rect —
      // hit-testing can never reach those, the tree is the only way to see them.
      // mapToItem qWarns on windowless items (mid-incubation delegates etc.).
      if (item.Window) {
        var gp = item.mapToItem(null, 0, 0);
        if (gp) {
          s += " @" + Math.round(gp.x) + "," + Math.round(gp.y);
        }
      }
      if (item.visible === false) {
        s += " hidden";
      }
      if (item.enabled === false) {
        s += " disabled";
      }
      if (item.opacity !== undefined && item.opacity < 1) {
        s += " opacity:" + Number(item.opacity).toFixed(2);
      }
      // Lifecycle row flags (app-strip delayed-removal recipe): a row stuck
      // at 0 length shows dying:true here — ghost vs still-entering.
      if (item.dying !== undefined) {
        s += " dying:" + item.dying;
      }
      if (item.scale !== undefined && item.scale !== 1) {
        s += " scale:" + Number(item.scale).toFixed(2);
      }
      if (item.clip === true) {
        s += " clip";
      }
      if (item.z) {
        s += " z:" + item.z;
      }
      if (item.layer && item.layer.enabled) {
        s += " layer";
      }
      // Pointer-relevant state: a Flickable still grabbing presses, or a
      // MouseArea that is enabled but never sees events, shows up here.
      if (item.interactive !== undefined) {
        s += " interactive:" + item.interactive;
      }
      // Flickable scroll state: a stuck view shows contentY:0 and an
      // auto-mode content size shows contentHeight:-1.
      if (item.contentY !== undefined) {
        s += " contentY:" + Math.round(item.contentY) + "/" + Math.round(item.contentHeight);
      }
      if (item.containsMouse !== undefined) {
        s += " containsMouse:" + item.containsMouse;
      }
      if (item.containsPress !== undefined) {
        s += " containsPress:" + item.containsPress;
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
    // PanelWindow/Window children live on contentItem, not children[].
    try {
      if (item.contentItem) {
        var ck = item.contentItem.children || [];
        for (var j = 0; j < ck.length; j++) {
          kids.push(ck[j]);
        }
      }
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
    // Window screen position, so callers can convert the dump's window-local
    // @x,y into screen coords for real pointer input (anchored PopupWindows
    // like context menus sit away from the screen origin).
    var head = "";
    try {
      var w = item.Window;
      if (w)
        head = "window @" + Math.round(w.x) + "," + Math.round(w.y) + " " + Math.round(w.width) + "x" + Math.round(w.height) + "\n";
    } catch (e) {}
    return head + dumpItemTree(item, maxDepth);
  }

  // The panel actually on screen: PanelService.openedPanel. Names lie when a
  // screen binding races registration — the open panel is the truth.
  function dumpOpenedPanel(maxDepth) {
    var p = null;
    try {
      p = PanelService.openedPanel;
    } catch (e) {}
    if (!p)
      return "no panel open";
    var head = describe(p) + " isPanelOpen=" + p.isPanelOpen + " isPanelVisible=" + p.isPanelVisible;
    return head + "\n" + dumpItemTree(p, maxDepth);
  }

  // PanelService render-chain snapshot: why the background is/isn't drawing.
  // Answers "assignedPanel null?" / "screen match?" / "panelBg geometry?" in
  // one shot instead of inferring from half a dozen IPC round-trips.
  function dumpBackgroundChain() {
    var lines = [];
    var op = null, cp = null;
    try {
      op = PanelService.openedPanel;
    } catch (e) {}
    try {
      cp = PanelService.closingPanel;
    } catch (e) {}
    var slots = [];
    try {
      slots = PanelService.backgroundSlotAssignments;
    } catch (e) {}
    lines.push("openedPanel=" + (op ? (op.objectName || String(op)) : "null"));
    lines.push("closingPanel=" + (cp ? (cp.objectName || String(cp)) : "null"));
    lines.push("backgroundSlotAssignments[0]=" + (slots[0] ? (slots[0].objectName || String(slots[0])) : "null"));
    lines.push("backgroundSlotAssignments[1]=" + (slots[1] ? (slots[1].objectName || String(slots[1])) : "null"));
    if (op) {
      lines.push("openedPanel.screen=" + (op.screen ? op.screen.name : "null"));
      lines.push("openedPanel.isPanelOpen=" + op.isPanelOpen);
      lines.push("openedPanel.isPanelVisible=" + op.isPanelVisible);
      lines.push("openedPanel.isClosing=" + op.isClosing);
      lines.push("openedPanel.ownBackgroundAlpha=" + op.ownBackgroundAlpha);
      lines.push("openedPanel.dimsBackground=" + op.dimsBackground);
      var pr = null;
      try {
        pr = op.panelRegion;
      } catch (e) {}
      lines.push("openedPanel.panelRegion=" + (pr ? describe(pr) : "null"));
      if (pr) {
        lines.push("  panelRegion.visible=" + pr.visible);
        var pi = null;
        try {
          pi = pr.panelItem;
        } catch (e) {}
        lines.push("  panelRegion.panelItem=" + (pi ? describe(pi) : "null"));
        if (pi) {
          lines.push("    panelItem.visible=" + pi.visible);
          lines.push("    panelItem.size=" + Math.round(pi.width) + "x" + Math.round(pi.height));
        }
      }
      // finishOpen gate: the reopen hook needs _contentReady + contentLoader.item.
      try {
        lines.push("openedPanel._contentReady=" + op._contentReady);
      } catch (e) {}
      try {
        lines.push("openedPanel.keepContentAlive=" + op.keepContentAlive);
      } catch (e) {}
      var cl = null;
      try {
        cl = op.contentLoader;
      } catch (e) {}
      lines.push("openedPanel.contentLoader=" + (cl ? "item=" + (cl.item ? "yes" : "null") + " active=" + cl.active + " status=" + cl.status : "null"));
    }
    // Walk every registered root that is a MainScreen to report isPanelOpen/color
    var names = Object.keys(roots);
    for (var i = 0; i < names.length; i++) {
      var r = roots[names[i]];
      if (!r)
        continue;
      if (r.isPanelOpen !== undefined) {
        lines.push("root[" + names[i] + "].screen=" + (r.screen ? r.screen.name : "null") + " isPanelOpen=" + r.isPanelOpen + " dimmerOpacity=" + r.dimmerOpacity + " color=" + r.color + " children=" + (r.children ? r.children.length : "?") + " contentItem=" + (r.contentItem ? "yes" : "no"));
      }
    }
    // PanelBackground slots: reach into the AllBackgrounds instance under each
    // MainScreen root and report assignedPanel + isRenderable — the two values
    // that decide whether a ShapePath paints anything at all. AllBackgrounds
    // exposes them as property aliases (ownAlphaSlot0/1, unifiedSlot0/1).
    for (var i = 0; i < names.length; i++) {
      var r = roots[names[i]];
      if (!r || r.isPanelOpen === undefined)
        continue;
      var ab = null;
      try {
        _walkItems(r, 0, function (it) {
          if (!ab && it.ownAlphaSlot0 !== undefined)
            ab = it;
        });
      } catch (e) {}
      if (!ab) {
        lines.push("root[" + names[i] + "]: AllBackgrounds not found");
        continue;
      }
      var s0 = null, s1 = null, u0 = null, u1 = null;
      try {
        s0 = ab.ownAlphaSlot0;
      } catch (e) {}
      try {
        s1 = ab.ownAlphaSlot1;
      } catch (e) {}
      try {
        u0 = ab.unifiedSlot0;
      } catch (e) {}
      try {
        u1 = ab.unifiedSlot1;
      } catch (e) {}
      lines.push("root[" + names[i] + "].ownAlphaSlot0.assignedPanel=" + (s0 && s0.assignedPanel ? (s0.assignedPanel.objectName || String(s0.assignedPanel)) : "null") + " isRenderable=" + (s0 ? s0.isRenderable : "?") + " fillColor=" + (s0 ? s0.fillColor : "?"));
      lines.push("root[" + names[i] + "].ownAlphaSlot1.assignedPanel=" + (s1 && s1.assignedPanel ? (s1.assignedPanel.objectName || String(s1.assignedPanel)) : "null") + " isRenderable=" + (s1 ? s1.isRenderable : "?"));
      lines.push("root[" + names[i] + "].unifiedSlot0.assignedPanel=" + (u0 && u0.assignedPanel ? (u0.assignedPanel.objectName || String(u0.assignedPanel)) : "null") + " isRenderable=" + (u0 ? u0.isRenderable : "?"));
      lines.push("root[" + names[i] + "].unifiedSlot1.assignedPanel=" + (u1 && u1.assignedPanel ? (u1.assignedPanel.objectName || String(u1.assignedPanel)) : "null") + " isRenderable=" + (u1 ? u1.isRenderable : "?"));
    }
    var out = lines.join("\n");
    console.info(out);
    return out;
  }

  // Pointer forensics: walk childAt() from a root item down to the deepest
  // item under the window coordinate (gx, gy). This is the same hit path Qt's
  // pointer delivery computes, minus event acceptance — so it answers "which
  // item is topmost at this pixel" when clicks land somewhere unexpected.
  // rootName "" or "opened" = PanelService.openedPanel.
  function hitTest(rootName, gx, gy, maxDepth) {
    var root = null;
    try {
      root = (rootName === "" || rootName === "opened") ? PanelService.openedPanel : roots[rootName];
    } catch (e) {}
    if (!root)
      return "no such root '" + rootName + "' (known: " + rootNames() + ", opened=" + (PanelService.openedPanel ? PanelService.openedPanel.objectName : "none") + ")";
    var p = root.mapFromItem(null, gx, gy);
    var lines = ["hit(" + gx + "," + gy + ") →"];
    var cur = root;
    lines.push("  " + describe(cur) + " @" + Math.round(p.x) + "," + Math.round(p.y));
    for (var d = 0; d < (maxDepth || 24); d++) {
      // List EVERY child containing the point (paint order → delivery order);
      // the topmost acceptor wins, so a covering item shows up before it.
      var kids = [];
      try {
        kids = cur.children || [];
      } catch (e) {}
      var hitKids = [];
      for (var i = 0; i < kids.length; i++) {
        var k = kids[i];
        try {
          if (k.visible === false || !k.Window)
            continue;
          var lp = cur.mapToItem(k, p.x, p.y);
          if (lp.x >= 0 && lp.y >= 0 && lp.x <= k.width && lp.y <= k.height)
            hitKids.push([k, lp]);
        } catch (e) {}
      }
      if (hitKids.length === 0)
        break;
      for (var j = hitKids.length - 1; j >= 0; j--) {
        var tag = j === hitKids.length - 1 ? "=>" : "  ";
        lines.push(tag + " " + describe(hitKids[j][0]) + " @" + Math.round(hitKids[j][1].x) + "," + Math.round(hitKids[j][1].y));
      }
      // Descend through the topmost child (paint-order last)
      var top = hitKids[hitKids.length - 1][0];
      p = hitKids[hitKids.length - 1][1];
      cur = top;
    }
    var out = lines.join("\n");
    console.info(out);
    return out;
  }

  function dumpAllRoots(maxDepth) {
    var names = Object.keys(roots);
    var parts = [];
    for (var i = 0; i < names.length; i++) {
      parts.push("== " + names[i] + " ==\n" + dumpItemTree(roots[names[i]], maxDepth));
    }
    return parts.join("\n");
  }

  // Find the first item with a matching objectName under a registered root
  // ("" / "opened" = PanelService.openedPanel). Pairs with setProperty to poke
  // state mid-repro — e.g. filling a search field the pointer can't reach.
  // Popups/dialogs parent to the window's Overlay, a sibling subtree of the
  // registered root — when the root walk misses, retry over the whole window
  // content item so dialogs are reachable too.
  function findItem(rootName, objectName) {
    var item = null;
    try {
      item = (rootName === "" || rootName === "opened") ? PanelService.openedPanel : roots[rootName];
    } catch (e) {}
    if (!item)
      return null;
    var found = null;
    var match = function (it) {
      if (found)
        return;
      try {
        if (it.objectName === objectName)
          found = it;
      } catch (e) {}
    };
    _walkItems(item, 0, match);
    if (!found) {
      try {
        var top = item.Window ? item.Window.contentItem : null;
        if (top && top !== item)
          _walkItems(top, 0, match);
      } catch (e) {}
    }
    return found;
  }

  function setProperty(rootName, objectName, prop, value) {
    var it = findItem(rootName, objectName);
    if (!it)
      return "no item '" + objectName + "' under " + rootName + " (roots: " + rootNames() + ")";
    try {
      if (it[prop] === undefined)
        return "no property '" + prop + "' on " + describe(it);
      it[prop] = value;
      return "ok " + describe(it) + " " + prop + "=" + value;
    } catch (e) {
      return "set failed on " + describe(it) + ": " + e;
    }
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
    // PanelWindow/Window children live on contentItem, not children[].
    try {
      if (item.contentItem) {
        var ck = item.contentItem.children || [];
        for (var j = 0; j < ck.length; j++) {
          _walkItems(ck[j], depth + 1, fn);
        }
      }
    } catch (e) {}
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
    var lines = ["isDebug=" + Settings.isDebug + " (env=" + Settings.envDebug + " persisted=" + (Settings.data.debug.enabled) + ")", "modules='" + Settings.data.debug.modules + "' logLevel=" + Settings.data.debug.logLevel, "screens=" + screens.join(" | "), "toplevels=" + toplevels, "roots=" + (rootNames() || "<none>"), "watches=" + (Object.keys(
                                                                                                                                                                                                                                                                                                                                                 _watches).join(", ")
                                                                                                                                                                                                                                                                                                                                               || "<none>"),
                 "qtTrace= QT_LOGGING_RULES env must be set before launch — e.g. qt.quick.hover.trace=true"];
    return lines.join("\n");
  }
}
