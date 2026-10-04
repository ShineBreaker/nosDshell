import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

// Unified OSD component that displays volume, input volume, and brightness changes
Variants {
  id: osd

  // Do not change the order or it will break settings.
  enum Type {
    Volume,
    InputVolume,
    Brightness,
    LockKey
  }

  model: Quickshell.screens.filter(screen => (Settings.data.osd.monitors.includes(screen.name) || Settings.data.osd.monitors.length === 0) && Settings.data.osd.enabled)

  delegate: Loader {
    id: root
    required property ShellScreen modelData
    active: false

    // OSD State
    property int currentOSDType: -1 // OSD.Type enum value, -1 means none
    property bool startupComplete: false
    property real currentBrightness: 0
    property bool suppressInputOSD: false

    // Lock Key States
    property string lastLockKeyChanged: "" // "caps", "num", "scroll", or ""

    // Current values (computed properties)
    readonly property real currentVolume: AudioService.volume
    readonly property bool isMuted: AudioService.muted
    readonly property real currentInputVolume: AudioService.inputVolume
    readonly property bool isInputMuted: AudioService.inputMuted
    readonly property real epsilon: 0.005

    // LockKey OSD enabled state (reactive to settings)
    readonly property bool lockKeyOSDEnabled: {
      const enabledTypes = Settings.data.osd.enabledTypes || [];
      if (enabledTypes.length === 0)
        return false;
      return enabledTypes.includes(OSD.Type.LockKey);
    }

    readonly property var validIcons: {
      const iconKeys = Object.keys(Icons.icons);
      const aliasKeys = Object.keys(Icons.aliases);
      return new Set([...iconKeys, ...aliasKeys]);
    }

    function getIcon() {
      switch (currentOSDType) {
      case OSD.Type.Volume:
        if (isMuted)
          return "volume-mute";
        // Show volume-x icon when volume is effectively 0% (within rounding threshold)
        if (currentVolume < root.epsilon)
          return "volume-x";
        return currentVolume <= 0.5 ? "volume-low" : "volume-high";
      case OSD.Type.InputVolume:
        return isInputMuted ? "microphone-off" : "microphone";
      case OSD.Type.Brightness:
        // Show sun-off icon when brightness is effectively 0% (within rounding threshold)
        if (currentBrightness < root.epsilon)
          return "sun-off";
        return currentBrightness <= 0.5 ? "brightness-low" : "brightness-high";
      case OSD.Type.LockKey:
        return "keyboard";
      default:
        return "";
      }
    }

    function getCurrentValue() {
      switch (currentOSDType) {
      case OSD.Type.Volume:
        return isMuted ? 0 : currentVolume;
      case OSD.Type.InputVolume:
        return isInputMuted ? 0 : currentInputVolume;
      case OSD.Type.Brightness:
        return currentBrightness;
      case OSD.Type.LockKey:
        return 1.0; // Always show 100% when showing lock key status

      default:
        return 0;
      }
    }

    function getMaxValue() {
      if (currentOSDType === OSD.Type.Volume || currentOSDType === OSD.Type.InputVolume) {
        return Settings.data.audio.volumeOverdrive ? 1.5 : 1.0;
      }
      return 1.0;
    }

    function getDisplayPercentage() {
      if (currentOSDType === OSD.Type.LockKey) {
        // For lock keys, return the pre-determined status text
        return lastLockKeyChanged;
      }

      const value = getCurrentValue();
      const max = getMaxValue();
      if ((currentOSDType === OSD.Type.Volume || currentOSDType === OSD.Type.InputVolume) && Settings.data.audio.volumeOverdrive) {
        const pct = Math.round(value * 100);
        return pct + "%";
      }
      const pct = Math.round(Math.min(max, value) * 100);
      return pct + "%";
    }

    function getIconColor() {
      const isMutedState = (currentOSDType === OSD.Type.Volume && isMuted) || (currentOSDType === OSD.Type.InputVolume && isInputMuted);
      if (isMutedState)
        return Color.alert;

      return Color.onTransient;
    }

    // Brightness Handling
    function connectBrightnessMonitors() {
      for (var i = 0; i < BrightnessService.monitors.length; i++) {
        const monitor = BrightnessService.monitors[i];
        monitor.brightnessUpdated.disconnect(onBrightnessChanged);
        monitor.brightnessUpdated.connect(onBrightnessChanged);
      }
    }

    function onBrightnessChanged(newBrightness) {
      if (!root)
        return;

      root.currentBrightness = newBrightness;
      // Don't show OSD if brightness panel is open
      var brightnessPanel = PanelService.getPanel("brightnessPanel", root.modelData);
      var controlCenterPanel = PanelService.getPanel("controlCenterPanel", root.modelData);

      if (brightnessPanel && brightnessPanel.isPanelOpen)
        return;
      if (controlCenterPanel && controlCenterPanel.isPanelOpen) {
        var cards = Settings.data.controlCenter.cards || [];
        if (cards.some(c => c.enabled && c.id === "brightness-card"))
          return;
      }
      showOSD(OSD.Type.Brightness);
    }

    // Check if a specific OSD type is enabled
    function isTypeEnabled(type) {
      const enabledTypes = Settings.data.osd.enabledTypes || [];
      // If enabledTypes is empty, no types are enabled (no OSD will be shown)
      if (enabledTypes.length === 0)
        return false;
      return enabledTypes.includes(type);
    }

    // OSD Display Control
    function showOSD(type) {
      // Ignore all OSD requests during startup period
      if (!startupComplete)
        return;

      // Check if this OSD type is enabled
      if (!isTypeEnabled(type))
        return;

      // Suppress Audio OSD if Audio Panel or Control Center (with audio card) is open
      if (type === OSD.Type.Volume || type === OSD.Type.InputVolume) {
        var audioPanel = PanelService.getPanel("audioPanel", root.modelData);
        if (audioPanel && audioPanel.isPanelOpen)
          return;
        var controlCenterPanel = PanelService.getPanel("controlCenterPanel", root.modelData);
        if (controlCenterPanel && controlCenterPanel.isPanelOpen) {
          var cards = Settings.data.controlCenter.cards || [];
          if (cards.some(c => c.enabled && c.id === "audio-card"))
            return;
        }
      }

      currentOSDType = type;

      if (!root.active) {
        root.active = true;
      }

      if (root.item) {
        root.item.showOSD();
      } else {
        Qt.callLater(() => {
                       if (root.item)
                       root.item.showOSD();
                     });
      }
    }

    function hideOSD() {
      if (root.item?.osdItem) {
        root.item.osdItem.hideImmediately();
      } else if (root.active) {
        root.active = false;
      }
    }

    // AudioService monitoring
    Connections {
      target: AudioService

      function onVolumeChanged() {
        showOSD(OSD.Type.Volume);
      }

      function onVolumeAtMaximum() {
        showOSD(OSD.Type.Volume);
      }

      function onVolumeAtMinimum() {
        showOSD(OSD.Type.Volume);
      }

      function onMutedChanged() {
        if (AudioService.consumeOutputOSDSuppression())
          return;
        showOSD(OSD.Type.Volume);
      }

      function onInputVolumeChanged() {
        if (suppressInputOSD)
          return;
        if (AudioService.hasInput)
          showOSD(OSD.Type.InputVolume);
      }

      function onInputMutedChanged() {
        if (suppressInputOSD)
          return;
        if (!AudioService.hasInput)
          return;
        if (AudioService.consumeInputOSDSuppression())
          return;
        showOSD(OSD.Type.InputVolume);
      }

      // Refresh OSD when device changes to ensure correct volume is displayed
      function onSinkChanged() {
        suppressInputOSD = true;
        inputSuppressionTimer.restart();
        // If volume OSD is currently showing, refresh it to show new device's volume
        if (root.currentOSDType === OSD.Type.Volume) {
          Qt.callLater(() => {
                         showOSD(OSD.Type.Volume);
                       });
        }
      }

      function onSourceChanged() {
        // If input volume OSD is currently showing, refresh it to show new device's volume
        if (root.currentOSDType === OSD.Type.InputVolume) {
          Qt.callLater(() => {
                         showOSD(OSD.Type.InputVolume);
                       });
        }
      }
    }

    // Brightness monitoring
    Connections {
      target: BrightnessService
      function onMonitorsChanged() {
        connectBrightnessMonitors();
      }
    }

    // Register/unregister LockKeysService polling based on whether LockKey OSD is enabled
    onLockKeyOSDEnabledChanged: {
      if (lockKeyOSDEnabled) {
        LockKeysService.registerComponent("osd:" + (modelData?.name || "unknown"));
      } else {
        LockKeysService.unregisterComponent("osd:" + (modelData?.name || "unknown"));
      }
    }
    Component.onCompleted: {
      if (lockKeyOSDEnabled) {
        LockKeysService.registerComponent("osd:" + (modelData?.name || "unknown"));
      }
    }

    // LockKeys monitoring with a cleaner approach
    // Only connect when LockKey OSD is enabled to avoid starting the service unnecessarily
    Connections {
      target: root.lockKeyOSDEnabled ? LockKeysService : null

      function onCapsLockChanged(active) {
        root.lastLockKeyChanged = active ? "CAPS ON" : "CAPS OFF";
        root.showOSD(OSD.Type.LockKey);
      }

      function onNumLockChanged(active) {
        root.lastLockKeyChanged = active ? "NUM ON" : "NUM OFF";
        root.showOSD(OSD.Type.LockKey);
      }

      function onScrollLockChanged(active) {
        root.lastLockKeyChanged = active ? "SCROLL ON" : "SCROLL OFF";
        root.showOSD(OSD.Type.LockKey);
      }
    }

    // Startup timer - connect brightness monitors and enable OSD after 2 seconds
    Timer {
      id: startupTimer
      interval: 2000
      running: true
      onTriggered: {
        connectBrightnessMonitors();
        root.startupComplete = true;
      }
    }

    // Timer to reset the input volume OSD suppression
    Timer {
      id: inputSuppressionTimer
      interval: 300
      repeat: false
      onTriggered: root.suppressInputOSD = false
    }

    Component.onDestruction: {
      LockKeysService.unregisterComponent("osd:" + (modelData?.name || "unknown"));
      if (typeof BrightnessService !== "undefined" && BrightnessService.monitors) {
        for (var i = 0; i < BrightnessService.monitors.length; i++) {
          try {
            BrightnessService.monitors[i].brightnessUpdated.disconnect(onBrightnessChanged);
          } catch (e) {
            // Ignore errors if already disconnected or not connected
          }
        }
      }
    }

    // Visual Component
    sourceComponent: PanelWindow {
      id: panel
      screen: modelData

      // Position configuration
      readonly property string location: Settings.data.osd?.location || "bottom_center"
      readonly property bool isTop: location === "top" || location.startsWith("top")
      readonly property bool isBottom: location === "bottom" || location.startsWith("bottom")
      readonly property bool isLeft: location.includes("_left") || location === "left"
      readonly property bool isRight: location.includes("_right") || location === "right"
      readonly property bool verticalMode: location === "left" || location === "right"

      // DDE default: tile horizontally centred, its bottom edge 180 px above the
      // screen bottom (dde-osd/container.cpp moveToCenter / setWaylandAnimationOffset).
      readonly property bool ddeBottomCenter: location === "bottom_center"

      // Hidden text element for measuring lock key text width
      NText {
        id: lockKeyTextMetrics
        visible: false
        text: root.getDisplayPercentage()
        pointSize: Style.fontSizeS
        family: Settings.data.ui.fontFixed
        elide: Text.ElideNone
        wrapMode: Text.NoWrap
      }

      // Dimensions
      readonly property bool isShortMode: root.currentOSDType === OSD.Type.LockKey
      readonly property int longHWidth: Math.round(320 * Style.uiScaleRatio)
      readonly property int longHHeight: Math.round(72 * Style.uiScaleRatio)
      readonly property int shortHWidth: Math.round(180 * Style.uiScaleRatio)
      readonly property int longVWidth: Math.round(80 * Style.uiScaleRatio)
      readonly property int longVHeight: Math.round(280 * Style.uiScaleRatio)
      readonly property int shortVHeight: Math.round(180 * Style.uiScaleRatio)

      // Dynamic width for horizontal lock keys based on text length
      // Explicitly bind to contentWidth to ensure reactivity
      readonly property int lockKeyHWidth: {
        if (root.currentOSDType !== OSD.Type.LockKey || verticalMode) {
          return shortHWidth;
        }
        const text = root.getDisplayPercentage();
        if (!text) {
          return shortHWidth;
        }
        // Access contentWidth to create binding dependency
        const textWidth = Math.ceil(lockKeyTextMetrics.contentWidth || 0);
        if (textWidth === 0) {
          // Fallback: estimate based on text length if measurement not ready
          const fontSize = Style.fontSizeS * Settings.data.ui.fontFixedScale * Style.uiScaleRatio;
          const estimatedWidth = text.length * fontSize * 0.6;
          const iconWidth = Style.fontSizeXL * Style.uiScaleRatio;
          const margins = Style.margin2L;
          const spacing = Style.marginM;
          const bgMargins = Style.margin2M * 1.5;
          return Math.max(shortHWidth, Math.round((estimatedWidth + iconWidth + margins + spacing + bgMargins) * 1.1));
        }
        const iconWidth = Style.fontSizeXL * Style.uiScaleRatio;
        const margins = Style.margin2L; // Left and right content margins
        const spacing = Style.marginM; // Spacing between icon and text
        const bgMargins = Style.margin2M * 1.5; // Background margins
        const totalWidth = textWidth + iconWidth + margins + spacing + bgMargins;
        // Ensure minimum width and add some buffer
        return Math.max(shortHWidth, Math.round(totalWidth * 1.1));
      }

      // Dynamic height for vertical lock keys based on text length
      readonly property int lockKeyVHeight: {
        if (root.currentOSDType !== OSD.Type.LockKey || !verticalMode) {
          return shortVHeight;
        }
        const text = root.getDisplayPercentage();
        const charCount = text ? text.length : 0;
        if (charCount === 0) {
          return shortVHeight;
        }
        // Calculate height: font size * char count + margins + icon space
        // Font size M (11pt) scaled, plus some spacing between chars
        const fontSize = Style.fontSizeS * Settings.data.ui.fontFixedScale * Style.uiScaleRatio;
        const charHeight = fontSize * 1.3; // Add 30% for line height (matches Layout.preferredHeight)
        const textHeight = charCount * charHeight;
        // Background margins (Style.marginM * 1.5 * 2 for top and bottom)
        const bgMargins = Style.marginM * 1.5 * 2;
        // Content margins (Style.margin2L for top and bottom)
        const contentMargins = Style.margin2L;
        // Icon size: fontSizeXL scaled, with extra space for icon rendering and padding
        const iconSize = Style.fontSizeXL * Style.uiScaleRatio * 1.8; // Add 80% for icon rendering and padding
        // Spacing between text and icon (Style.marginM for lock keys)
        const textIconSpacing = Style.marginM;
        // Add extra buffer to ensure everything fits comfortably
        const buffer = Style.marginL;
        const totalHeight = textHeight + bgMargins + contentMargins + iconSize + textIconSpacing + buffer;
        // Ensure minimum height and add some padding for safety
        return Math.max(shortVHeight, Math.round(totalHeight * 1.1));
      }

      // DDE: tile bottom edge 180 px above the screen bottom (container.cpp
      // moveToCenter). `bottom_center` is the "bottom" location with that
      // offset; bare "bottom" keeps the generic margin.
      readonly property int osdBottomOffset: Math.round(180 * Style.uiScaleRatio)

      anchors.top: isTop
      anchors.bottom: isBottom
      anchors.left: isLeft
      anchors.right: isRight

      readonly property bool hasBar: BarService.hasBarOnScreen(root.modelData?.name)
      readonly property string screenBarPosition: hasBar ? Settings.getBarPositionForScreen(root.modelData?.name) : ""
      readonly property real barHeight: hasBar ? Style.getBarHeightForScreen(root.modelData?.name) : 0
      readonly property bool isFramed: hasBar && Settings.getEffectiveBarType() === "framed"
      readonly property real frameThickness: Settings.data.bar.frameThickness ?? 8

      function calculateMargin(isAnchored, position) {
        if (!isAnchored)
          return 0;

        let base = Style.marginM;
        if (screenBarPosition === position) {
          const isVertical = position === "top" || position === "bottom";
          const floatExtra = Math.ceil(Settings.getEffectiveBarType() === "floating" ? (isVertical ? Settings.data.bar.marginVertical : Settings.data.bar.marginHorizontal) : 0);
          return barHeight + base + floatExtra;
        }

        if (isFramed) {
          return base + frameThickness;
        }

        return base;
      }

      margins.top: calculateMargin(anchors.top, "top")
      margins.bottom: (isBottom ? Math.max(calculateMargin(anchors.bottom, "bottom"), ddeBottomCenter ? osdBottomOffset : 0) : 0)
      margins.left: calculateMargin(anchors.left, "left")
      margins.right: calculateMargin(anchors.right, "right")

      implicitWidth: Math.max(Style.osdTileSize, verticalMode ? longVWidth : (isShortMode ? lockKeyHWidth : Style.osdTileSize))
      implicitHeight: Math.max(Style.osdTileSize, verticalMode ? longVHeight : Style.osdTileSize)
      color: "transparent"

      WlrLayershell.namespace: "noctalia-osd-" + (screen?.name || "unknown")
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.layer: Settings.data.osd?.overlayLayer ? WlrLayer.Overlay : WlrLayer.Top
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      // Click-through — OSD is display-only, no input needed
      mask: Region {}

      Item {
        id: osdItem
        anchors.fill: parent
        visible: false
        opacity: 0

        Behavior on opacity {
          NumberAnimation {
            duration: Style.motionOsdIn
            easing.type: Easing.OutCubic
          }
        }

        // DDE slides the tile up 12 px on show / 8 px on hide while fading
        // (dde-osd/container.cpp startWaylandAnimation).
        property real slideOffset: 0
        transform: Translate {
          y: osdItem.slideOffset
        }
        Behavior on slideOffset {
          NumberAnimation {
            duration: Style.motionOsdIn
            easing.type: Easing.OutCubic
          }
        }

        Timer {
          id: hideTimer
          interval: Settings.data.osd.autoHideMs
          onTriggered: osdItem.hide()
        }

        Timer {
          id: visibilityTimer
          interval: Style.motionOsdOut
          onTriggered: {
            osdItem.visible = false;
            root.currentOSDType = -1;
            root.lastLockKeyChanged = "";
            root.active = false;
          }
        }

        Rectangle {
          id: tile
          anchors.centerIn: parent
          width: Style.osdTileSize
          height: Style.osdTileSize
          radius: Style.radiusLarge
          color: Color.maskTransient
          border.color: Color.borderTransient
          border.width: Style.borderS

          // Shadow: must not inflate the window. autoPaddingEnabled grows an
          // anchors.fill child, which would push the panel surface past
          // 140x140 and scale the whole tile; anchor it to the tile's own
          // geometry instead.
          NDropShadow {
            x: tile.x
            y: tile.y
            width: tile.width
            height: tile.height
            source: tile
            autoPaddingEnabled: false
            shadow: Style.shadowOsd
          }

          // ---- progress types: volume / input volume / brightness ----
          // Absolute positioning: DDE draws the glyph at a fixed offset from the
          // tile top and the bar at a fixed offset (dde-osd/common.cpp
          // DrawImage / DrawProgressBar), so no layout pass can shift them.
          NIcon {
            id: osdGlyph
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.osdIconOffsetWithProgress
            icon: root.getIcon()
            color: root.getIconColor()
            pointSize: Style.fontSizeXL
          }

          Rectangle {
            id: progressTrack
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.osdProgressOffset
            width: Style.osdProgressWidth
            height: Style.osdProgressHeight
            radius: Style.osdProgressHeight / 2
            color: Color.onTransientTrack

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: parent.width * Math.min(1.0, root.getCurrentValue() / root.getMaxValue())
              radius: parent.radius
              color: Color.onTransient

              Behavior on width {
                NumberAnimation {
                  duration: Style.motionOsdIn
                  easing.type: Easing.OutCubic
                }
              }
            }

            // Overdrive graduation: two 1x5 tick marks at the 2/3 point of
            // the track (dde-osd/common.cpp DrawVolumeGraduation).
            Rectangle {
              visible: Settings.data.audio.volumeOverdrive && (root.currentOSDType === OSD.Type.Volume || root.currentOSDType === OSD.Type.InputVolume)
              x: parent.width * (1.0 / 1.5)
              y: -8
              width: Style.osdTickWidth
              height: Style.osdTickHeight
              color: Color.onTransientTick
            }

            Rectangle {
              visible: Settings.data.audio.volumeOverdrive && (root.currentOSDType === OSD.Type.Volume || root.currentOSDType === OSD.Type.InputVolume)
              x: parent.width * (1.0 / 1.5)
              y: parent.height + 3
              width: Style.osdTickWidth
              height: Style.osdTickHeight
              color: Color.onTransientTick
            }
          }

          // ---- lock key: glyph + text, no progress ----
          NIcon {
            id: lockKeyGlyph
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.osdIconOffsetWithText
            visible: root.currentOSDType === OSD.Type.LockKey
            icon: root.getIcon()
            color: root.getIconColor()
            pointSize: Style.fontSizeXL
          }

          NText {
            id: lockKeyLabel
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.osdIconOffsetWithText + Style.fontSizeXL * Style.uiScaleRatio + Style.marginS
            visible: root.currentOSDType === OSD.Type.LockKey
            text: root.getDisplayPercentage()
            color: Color.onTransient
            pointSize: Style.fontSizeS
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
          }

        }

        // Delay showing the OSD to allow the layout to settle after activation.
        // Without this, the percentage text renders outside the box on first
        // show.
        Timer {
          id: showDelayTimer
          interval: 30
          onTriggered: {
            osdItem.visible = true;
            osdItem.slideOffset = -12;
            osdItem.opacity = 0;
            osdItem.slideOffset = 0;
            osdItem.opacity = 1;
            hideTimer.start();
          }
        }

        function show() {
          hideTimer.stop();
          visibilityTimer.stop();
          showDelayTimer.start();
        }

        function hide() {
          hideTimer.stop();
          visibilityTimer.stop();
          osdItem.opacity = 0;
          osdItem.slideOffset = -8;
          visibilityTimer.start();
        }

        function hideImmediately() {
          hideTimer.stop();
          visibilityTimer.stop();
          osdItem.opacity = 0;
          osdItem.visible = false;
          root.currentOSDType = -1;
          root.active = false;
        }
      }

      function showOSD() {
        osdItem.show();
      }
    }
  }
}
