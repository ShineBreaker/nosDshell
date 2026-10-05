import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Modules.LockScreen
import qs.Modules.MainScreen
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// dde-shutdown full-screen session menu (DESIGN §3.8).
//
// Route note: unlike the other panels this one is NOT a SmartPanel. SmartPanel
// sizes every panel to the screen minus Style.marginL on each side and minus
// the taskbar height, which left a ~13 px band of sharp wallpaper around the
// shutdown screen; and because SmartPanel lives inside MainScreen's PanelWindow
// (WlrLayer.Top) it can never paint over the taskbar, whose own content window
// sits on the same layer. dde-shutdown covers the whole screen including the
// taskbar, so this owns a full-screen PanelWindow on WlrLayer.Overlay instead
// (same reasoning as the launcher's own LauncherFullscreenWindow, mirrored to
// the other side of the taskbar). It still registers with PanelService, so
// `qs ipc call sessionMenu toggle`, the taskbar button and MainScreen's central
// keyboard routing (onEscapePressed / onLeftPressed / …) keep working unchanged.
PanelWindow {
  id: root

  // Screen property is inherited from PanelWindow; MainScreen assigns it.
  color: "transparent"

  WlrLayershell.namespace: "nosdshell-session-menu-" + (root.screen?.name || "unknown")
  // Above the taskbar: dde-shutdown is modal over the whole screen
  WlrLayershell.layer: WlrLayer.Overlay
  // Never reserve space — the shutdown screen must not push the taskbar around
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: root.isPanelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  implicitWidth: root.screen?.width || 0
  implicitHeight: root.screen?.height || 0

  // Window state mirrored from the SmartPanel contract that PanelService and
  // MainScreen expect: isPanelOpen drives the open sequence, isPanelVisible is
  // what actually maps the surface.
  property bool isPanelOpen: false
  property bool isPanelVisible: false
  property bool isClosing: false
  readonly property real contentOpacity: isPanelVisible && !isClosing ? 1 : 0

  visible: isPanelVisible || isClosing

  onIsPanelOpenChanged: {
    if (isPanelOpen) {
      isClosing = false;
      isPanelVisible = true;
    } else {
      isClosing = true;
    }
  }

  function open(buttonItem, buttonName) {
    void buttonItem;
    void buttonName;
    if (isPanelOpen)
      return;
    isPanelOpen = true;
    PanelService.willOpenPanel(root);
  }

  function close() {
    if (!isPanelOpen)
      return;
    isPanelOpen = false;
    PanelService.closedPanel(root);
  }

  function closeImmediately() {
    isClosing = false;
    isPanelVisible = false;
    isPanelOpen = false;
    PanelService.closedPanel(root);
  }

  function toggle(buttonItem, buttonName) {
    if (isPanelOpen) {
      close();
    } else {
      open(buttonItem, buttonName);
    }
  }

  Component.onCompleted: PanelService.registerPanel(root)

  // Timer properties
  readonly property int timerDuration: Settings.data.sessionMenu.countdownDuration
  property string pendingAction: ""
  property bool timerActive: false
  property int timeRemaining: 0

  // Navigation properties
  property int selectedIndex: -1
  property bool ignoreMouseHover: true // Transient flag, should always be true on init
  property bool mouseTrackingReady: false

  // Global mouse tracking for movement detection across delegates
  property real globalLastMouseX: 0
  property real globalLastMouseY: 0
  property bool globalMouseInitialized: false
  // Set by presetSelection(); the row below picks it up and takes focus.
  property bool focusRequested: false

  // Artwork map, DDE button order and action dispatch live in ShutdownActions so
  // the lock screen's power row (Modules/LockScreen) shows the same buttons.
  ShutdownActions {
    id: actions
  }

  readonly property var actionMetadata: actions.actionMetadata
  readonly property bool switchUserAvailable: actions.switchUserAvailable

  // Build powerOptions from settings, filtering enabled ones and adding metadata.
  // Order follows dde-shutdown; _powerOptionsVersion forces re-evaluation.
  property int _powerOptionsVersion: 0
  property var powerOptions: {
    void (_powerOptionsVersion);
    return actions.buildOptions();
  }

  Connections {
    target: Settings.data.sessionMenu
    function onPowerOptionsChanged() {
      root._powerOptionsVersion++;
    }
  }

  // Lifecycle ------------------------------------------------------------
  // Named presetSelection() rather than open() so it does not shadow the
  // open() above; called when the panel becomes visible.
  function presetSelection() {
    if (powerOptions.length === 0) {
      Logger.w("SessionMenu", "Trying to open an empty session menu");
      return;
    }

    // DDE preselects "lock" (dde-shutdown contentwidget.cpp m_currentSelectedBtn)
    var lockIndex = -1;
    for (var i = 0; i < powerOptions.length; i++) {
      if (powerOptions[i].action === "lock") {
        lockIndex = i;
        break;
      }
    }
    selectedIndex = lockIndex >= 0 ? lockIndex : 0;
    ignoreMouseHover = true;
    mouseTrackingReady = false;
    globalMouseInitialized = false;
    mouseTrackingDelayTimer.restart();
    focusRequested = true;
  }

  function cancelTimer() {
    timerActive = false;
    pendingAction = "";
    timeRemaining = 0;
    countdownTimer.stop();
  }

  // Hook the visibility transition for preset selection and timer cleanup.
  Connections {
    target: root
    function onIsPanelVisibleChanged() {
      if (root.isPanelVisible) {
        root.presetSelection();
      } else {
        root.cancelTimer();
      }
    }
  }

  // Timer management -----------------------------------------------------
  function startTimer(action) {
    // Check if global countdown is disabled
    if (!Settings.data.sessionMenu.enableCountdown) {
      executeAction(action);
      return;
    }

    // Check per-item countdown setting
    var option = null;
    for (var i = 0; i < powerOptions.length; i++) {
      if (powerOptions[i].action === action) {
        option = powerOptions[i];
        break;
      }
    }

    // If this specific action has countdown disabled, execute immediately
    if (option && option.countdownEnabled === false) {
      executeAction(action);
      return;
    }

    if (timerActive && pendingAction === action) {
      // Second click - execute immediately
      executeAction(action);
      return;
    }

    pendingAction = action;
    timeRemaining = timerDuration;
    timerActive = true;
    countdownTimer.start();
  }

  function executeAction(action) {
    countdownTimer.stop();
    actions.execute(action);
    cancelTimer();
    root.close();
  }

  // Navigation -----------------------------------------------------------
  function selectNextWrapped() {
    if (powerOptions.length > 0) {
      if (selectedIndex < 0) {
        selectedIndex = 0;
      } else {
        selectedIndex = (selectedIndex + 1) % powerOptions.length;
      }
    }
  }

  function selectPreviousWrapped() {
    if (powerOptions.length > 0) {
      if (selectedIndex < 0) {
        selectedIndex = powerOptions.length - 1;
      } else {
        selectedIndex = (((selectedIndex - 1) % powerOptions.length) + powerOptions.length) % powerOptions.length;
      }
    }
  }

  function selectFirst() {
    selectedIndex = powerOptions.length > 0 ? 0 : -1;
  }

  function selectLast() {
    selectedIndex = powerOptions.length > 0 ? powerOptions.length - 1 : -1;
  }

  function activate() {
    if (powerOptions.length > 0 && selectedIndex >= 0 && powerOptions[selectedIndex]) {
      startTimer(powerOptions[selectedIndex].action);
    }
  }

  // MainScreen's central keyboard shortcuts route here.
  function onLeftPressed() {
    selectPreviousWrapped();
  }
  function onRightPressed() {
    selectNextWrapped();
  }
  function onUpPressed() {
    selectPreviousWrapped();
  }
  function onDownPressed() {
    selectNextWrapped();
  }
  function onHomePressed() {
    selectFirst();
  }
  function onEndPressed() {
    selectLast();
  }
  function onReturnPressed() {
    activate();
  }
  function onEscapePressed() {
    if (timerActive) {
      cancelTimer();
    } else {
      root.close();
    }
  }

  function checkKeybind(event) {
    if (powerOptions.length === 0)
      return false;

    if (event.key === Qt.Key_Control || event.key === Qt.Key_Shift || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
      return false;
    }

    const pressedKeybind = Keybinds.getKeybindString(event);
    if (!pressedKeybind)
      return false;

    for (var i = 0; i < powerOptions.length; i++) {
      const option = powerOptions[i];
      if (option.keybind === pressedKeybind) {
        selectedIndex = i;
        startTimer(option.action);
        return true;
      }
    }
    return false;
  }

  Timer {
    id: countdownTimer
    interval: 100
    repeat: true
    onTriggered: {
      timeRemaining -= interval;
      if (timeRemaining <= 0) {
        executeAction(pendingAction);
      }
    }
  }

  Timer {
    id: mouseTrackingDelayTimer
    interval: Style.motionEnter + 50
    repeat: false
    onTriggered: {
      root.mouseTrackingReady = true;
      root.globalMouseInitialized = false;
    }
  }

  // DDE renders the shutdown form over a blurred wallpaper with black
  // underneath (widgets/fullscreenbackground.cpp). LockScreenBackground already
  // owns wallpaper resolution and the nosd-blur / MultiEffect fallback, so
  // reuse it instead of duplicating that machinery. It fills this window, which
  // is anchored to all four edges, so the blurred wallpaper reaches every pixel
  // with no sharp band showing through.
  Item {
    id: content
    anchors.fill: parent
    focus: true

    // PanelWindow exposes no opacity of its own; fade the content item instead
    opacity: root.contentOpacity
    Behavior on opacity {
      enabled: !Settings.data.general.animationDisabled
      NumberAnimation {
        duration: Style.motionEnter
        easing.type: Easing.OutCubic
      }
    }

    LockScreenBackground {
      anchors.fill: parent
      screen: root.screen
      tintColor: "transparent"
      z: 0
    }

    // Click on empty area cancels the countdown, else closes the menu
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      z: 1

      onClicked: {
        if (root.timerActive) {
          root.cancelTimer();
        } else {
          root.close();
        }
      }
    }

    // Cross-scope focus handshake (buttonRow lives here, the trigger is on root)
    Connections {
      target: root
      function onFocusRequestedChanged() {
        if (root.focusRequested) {
          root.focusRequested = false;
          buttonRow.forceActiveFocus();
        }
      }
    }

    Keys.onPressed: event => {
                      if (root.checkKeybind(event)) {
                        event.accepted = true;
                        return;
                      }

                      if (Keybinds.checkKey(event, 'left', Settings)) {
                        root.selectPreviousWrapped();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'right', Settings)) {
                        root.selectNextWrapped();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'up', Settings)) {
                        root.selectPreviousWrapped();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'down', Settings)) {
                        root.selectNextWrapped();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'home', Settings)) {
                        root.selectFirst();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'end', Settings)) {
                        root.selectLast();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'enter', Settings)) {
                        root.activate();
                        event.accepted = true;
                        return;
                      }
                      if (Keybinds.checkKey(event, 'escape', Settings)) {
                        root.onEscapePressed();
                        event.accepted = true;
                        return;
                      }

                      // Block defaults so rebinding a direction actually disables it
                      if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
                        event.accepted = true;
                      }
                    }

    // One horizontal row, vertically centered (contentwidget.cpp buttonLayout)
    Row {
      id: buttonRow
      anchors.centerIn: parent
      spacing: Style.shutdownButtonSpacing
      z: 2

      Repeater {
        model: root.powerOptions
        delegate: ShutdownButton {
          required property var modelData
          required property int index

          width: Style.shutdownButtonSize
          height: Style.shutdownButtonSize
          icon: modelData.icon
          artworkPath: modelData.artworkUrl
          title: modelData.title
          isShutdown: modelData.isShutdown || false
          isSelected: index === root.selectedIndex
          effectiveHover: !root.ignoreMouseHover && buttonMouse.containsMouse
          available: modelData.available !== false
          pending: root.timerActive && root.pendingAction === modelData.action
          keybind: (Settings.data.sessionMenu.showKeybinds && modelData.keybind) ? modelData.keybind : ""

          onClicked: {
            root.selectedIndex = index;
            root.startTimer(modelData.action);
          }
        }
      }
    }

    // Countdown line, 40 px under the row (contentwidget.cpp setBottomWidget)
    NText {
      id: countdownText
      anchors.top: buttonRow.bottom
      anchors.topMargin: Style.shutdownCountdownOffset
      anchors.horizontalCenter: buttonRow.horizontalCenter
      visible: root.timerActive
      z: 2
      text: I18n.tr("session-menu.action-in-seconds", {
                      "action": root.actionMetadata[root.pendingAction] ? root.actionMetadata[root.pendingAction].title : "",
                      "seconds": Math.ceil(root.timeRemaining / 1000)
                    })
      pointSize: Style.fontSizeL
      color: "white"
    }
  }
}
