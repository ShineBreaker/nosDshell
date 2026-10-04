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
// Route note: this stays a SmartPanel. SmartPanel owns the window (layershell,
// focus, mask, close animation) and MainScreen's background slots reference
// panels through PanelService, so the only way to keep `qs ipc call sessionMenu
// toggle`, the bar button and the blurred backdrop working is to remain a
// SmartPanel. The DDE full-screen look is achieved with preferredWidth/Height
// ratio 1.0 and a transparent panelBackgroundColor + blurEnabled = false, so
// SmartPanel draws no frame and clips nothing — the DDE form is the
// panelContent.
SmartPanel {
  id: root

  // Full-screen form: no panel frame, no SmartPanel background.
  blurEnabled: false
  panelBackgroundColor: "transparent"
  panelBorderColor: "transparent"
  preferredWidth: 0
  preferredWidthRatio: 1.0
  preferredHeight: 0
  preferredHeightRatio: 1.0

  // dde-shutdown always centers its button row
  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true

  // SessionMenu handles its own closing logic
  closeWithEscape: false

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
  // Set by presetSelection(); the row inside panelContent picks it up and takes
  // focus, because ids in panelContent are not visible from this scope.
  property bool focusRequested: false

  // Action metadata mapping (dde-shutdown contentwidget.cpp order)
  readonly property var actionMetadata: {
    "shutdown": {
      "icon": "power",
      "title": I18n.tr("common.shutdown"),
      "isShutdown": true
    },
    "reboot": {
      "icon": "refresh",
      "title": I18n.tr("common.reboot"),
      "isShutdown": false
    },
    "suspend": {
      "icon": "moon",
      "title": I18n.tr("common.suspend"),
      "isShutdown": false
    },
    "hibernate": {
      "icon": "snowflake",
      "title": I18n.tr("common.hibernate"),
      "isShutdown": false
    },
    "lock": {
      "icon": "lock",
      "title": I18n.tr("common.lock"),
      "isShutdown": false
    },
    "switchUser": {
      "icon": "user-switch",
      "title": I18n.tr("session-menu.switch-user"),
      "isShutdown": false
    },
    "logout": {
      "icon": "logout",
      "title": I18n.tr("common.logout"),
      "isShutdown": false
    },
    "rebootToUefi": {
      "icon": "device-desktop",
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
      options.push({
                     "action": settingOption.action,
                     "icon": metadata.icon,
                     "title": metadata.title,
                     "isShutdown": metadata.isShutdown,
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
  // Named presetSelection() rather than open() so it does not shadow
  // SmartPanel.open(); called when the panel becomes visible.
  // NOTE: close()/toggle() are SmartPanel's — this panel only adds
  // cancelTimer() via onIsPanelVisibleChanged below, because defining
  // close() here would shadow it and recurse infinitely.
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

  // SmartPanel already defines open()/close()/toggle(), so only hook the
  // visibility transition here (preset selection on open, timer cancel on
  // close) instead of shadowing those functions.
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
    // SmartPanel's close — do NOT call this.close(), that would recurse.
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
      root.close(); // SmartPanel's close
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
  // reuse it instead of duplicating that machinery.
  //
  // NOTE: the background and the click-outside area live inside panelContent,
  // not as siblings of it — SmartPanel's contentLoader is declared in the base
  // file, so siblings added here would paint above the panel content and hide
  // the button row.
  panelContent: Component {
    Item {
      id: content
      anchors.fill: parent
      focus: true

      readonly property bool allowAttach: false
      readonly property var geometryPlaceholder: null

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
            root.close(); // SmartPanel's close
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
            title: modelData.title
            isShutdown: modelData.isShutdown || false
            isSelected: index === root.selectedIndex
            effectiveHover: !root.ignoreMouseHover && buttonMouse.containsMouse
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

  // RoundItemButton (rounditembutton.cpp): 140x140, 75x75 glyph, 10 px gap,
  // white wrapping label; hover/selected = pressDim rounded rect radiusLarge;
  // disabled = opacity 0.5
  component ShutdownButton: Rectangle {
    id: button

    property string icon: ""
    property string title: ""
    property bool isShutdown: false
    property bool isSelected: false
    property bool effectiveHover: false
    property bool pending: false
    property string keybind: ""

    signal clicked

    readonly property bool dimmed: isSelected || effectiveHover

    radius: Style.radiusLarge
    color: dimmed ? Color.pressDim : "transparent"
    opacity: 1.0

    Behavior on color {
      enabled: !Settings.data.general.animationDisabled
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Style.shutdownButtonIcon
        Layout.preferredHeight: Style.shutdownButtonIcon
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
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }
}
