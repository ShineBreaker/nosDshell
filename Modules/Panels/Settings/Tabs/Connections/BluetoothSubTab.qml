import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Bluetooth

import qs.Commons
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  Layout.fillWidth: true
  implicitHeight: mainLayout.implicitHeight

  // Configuration for shared use (e.g. by BluetoothPanel)
  property bool showOnlyLists: false

  readonly property bool isDiscoverable: BluetoothService.discoverable

  // Device lists with local filtering logic
  readonly property var connectedDevices: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    var filtered = BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && dev.connected);
    filtered = BluetoothService.dedupeDevices(filtered);
    return BluetoothService.sortDevices(filtered);
  }

  readonly property var pairedDevices: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    var filtered = BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && !dev.connected && (dev.paired || dev.trusted));
    filtered = BluetoothService.dedupeDevices(filtered);
    return BluetoothService.sortDevices(filtered);
  }

  readonly property var unnamedAvailableDevices: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    return BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && !dev.paired && !dev.trusted);
  }

  readonly property var availableDevices: {
    var list = root.unnamedAvailableDevices;

    if (Settings.data.network.bluetoothHideUnnamedDevices) {
      list = list.filter(function (dev) {
        var dn = dev.name || dev.deviceName || "";
        var s = String(dn).trim();
        if (s.length === 0)
          return false;
        var lower = s.toLowerCase();
        if (lower === "unknown" || lower === "unnamed" || lower === "n/a" || lower === "na")
          return false;
        var addr = dev.address || dev.bdaddr || dev.mac || "";
        if (addr.length > 0) {
          var normName = s.toLowerCase().replace(/[^0-9a-z]/g, "");
          var normAddr = String(addr).toLowerCase().replace(/[^0-9a-z]/g, "");
          if (normName.length > 0 && normName === normAddr)
            return false;
        }
        var macRegexComb = /^(([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}|([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}|[0-9A-Fa-f]{12})$/;
        if (macRegexComb.test(s)) {
          return false;
        }
        return true;
      });
    }
    list = BluetoothService.dedupeDevices(list);
    return BluetoothService.sortDevices(list);
  }

  // For managing expanded device details
  property string expandedDeviceKey: ""

  // Combined visibility check: tab must be visible AND the window must be visible
  readonly property bool effectivelyVisible: root.visible && Window.window && Window.window.visible

  Connections {
    target: BluetoothService
    function onEnabledChanged() {
      stateChangeDebouncer.restart();
    }
    function onDiscoverableChanged() {
      stateChangeDebouncer.restart();
    }
  }

  onEffectivelyVisibleChanged: stateChangeDebouncer.restart()

  Timer {
    id: stateChangeDebouncer
    interval: 100 // 100ms debounce
    repeat: false
    onTriggered: root._updateScanningState()
  }

  // Scanning ownership lives in BluetoothService.startDiscovery/
  // stopDiscovery (reference counted). Several BluetoothSubTab instances
  // stay alive at once (keep-alive panels preload the settings view while
  // hidden — the CC-embedded module view, the standalone settings window,
  // per-screen panels); when each instance flipped setScanActive directly a
  // hidden instance that tore down state it never owned just ping-ponged
  // the adapter with the visible one (~1 Hz, jittering the page), and an
  // owner-less scan had no stop path at all. Discoverable keeps its
  // per-instance ownership here — no second surface toggles it.
  property bool _ownsDiscoverable: false

  function _updateScanningState() {
    if (effectivelyVisible && BluetoothService.enabled && !showOnlyLists) {
      Logger.d("BluetoothPrefs", "Panel/tab active");
      BluetoothService.startDiscovery(root);
      if (!isDiscoverable) {
        BluetoothService.setDiscoverable(true);
        _ownsDiscoverable = true;
      }
    } else {
      Logger.d("BluetoothPrefs", "Panel/tab inactive");
      // Read the live state before writing: BlueZ may already have stopped
      // discovery on its own — a redundant stop is what "No discovery
      // started" warnings look like.
      BluetoothService.stopDiscovery(root);
      if (_ownsDiscoverable) {
        _ownsDiscoverable = false;
        if (isDiscoverable)
          BluetoothService.setDiscoverable(false);
      }
    }
  }

  Component.onDestruction: {
    // Release only what this instance owns; the service keeps scanning
    // alive while any other owner (sibling sub-tab, CC detail page) holds
    // its own reference.
    BluetoothService.stopDiscovery(root);
    if (_ownsDiscoverable) {
      _ownsDiscoverable = false;
      if (isDiscoverable)
        BluetoothService.setDiscoverable(false);
    }
    Logger.d("BluetoothPrefs", "Panel closed");
  }

  ColumnLayout {
    id: mainLayout
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: root.showOnlyLists ? Style.marginM : Style.settingsGroupSpacing

    // Master toggle — a DDE SettingsGroup of one row (§3.5.4); the
    // discoverable caption is the row's own description.
    NToggle {
      visible: !root.showOnlyLists
      Layout.fillWidth: true
      label: I18n.tr("common.bluetooth")
      description: (BluetoothService.enabled && isDiscoverable) ? I18n.tr("panels.connections.bluetooth-discoverable", {
                                                                            hostName: HostService.hostName
                                                                          }) : ""
      icon: BluetoothService.enabled ? "bluetooth" : "bluetooth-off"
      checked: BluetoothService.enabled
      enabled: !NetworkService.airplaneModeEnabled && BluetoothService.bluetoothAvailable && !BluetoothService.blocked
      onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
    }

    // Device List [1] (Connected)
    ColumnLayout {
      visible: root.connectedDevices.length > 0 && BluetoothService.enabled
      Layout.fillWidth: true
      spacing: Style.marginM

      NHeader {
        label: I18n.tr("bluetooth.panel.connected-devices")
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.settingsGroupGap
        property var deviceList: root.connectedDevices

        Repeater {
          // Model is index keys, not the entries: boxing the JS-array model
          // turns the BluetoothDevice refs into raw pointers (CODING_STANDARDS
          // "QML 规则"). The delegate resolves the live JS entry via this
          // column's deviceList.
          model: root.connectedDevices.map((_, i) => i)
          delegate: nboxDelegate
        }
      }
    }

    // Devices List [2] (Paired)
    ColumnLayout {
      visible: root.pairedDevices.length > 0 && BluetoothService.enabled
      Layout.fillWidth: true
      spacing: Style.marginM

      NHeader {
        label: I18n.tr("bluetooth.panel.paired-devices")
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.settingsGroupGap
        property var deviceList: root.pairedDevices

        Repeater {
          // Index-key model — see the comment on the connected-devices
          // Repeater above (CODING_STANDARDS "QML 规则").
          model: root.pairedDevices.map((_, i) => i)
          delegate: nboxDelegate
        }
      }
    }

    // Device List [3] (Available)
    ColumnLayout {
      visible: !root.showOnlyLists && root.unnamedAvailableDevices.length > 0 && BluetoothService.enabled
      Layout.fillWidth: true
      spacing: Style.marginM

      NHeader {
        label: I18n.tr("bluetooth.panel.available-devices")
        description: BluetoothService.scanningActive ? I18n.tr("bluetooth.panel.scanning") : ""
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.settingsGroupGap
        property var deviceList: root.availableDevices

        Repeater {
          // Index-key model — see the comment on the connected-devices
          // Repeater above (CODING_STANDARDS "QML 规则").
          model: root.availableDevices.map((_, i) => i)
          delegate: nboxDelegate
        }
      }

      NText {
        visible: root.availableDevices.length === 0 && root.unnamedAvailableDevices.length > 0
        text: I18n.tr("panels.connections.bluetooth-devices-unnamed")
        pointSize: Style.fontSizeS
        color: Colors.onShellTertiary
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
    }

    ColumnLayout {
      visible: !root.showOnlyLists && BluetoothService.enabled
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap

      NToggle {
        label: I18n.tr("panels.connections.bluetooth-auto-connect-label")
        description: I18n.tr("panels.connections.bluetooth-auto-connect-description")
        checked: Settings.data.network.bluetoothAutoConnect
        onToggled: checked => Settings.data.network.bluetoothAutoConnect = checked
      }

      NToggle {
        label: I18n.tr("panels.connections.hide-unnamed-devices-label")
        description: I18n.tr("panels.connections.hide-unnamed-devices-description")
        checked: Settings.data.network.bluetoothHideUnnamedDevices
        onToggled: checked => Settings.data.network.bluetoothHideUnnamedDevices = checked
      }

      // RSSI Polling
      NToggle {
        label: I18n.tr("panels.connections.bluetooth-rssi-polling-label")
        description: I18n.tr("panels.connections.bluetooth-rssi-polling-description")
        checked: Settings.data.network.bluetoothRssiPollingEnabled
        onToggled: checked => Settings.data.network.bluetoothRssiPollingEnabled = checked
      }
      NSpinBox {
        label: I18n.tr("panels.connections.bluetooth-rssi-polling-interval-label")
        description: I18n.tr("panels.connections.bluetooth-rssi-polling-interval-description")
        from: 10000
        to: 120000
        stepSize: 1000
        value: Settings.data.network.bluetoothRssiPollIntervalMs
        defaultValue: Settings.getDefaultValue("network.bluetoothRssiPollIntervalMs")
        onValueChanged: Settings.data.network.bluetoothRssiPollIntervalMs = value
        suffix: " ms"
        Layout.alignment: Qt.AlignVCenter
        visible: Settings.data.network.bluetoothRssiPollingEnabled
      }
    }
  }

  // Shared Delegate — a DDE row; pairing/connected state reads through the
  // spinner, the accent check and the status text instead of filled colors.
  Component {
    id: nboxDelegate
    NDccRow {
      id: device

      required property int index

      // The section's device list is injected through the repeater's parent
      // column (deviceList): an entries-array model would box each
      // BluetoothDevice into a QVariant copy that loses QPointer tracking
      // (CODING_STANDARDS "QML 规则"), so the model carries only index keys
      // and the row resolves the live JS entry itself.
      readonly property var entry: device.parent && device.parent.deviceList ? (device.parent.deviceList[device.index] ?? null) : null

      readonly property bool canConnect: BluetoothService.canConnect(entry)
      readonly property bool canDisconnect: BluetoothService.canDisconnect(entry)
      readonly property bool canPair: BluetoothService.canPair(entry)
      readonly property bool isBusy: BluetoothService.isDeviceBusy(entry)
      readonly property bool isExpanded: root.expandedDeviceKey === BluetoothService.deviceKey(entry)

      clip: true
      Layout.fillWidth: true

      ColumnLayout {
        id: deviceColumn
        Layout.fillWidth: true
        spacing: Style.marginS

        RowLayout {
          id: deviceLayout
          Layout.fillWidth: true
          spacing: Style.marginM
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            icon: BluetoothService.getDeviceIcon(entry)
            pointSize: Style.fontSizeXXL
            color: Colors.onShell
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: entry?.name || entry?.deviceName || ""
              pointSize: Style.fontSizeM
              font.weight: entry?.connected ? Style.fontWeightSemiBold : Style.fontWeightMedium
              elide: Text.ElideRight
              color: Colors.onShell
              Layout.fillWidth: true
            }

            NText {
              text: {
                const k = BluetoothService.getStatusKey(entry);
                if (k === "pairing")
                  return I18n.tr("common.pairing");
                if (k === "blocked")
                  return I18n.tr("bluetooth.panel.blocked");
                if (k === "connecting")
                  return I18n.tr("common.connecting");
                if (k === "disconnecting")
                  return I18n.tr("common.disconnecting");
                return "";
              }
              visible: text !== ""
              pointSize: Style.fontSizeXS
              color: Colors.onShellTertiary
            }

            RowLayout {
              visible: entry?.batteryAvailable ?? false
              spacing: Style.marginS
              NIcon {
                icon: {
                  var b = BluetoothService.getBatteryPercent(entry);
                  return BatteryService.getIcon(b !== null ? b : 0, false, false, b !== null);
                }
                pointSize: Style.fontSizeXS
                color: Colors.onShellTertiary
              }
              NText {
                numeric: true
                text: {
                  var b = BluetoothService.getBatteryPercent(entry);
                  return b === null ? "-" : (b + "%");
                }
                pointSize: Style.fontSizeXS
                color: Colors.onShellTertiary
              }
            }
          }

          Item {
            Layout.fillWidth: true
          }

          NIcon {
            visible: (entry?.connected ?? false) && entry?.state !== BluetoothDeviceState.Disconnecting
            icon: "check"
            pointSize: Style.fontSizeXL
            color: Colors.accent
            Layout.alignment: Qt.AlignVCenter
          }

          RowLayout {
            spacing: Style.marginS

            NBusyIndicator {
              visible: isBusy
              running: visible && root.effectivelyVisible
              color: Colors.onShell
              size: Style.baseWidgetSize * 0.5
            }

            NIconButton {
              visible: (entry?.connected ?? false) && entry?.state !== BluetoothDeviceState.Disconnecting
              icon: "info"
              tooltipText: I18n.tr("common.info")
              baseSize: Style.baseWidgetSize * 0.75
              colorBg: Colors.overlay("field")
              colorFg: Colors.onShell
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: {
                const key = BluetoothService.deviceKey(entry);
                root.expandedDeviceKey = (root.expandedDeviceKey === key) ? "" : key;
              }
            }

            NIconButton {
              visible: !root.showOnlyLists && ((entry?.paired ?? false) || (entry?.trusted ?? false)) && !(entry?.connected ?? false) && !isBusy && !(entry?.blocked ?? false)
              icon: "trash"
              tooltipText: I18n.tr("common.unpair")
              baseSize: Style.baseWidgetSize * 0.75
              colorBg: Colors.overlay("field")
              colorFg: Colors.alert
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: BluetoothService.unpairDevice(entry)
            }

            NButton {
              id: button
              visible: entry?.state !== BluetoothDeviceState.Connecting && entry?.state !== BluetoothDeviceState.Disconnecting
              enabled: (canConnect || canDisconnect || (root.showOnlyLists ? false : canPair)) && !isBusy
              fontSize: Style.fontSizeS
              backgroundColor: entry?.connected ? Colors.overlay("strong") : Colors.accent
              textColor: entry?.connected ? Colors.onShell : Colors.onAccent
              text: {
                if (entry?.pairing)
                  return I18n.tr("common.pairing");
                if (entry?.blocked)
                  return I18n.tr("bluetooth.panel.blocked");
                if (entry?.connected)
                  return I18n.tr("common.disconnect");
                if (!root.showOnlyLists && device.canPair)
                  return I18n.tr("common.pair");
                return I18n.tr("common.connect");
              }
              onClicked: {
                if (entry?.connected) {
                  BluetoothService.disconnectDevice(entry);
                } else {
                  if (!root.showOnlyLists && device.canPair) {
                    BluetoothService.pairDevice(entry);
                  } else {
                    BluetoothService.connectDeviceWithTrust(entry);
                  }
                }
              }
            }
          }
        }

        // Expanded info section
        Rectangle {
          visible: device.isExpanded
          Layout.fillWidth: true
          implicitHeight: infoColumn.implicitHeight + Style.margin2S
          radius: Style.radiusItem
          color: Colors.overlay("field")
          border.width: Style.borderS
          border.color: Colors.borderShell
          clip: true

          GridLayout {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: Style.marginS
            flow: GridLayout.TopToBottom
            rows: 3
            columns: 2
            columnSpacing: Style.marginM
            rowSpacing: Style.marginXS

            // --- Item 1: Signal Strength ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: BluetoothService.getSignalIcon(entry)
                pointSize: Style.fontSizeXS
                color: Colors.onShell
              }
              NText {
                text: BluetoothService.getSignalStrength(entry)
                pointSize: Style.fontSizeXS
                color: Colors.onShell
                Layout.fillWidth: true
              }
            }

            // --- Item 2: Battery ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: {
                  var b = BluetoothService.getBatteryPercent(entry);
                  return BatteryService.getIcon(b !== null ? b : 0, false, false, b !== null);
                }
                pointSize: Style.fontSizeXS
                color: Colors.onShell
              }
              NText {
                numeric: true
                text: {
                  var b = BluetoothService.getBatteryPercent(entry);
                  return b === null ? "-" : (b + "%");
                }
                pointSize: Style.fontSizeXS
                color: Colors.onShell
                Layout.fillWidth: true
              }
            }
            // --- Item 3: Pair state ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "link"
                pointSize: Style.fontSizeXS
                color: Colors.onShell
              }
              NText {
                text: entry?.paired ? I18n.tr("common.yes") : I18n.tr("common.no")
                pointSize: Style.fontSizeXS
                color: Colors.onShell
                Layout.fillWidth: true
              }
            }
            // --- Item 4: Trust state ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "shield-check"
                pointSize: Style.fontSizeXS
                color: Colors.onShell
              }
              NText {
                text: entry?.trusted ? I18n.tr("common.yes") : I18n.tr("common.no")
                pointSize: Style.fontSizeXS
                color: Colors.onShell
                Layout.fillWidth: true
              }
            }
            // --- Item 5: Address ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "hash"
                pointSize: Style.fontSizeXS
                color: Colors.onShell
              }
              NText {
                text: entry?.address || "-"
                pointSize: Style.fontSizeXS
                color: Colors.onShell
                Layout.fillWidth: true
              }
            }
            // --- Item 6: Auto-connect ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.topMargin: -Style.marginXXS
              spacing: Style.marginXS
              visible: Settings.data.network.bluetoothAutoConnect
              NIcon {
                icon: BluetoothService.getDeviceAutoConnect(entry) ? "repeat" : "repeat-off"
                pointSize: Style.fontSizeXS
              }
              NCheckbox {
                label: I18n.tr("common.auto-connect")
                labelSize: Style.fontSizeXS
                baseSize: Style.baseWidgetSize * 0.5
                checked: BluetoothService.getDeviceAutoConnect(entry)
                onToggled: checked => BluetoothService.setDeviceAutoConnect(entry, checked)
              }
            }
          }
        }
      }
    }
  }

  // PIN Authentication Overlay (This part needs some love :P)
  Rectangle {
    id: pinOverlay
    visible: !root.showOnlyLists && BluetoothService.pinRequired
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 400)
    height: pinCol.implicitHeight + Style.margin2L
    color: Colors.maskShell
    radius: Style.radiusWindow
    border.color: Colors.borderShell
    border.width: Style.borderS
    z: 1000

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: mouse => mouse.accepted = true
      onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
      id: pinCol
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      NIcon {
        icon: "lock"
        pointSize: Style.emptyStateIconSize
        color: Colors.accent
        Layout.alignment: Qt.AlignHCenter
      }
      NText {
        text: I18n.tr("panels.connections.authentication-required")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Colors.onShell
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      NText {
        text: I18n.tr("panels.connections.pin-instructions")
        pointSize: Style.fontSizeM
        color: Colors.onShellTertiary
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      NTextInput {
        id: pinInput
        Layout.fillWidth: true
        placeholderText: "123456"
        inputIconName: "key"
        onVisibleChanged: {
          if (visible) {
            text = "";
            inputItem.forceActiveFocus();
          }
        }
        inputItem.onEditingFinished: {
          if (text.length > 0) {
            BluetoothService.submitPin(text);
            text = "";
          }
        }
      }
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM
        NButton {
          text: I18n.tr("common.cancel")
          icon: "x"
          onClicked: BluetoothService.cancelPairing()
        }
        NButton {
          text: I18n.tr("common.confirm")
          icon: "check"
          backgroundColor: Colors.accent
          textColor: Colors.onAccent
          enabled: pinInput.text.length > 0
          onClicked: {
            BluetoothService.submitPin(pinInput.text);
            pinInput.text = "";
          }
        }
      }
    }
  }
}
