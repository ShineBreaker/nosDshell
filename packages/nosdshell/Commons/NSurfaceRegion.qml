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
// 6. niri pending_dirty race: niri 26.04 (src/handlers/background_effect.rs)
//    sets a per-surface pending_dirty flag when the set_blur_region REQUEST
//    arrives and clears it in the post-commit hook of whichever transaction
//    APPLIES next (smithay ff5fa7df transaction.rs:261-271 runs post-commit
//    hooks at apply time). niri holds commits behind dmabuf fence blockers
//    (handlers/compositor.rs add_default_dmabuf_pre_commit_hook), so a
//    still-blocked earlier commit can consume the flag: the commit actually
//    carrying the new region then applies with no dirty flag set, niri's
//    cached blur region stays stale until the next set_blur_region — the
//    leftover blur rectangle seen after a popup closes. The flush below
//    remains the commit trigger; after a burst of region changes settles,
//    the settle timer re-sends the identical region once so the final
//    state is observed even when the race consumed it.
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
  // _resending swaps in the transient internalResend object for one
  // synchronous settle re-send (see 6 above); the polish that follows
  // reads the final object again.
  readonly property Region region: root._resending ? internalResend : (root.activeWhen ? (root.activeRegion ?? internalActive) : internalEmpty)

  // A region-object swap or a content mutation only reaches the compositor
  // with a surface commit, so flush after every change — the flush is the
  // commit trigger for the pending state. The flag coalesces a burst of
  // mutations into one deferred flush, and callLater lets the lazy
  // geometry bindings re-evaluate so the final state is what gets
  // committed. On niri the commit alone is not always enough — the
  // pending_dirty race in 6 above can still lose the update — so the
  // settle timer re-sends the final state once the burst ends.
  property bool _flushQueued: false

  // Settle re-send (see 6 above): restart on every region change/flush; on
  // timeout re-send the identical region once by swapping region to the
  // empty internalResend object and back inside one synchronous JS step.
  // Quickshell's BackgroundEffect.setBlurRegion / ProxyWindow mask only
  // store the region pointer and schedule a polish, so the polish reads
  // the final object and emits set_blur_region / set_input_region with
  // identical content — which the flush machinery above then commits.
  // Works for the active and the empty (nil) states alike. The re-send
  // must not re-arm the timer, hence the _inResend guard in
  // scheduleRegionFlush: regionChanged fires while the swap unwinds, and
  // without the guard each re-send would schedule the next one forever.
  // settleMs is a protocol workaround constant, not a design token.
  property int settleMs: 250
  property bool _resending: false
  property bool _inResend: false

  Timer {
    id: settleTimer
    interval: root.settleMs
    repeat: false
    onTriggered: root.resendRegion()
  }

  function resendRegion() {
    _inResend = true;
    _resending = true;
    _resending = false;
    _inResend = false;
  }

  // flushWaylandState only exists on noctalia-qs (it polishes and commits
  // the wl_surface directly); on stock quickshell the QML-reachable way to
  // force the same pending state out is QQuickWindow.update() — it
  // schedules a frame whose present carries the region change. On a fully
  // occluded surface the frame may wait for a compositor callback, but a
  // ghosted region is by definition still being composited.
  function scheduleRegionFlush() {
    // Changes caused by the settle re-send itself must not re-arm the
    // settle timer — the re-send fires once per burst, not continuously.
    if (!_inResend)
      settleTimer.restart();
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

  // Transient swap target for the settle re-send (see 6 in the header):
  // region points here for the span of one synchronous JS step, which is
  // enough for the pointer identity change the polish needs; it is never
  // the object the polish itself reads.
  Region {
    id: internalResend
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
