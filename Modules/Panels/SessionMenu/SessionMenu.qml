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

  // DDE ships the button artwork as normal/hover/press SVGs; the mapping below
  // is the one dde-shutdown/skin/shutdown.qss:1-40 declares per button objectName.
  // hibernate uses the shared widgets/ list_actions/sleep_*.svg (shutdown.qss:37-40);
  // rebootToUefi is nosDshell-only and has no DDE artwork, so it reuses reboot_*.
  readonly property string ddeShutdownIcons: Quickshell.shellDir + "/Assets/DDE/gxde-session-ui/dde-shutdown/img/"
  readonly property string ddeWidgetIcons: Quickshell.shellDir + "/Assets/DDE/gxde-session-ui/widgets/img/"
  // Action metadata mapping (dde-shutdown contentwidget.cpp order)
  readonly property var actionMetadata: {
    "shutdown": {
      "icon": "power",
      "artwork": "poweroff",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.shutdown"),
      "isShutdown": true
    },
    "reboot": {
      "icon": "refresh",
      "artwork": "reboot",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.reboot"),
      "isShutdown": false
    },
    "suspend": {
      "icon": "moon",
      "artwork": "suspend",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.suspend"),
      "isShutdown": false
    },
    "hibernate": {
      "icon": "snowflake",
      "artwork": "sleep",
      "artworkDir": "widgets/list_actions",
      "title": I18n.tr("common.hibernate"),
      "isShutdown": false
    },
    "lock": {
      "icon": "lock",
      "artwork": "lock",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.lock"),
      "isShutdown": false
    },
    "switchUser": {
      "icon": "user-switch",
      "artwork": "userswitch",
      "artworkDir": "shutdown",
      "title": I18n.tr("session-menu.switch-user"),
      "isShutdown": false
    },
    "logout": {
      "icon": "logout",
      "artwork": "logout",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.logout"),
      "isShutdown": false
    },
    "rebootToUefi": {
      "icon": "device-desktop",
      "artwork": "reboot",
      "artworkDir": "shutdown",
      "title": I18n.tr("common.reboot-to-uefi"),
      "isShutdown": false
    }
  }

  // DDE has no "switch user" action in the session service; the entry is only
  // offered when the compositor service can actually switch users.
  readonly property bool switchUserAvailable: typeof CompositorService.switchUser === "function"

  // Build powerOptions from settings, filtering enabled ones and adding metadata.
  // Order follows dde-shutdown; _powerOptionsVersion forces re-evaluation.
  property int _powerOptionsVersion: 0
  property var powerOptions: {
    void (_powerOptionsVersion);
    var options = [];
    var settingsOptions = Settings.data.sessionMenu.powerOptions || [];

    var ddeOrder = ["shutdown", "reboot", "suspend", "hibernate", "lock", "switchUser", "logout", "rebootToUefi"];
    var enabled = [];
    for (var i = 0; i < settingsOptions.length; i++) {
      if (settingsOptions[i].enabled && actionMetadata[settingsOptions[i].action]) {
        enabled.push(settingsOptions[i]);
      }
    }
    enabled.sort(function (a, b) {
      var ia = ddeOrder.indexOf(a.action);
      var ib = ddeOrder.indexOf(b.action);
      if (ia < 0)
        ia = ddeOrder.length;
      if (ib < 0)
        ib = ddeOrder.length;
      return ia - ib;
    });

    for (var j = 0; j < enabled.length; j++) {
      var settingOption = enabled[j];
      // "switch user" is only offered when it can actually run
      if (settingOption.action === "switchUser" && !switchUserAvailable) {
        continue;
      }
      var metadata = actionMetadata[settingOption.action];
      // Most artwork lives in dde-shutdown/img/; hibernate uses the shared
      // widgets/ list_actions set (shutdown.qss:37-40)
      var base = metadata.artworkDir === "shutdown" ? root.ddeShutdownIcons : root.ddeWidgetIcons + "list_actions/";
      options.push({
                     "action": settingOption.action,
                     "icon": metadata.icon,
                     "artworkUrl": metadata.artwork ? base + metadata.artwork : "",
                     "title": metadata.title,
                     "isShutdown": metadata.isShutdown,
                     "available": settingOption.action !== "switchUser" || switchUserAvailable,
                     "countdownEnabled": settingOption.countdownEnabled !== undefined ? settingOption.countdownEnabled : true,
                     "command": settingOption.command || "",
                     "keybind": settingOption.keybind || ""
                   });
    }

    return options;
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

    switch (action) {
    case "lock":
      CompositorService.lock();
      break;
    case "suspend":
      if (Settings.data.general.lockOnSuspend) {
        CompositorService.lockAndSuspend();
      } else {
        CompositorService.suspend();
      }
      break;
    case "hibernate":
      CompositorService.hibernate();
      break;
    case "reboot":
      CompositorService.reboot();
      break;
    case "userspaceReboot":
      CompositorService.userspaceReboot();
      break;
    case "rebootToUefi":
      CompositorService.rebootToUefi();
      break;
    case "logout":
      CompositorService.logout();
      break;
    case "shutdown":
      CompositorService.shutdown();
      break;
    }

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

  // RoundItemButton (rounditembutton.cpp): 140x140, 75x75 glyph, 10 px gap,
  // white wrapping label; hover/selected = pressDim rounded rect radiusLarge;
  // disabled = opacity 0.5. The glyph itself is the original 75x75 DDE artwork
  // and switches between the normal / hover / press SVGs — rounditembutton.cpp
  // repaints m_itemIcon from a QSvgRenderer in its event filter (lines 173-181),
  // it does not tint or fade it.
  component ShutdownButton: Rectangle {
    id: button

    property string icon: ""
    // Absolute path prefix of the DDE artwork, e.g. ".../dde-shutdown/img/poweroff"
    property string artworkPath: ""
    property string title: ""
    property bool isShutdown: false
    property bool isSelected: false
    property bool effectiveHover: false
    property bool pressed: false
    property bool available: true
    property bool pending: false
    property string keybind: ""

    signal clicked

    readonly property bool dimmed: isSelected || effectiveHover || pressed

    // rounditembutton.cpp:194-201 — one SVG per state, no overlay
    readonly property string artworkState: pressed ? "press" : (dimmed ? "hover" : "normal")

    radius: Style.radiusLarge
    color: dimmed ? Color.pressDim : "transparent"
    // rounditembutton.cpp:65-74 — setDisabled() drops the whole widget to 0.5
    opacity: button.available ? 1.0 : 0.5

    Behavior on color {
      enabled: !Settings.data.general.animationDisabled
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    Behavior on opacity {
      enabled: !Settings.data.general.animationDisabled
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      // rounditembutton.cpp:104-111 — 10 px of leading space, then the icon,
      // then the wrapping label below it
      spacing: Style.shutdownButtonIconTextGap

      Image {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Style.shutdownButtonIcon
        Layout.preferredHeight: Style.shutdownButtonIcon
        source: button.artworkPath !== "" ? button.artworkPath + "_" + button.artworkState + ".svg" : ""
        sourceSize.width: Style.shutdownButtonIcon
        sourceSize.height: Style.shutdownButtonIcon
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
        // Fall back to the Tabler glyph only if the artwork is missing
        visible: source !== ""
      }

      NIcon {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Style.shutdownButtonIcon
        Layout.preferredHeight: Style.shutdownButtonIcon
        visible: button.artworkPath === ""
        icon: button.icon
        color: "white"
        pointSize: Style.fontSizeXXXL
      }

      NText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Style.shutdownButtonSize - Style.marginM
        text: button.title
        pointSize: Style.fontSizeM
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
      }

      // Keybind shown after the label, onShellTertiary (white @0.6)
      NText {
        Layout.alignment: Qt.AlignHCenter
        text: button.keybind
        pointSize: Style.fontSizeS
        color: Color.onShellTertiary
        visible: text.length > 0
      }
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: button.available
      cursorShape: Qt.PointingHandCursor
      onPressed: button.pressed = true
      onReleased: button.pressed = false
      onEntered: button.pressed = false
      onExited: button.pressed = false
      onClicked: button.clicked()
    }
  }
}
