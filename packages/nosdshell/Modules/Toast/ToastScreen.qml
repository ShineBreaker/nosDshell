import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI

Item {
  id: root

  required property ShellScreen screen

  // Local queue for this screen only (bounded to prevent memory issues)
  property var messageQueue: []
  property int maxQueueSize: 10
  property bool isShowingToast: false

  // If true, immediately show new toasts
  property bool replaceOnNew: true

  Connections {
    target: ToastService

    function onNotify(title, description, icon, type, duration, actionLabel, actionCallback) {
      root.enqueueToast({
                          "title": title,
                          "description": description,
                          "icon": icon,
                          "type": type,
                          "duration": duration,
                          "actionLabel": actionLabel || "",
                          "actionCallback": actionCallback || null,
                          "timestamp": Date.now()
                        });
    }

    function onDismiss() {
      root.dismissToast();
    }
  }

  // Clear queue on component destruction to prevent orphaned toasts
  Component.onDestruction: {
    messageQueue = [];
    isShowingToast = false;
    hideTimer.stop();
    quickSwitchTimer.stop();
  }

  function dismissToast() {
    if (windowLoader.item) {
      hideTimer.stop();
      windowLoader.item.hideToast();
    }
  }

  function enqueueToast(toastData) {
    // Safe logging - fix the substring bug
    var descPreview = (toastData.description || "").substring(0, 100).replace(/\n/g, " ");
    Logger.d("ToastScreen", "Queuing", toastData.type, ":", toastData.title, descPreview);

    // Bounded queue to prevent unbounded memory growth
    if (messageQueue.length >= maxQueueSize) {
      Logger.d("ToastScreen", "Queue full, dropping oldest toast");
      messageQueue.shift();
    }

    if (replaceOnNew && isShowingToast) {
      // Cancel current toast and clear queue for latest toast
      messageQueue = []; // Clear existing queue
      messageQueue.push(toastData);

      // Hide current toast immediately
      root.dismissToast();

      // Process new toast after a brief delay
      isShowingToast = false;
      quickSwitchTimer.restart();
    } else {
      // Queue the toast
      messageQueue.push(toastData);
      processQueue();
    }
  }

  Timer {
    id: quickSwitchTimer
    interval: 50 // Brief delay for smooth transition
    onTriggered: root.processQueue()
  }

  function processQueue() {
    if (messageQueue.length === 0 || isShowingToast) {
      return;
    }

    var data = messageQueue.shift();
    isShowingToast = true;

    // Store the toast data for when loader is ready
    windowLoader.pendingToast = data;

    // Activate the loader - onStatusChanged will handle showing the toast
    windowLoader.active = true;
  }

  function onToastHidden() {
    isShowingToast = false;

    // Deactivate the loader to completely remove the window and free memory
    windowLoader.active = false;

    // Small delay before processing next toast
    hideTimer.restart();
  }

  Timer {
    id: hideTimer
    interval: 200
    onTriggered: root.processQueue()
  }

  // The loader that creates/destroys the PanelWindow as needed
  // This is good for RAM efficiency when toasts are infrequent
  Loader {
    id: windowLoader
    active: false // Only active when showing a toast

    // Store pending toast data
    property var pendingToast: null

    onStatusChanged: {
      // When loader becomes ready, show the pending toast
      if (status === Loader.Ready && pendingToast !== null) {
        item.showToast(pendingToast.title, pendingToast.description, pendingToast.icon, pendingToast.type, pendingToast.duration, pendingToast.actionLabel, pendingToast.actionCallback);
        pendingToast = null;
      }
    }

    sourceComponent: PanelWindow {
      id: panel

      property alias toastItem: toastItem

      screen: root.screen

      // Parse location setting
      readonly property string location: Settings.data.notifications?.location || "top_right"
      readonly property bool isTop: location.startsWith("top")
      readonly property bool isBottom: location.startsWith("bottom")
      readonly property bool isLeft: location.endsWith("_left")
      readonly property bool isRight: location.endsWith("_right")
      readonly property bool isCentered: location === "top" || location === "bottom"

      // Space each edge must keep clear so no shell strip clips the
      // toast — the bar window or the floating fashion dock, the float
      // margin, and the framed ring band (BarService.edgeClearance).
      readonly property int barOffsetTop: BarService.edgeClearance(panel.screen?.name, "top")
      readonly property int barOffsetBottom: BarService.edgeClearance(panel.screen?.name, "bottom")
      readonly property int barOffsetLeft: BarService.edgeClearance(panel.screen?.name, "left")
      readonly property int barOffsetRight: BarService.edgeClearance(panel.screen?.name, "right")

      readonly property int shadowPadding: Style.shadowBlurMax + Style.marginL

      // Anchoring
      anchors.top: isTop
      anchors.bottom: isBottom
      anchors.left: isLeft
      anchors.right: isRight

      // Margins for PanelWindow - only apply bar offset for the specific edge where the bar is
      margins.top: isTop ? barOffsetTop - shadowPadding + Style.marginM : 0
      margins.bottom: isBottom ? barOffsetBottom - shadowPadding + Style.marginM : 0
      margins.left: isLeft ? barOffsetLeft - shadowPadding + Style.marginM : 0
      margins.right: isRight ? barOffsetRight - shadowPadding + Style.marginM : 0

      implicitWidth: Math.round(toastItem.width)
      implicitHeight: Math.round(toastItem.height)

      color: "transparent"

      WlrLayershell.layer: (Settings.data.notifications && Settings.data.notifications.overlayLayer) ? WlrLayer.Overlay : WlrLayer.Top
      WlrLayershell.namespace: "nosdshell-toast-" + (screen?.name || "unknown")
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      // Only the bubble takes input; the shadow area is click-through.
      // The bubble rect is tracked live — the swipe Translate and the
      // scale entry/exit animation move it without touching x/y, so the
      // mask needs the NSurfaceRegion sentinels to rebuild each frame.
      mask: toastMask.region

      NSurfaceRegion {
        id: toastMask
        trackedItem: toastItem.bubble
        radius: Style.radiusL
        slideX: toastItem.swipeOffset + (toastItem.useVerticalSwipe ? 0 : toastItem.edgeOffset)
        slideY: toastItem.swipeOffsetY + (toastItem.useVerticalSwipe ? toastItem.edgeOffset : 0)
        watch: toastItem.scale
      }

      // The same tracked rect is also the blur region — maskTransient is a
      // glass token that assumes a blurred backdrop (DESIGN §1.2).
      BackgroundEffect.blurRegion: toastBlur.region

      NSurfaceRegion {
        id: toastBlur
        trackedItem: toastItem.bubble
        radius: Style.radiusL
        slideX: toastItem.swipeOffset + (toastItem.useVerticalSwipe ? 0 : toastItem.edgeOffset)
        slideY: toastItem.swipeOffsetY + (toastItem.useVerticalSwipe ? toastItem.edgeOffset : 0)
        watch: toastItem.scale
        activeWhen: Colors.blurActive
      }

      function showToast(title, description, icon, type, duration, actionLabel, actionCallback) {
        toastItem.show(title, description, icon, type, duration, actionLabel, actionCallback);
      }

      // Dismiss plays the bubble exit; hidden() fires when it ends.
      function hideToast() {
        toastItem.hide();
      }

      Toast {
        id: toastItem
        onHidden: root.onToastHidden()
      }
    }
  }
}
