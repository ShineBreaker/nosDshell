import QtQuick
import Quickshell

// Deep module for compositor surface regions (input mask / blur).
// Surfaces register a Region with the compositor in two ways — PanelWindow.mask
// and BackgroundEffect.blurRegion — and Quickshell hides several platform traps
// in that registration. This adapter internalizes them so a surface only
// declares WHAT to track, not HOW the compositor is kept in sync:
//
// 1. Item tracking over hand-bound geometry: PendingRegion only rebuilds on the
//    item's own x/y/width/height property changes, but Region.item goes through
//    mapToScene (quickshell src/core/region.cpp applyTo/itemChanged), which
//    follows transforms and reads the live rect.
// 2. Transform sentinel: an animated Translate does not touch x/y, so the item
//    rect would freeze. The zero-size sentinel below re-emits `changed` each
//    animation frame — but ONLY if slideX/slideY bind the ANIMATED transform
//    values; binding the target values rebuilds once at animation start and
//    freezes on the pre-slide rect (42d69667d's measured stale mask).
// 3. Object swap, never null, when detaching the blur region: re-binding the
//    same Region object after a null does not reliably push a new
//    set_blur_region, leaving the effect lost on return (5f070d64b). activeWhen
//    swaps between two persistent Region objects instead.
// 4. Detach while hidden: a stale region keeps blurring a band where the
//    content used to be while the layer surface stays composited (72808f3fd).
//    activeWhen=false swaps in the empty object.
// 5. Rounded corners: the blur region should match the visual radius; radius
//    and the per-corner overrides are passed through to the item region.
//
// Two composition modes:
// - Simple: set trackedItem (plus radius / per-corner radius and the animated
//   slide values); the internal region below does the tracking.
// - Composite: hand the whole active tree in via activeRegion (declare it as a
//   plain document child — e.g. inside this item — and assign its id). Do NOT
//   try to merge extra children into the internal tree: Region.regions is
//   read-only for bindings, and nothing appends resources automatically.
//
// Caveat for the mask property specifically: null and an empty Region mean
// OPPOSITE things there — null makes the whole surface take input, an empty
// Region makes it fully click-through (proxywindow.cpp updateMask sets
// Qt::WindowTransparentForInput only for a non-null empty mask). "Everything
// takes input" must be expressed as a Region covering the window, not as
// activeWhen=false.
Item {
  id: root

  // Visual item whose live rect (transforms and hidden state included) becomes
  // the region. Leave null when composing via activeRegion instead.
  property Item trackedItem: null

  // Corner radius of the tracked rect (blur should match the visual shape).
  property int radius: 0
  property int topLeftRadius: radius
  property int topRightRadius: radius
  property int bottomLeftRadius: radius
  property int bottomRightRadius: radius

  // false → output the empty object (hidden detach, see 3/4 above).
  property bool activeWhen: true

  // The ANIMATED transform offset, when the tracked item slides via a
  // Translate (see 2 above). Leave 0 when there is no transform animation.
  property real slideX: 0
  property real slideY: 0

  // Any other ANIMATED property that moves the tracked rect — e.g. a scale
  // grow/shrink entry animation. Folded into the sentinel so each animated
  // frame re-emits `changed`. Leave 0 when nothing else moves the rect.
  property real watch: 0

  // Composite mode: the caller-provided active tree. When null, the internal
  // tracked-item region below is used.
  property Region activeRegion: null

  // The Region object to assign to mask / BackgroundEffect.blurRegion.
  readonly property Region region: root.activeWhen ? (root.activeRegion ?? internalActive) : internalEmpty

  // A region-object swap or a content mutation only reaches the compositor
  // with a surface commit; a frame-starved window (occluded, idle render
  // loop, or an instant show/hide transition that renders zero frames —
  // e.g. an arrow popup toggling closed) can hold the pending state
  // indefinitely and leave the stale region ghosted — the same class
  // SmartPanel's close-time flush guards. Flush after every change; the
  // flag coalesces a burst of mutations into one deferred flush, and
  // callLater lets the lazy geometry bindings re-evaluate so the final
  // state is what gets committed.
  property bool _flushQueued: false

  // flushWaylandState only exists on noctalia-qs (it polishes and commits
  // the wl_surface directly); on stock quickshell the QML-reachable way to
  // force the same pending state out is QQuickWindow.update() — it
  // schedules a frame whose present carries the region change. On a fully
  // occluded surface the frame may wait for a compositor callback, but a
  // ghosted region is by definition still being composited.
  function scheduleRegionFlush() {
    if (_flushQueued)
      return;
    _flushQueued = true;
    Qt.callLater(() => {
                   _flushQueued = false;
                   const win = Window.window;
                   if (!win)
                     return;
                   if (win.flushWaylandState)
                     win.flushWaylandState();
                   else if (win.update)
                     win.update();
                 });
  }

  onRegionChanged: scheduleRegionFlush()

  // Content mutations (geometry/item updates inside the assigned tree)
  // emit changed on the Region object without swapping identity — same
  // commit gap as an object swap. During animations changed fires per
  // frame; scheduleRegionFlush coalesces them.
  Connections {
    target: root.region
    function onChanged() {
      root.scheduleRegionFlush();
    }
  }

  Region {
    id: internalEmpty
  }

  Region {
    id: internalActive

    Region {
      item: root.trackedItem
      radius: root.radius
      topLeftRadius: root.topLeftRadius
      topRightRadius: root.topRightRadius
      bottomLeftRadius: root.bottomLeftRadius
      bottomRightRadius: root.bottomRightRadius
    }

    Region {
      x: root.slideX + root.slideY + root.watch
      width: 0
      height: 0
    }
  }
}
