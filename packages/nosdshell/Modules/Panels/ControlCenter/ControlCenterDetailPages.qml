import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import qs.Commons
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterDetailPages - quick-control detail pages (DESIGN §3.5.2/§3.5.4).
*
* Wi-Fi / Bluetooth / VPN lists: 36 px rows, 1 px overlay("hover")
* separators, connected row shows an accent ✓ and a signal glyph. Logic comes
* from the same services as the standalone panels, so the list and the panel
* can never disagree about state.
*/
Item {
  id: root

  property var screen: null
  property string page: "wifi"

  // Wi-Fi rows: connected first, then saved, then the rest, strongest signal first
  readonly property var wifiRows: {
    const nets = Object.values(NetworkService.networks ?? {});
    const connected = nets.filter(n => n.connected);
    const saved = nets.filter(n => !n.connected && n.existing);
    const rest = nets.filter(n => !n.connected && !n.existing);
    return connected.concat(saved, rest);
  }

  readonly property var bluetoothRows: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    return BluetoothService.sortDevices(BluetoothService.dedupeDevices(BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked)));
  }

  readonly property var vpnRows: Object.values(VPNService.connections ?? {})

  implicitHeight: body.implicitHeight

  // Bluetooth discovery follows the page through BluetoothService's owner
  // accounting (startDiscovery/stopDiscovery): acquire while the bluetooth
  // list is showing AND the panel is actually open, release otherwise. The
  // detail page is keep-alive inside the control center, so leaving the
  // page, closing the panel and destroying the component all must drop
  // ownership — setScanActive(true) alone had no stop path at all.
  readonly property bool effectivelyVisible: root.visible && Window.window && Window.window.visible
  readonly property bool btScanWanted: page === "bluetooth" && effectivelyVisible && BluetoothService.enabled

  function _syncBtScan() {
    if (btScanWanted)
      BluetoothService.startDiscovery(root);
    else
      BluetoothService.stopDiscovery(root);
  }

  onBtScanWantedChanged: _syncBtScan()

  Component.onCompleted: {
    if (page === "wifi" && NetworkService.wifiEnabled) {
      NetworkService.scan();
      NetworkService.refreshActiveWifiDetails();
    } else if (page === "vpn") {
      VPNService.refresh();
    }
    _syncBtScan();
  }

  Component.onDestruction: BluetoothService.stopDiscovery(root)

  Connections {
    target: BluetoothService.adapter
    ignoreUnknownSignals: true
    function onDevicesChanged() {
      // Re-assert while on the page: BlueZ may have stopped discovery on
      // its own, and each discovery round changes the device set.
      if (root.btScanWanted)
        BluetoothService.startDiscovery(root);
    }
  }

  Connections {
    target: root
    function onPageChanged() {
      if (page === "wifi" && NetworkService.wifiEnabled) {
        NetworkService.scan();
        NetworkService.refreshActiveWifiDetails();
      } else if (page === "vpn") {
        VPNService.refresh();
      }
      // Bluetooth is driven solely by btScanWanted (page is one of its
      // inputs), so page switches go through onBtScanWantedChanged.
    }
  }

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 0

    // ---- Wi-Fi: power switch row + network rows ----
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.page === "wifi"
      spacing: Style.settingsGroupGap

      NToggle {
        label: I18n.tr("common.wifi")
        icon: NetworkService.wifiEnabled ? "wifi" : "wifi-off"
        checked: NetworkService.wifiEnabled
        enabled: !NetworkService.airplaneModeEnabled
        onToggled: checked => NetworkService.setWifiEnabled(checked)
      }

      NHeader {
        label: I18n.tr("common.available")
      }

      Repeater {
        model: NetworkService.wifiEnabled ? root.wifiRows : []

        delegate: DetailRow {
          required property var modelData
          glyph: NetworkService.getSignalInfo(modelData.signal, modelData.connected).icon
          glyphColor: modelData.connected ? Colors.accent : Colors.onShellSecondary
          rowText: modelData.ssid
          secondary: modelData.connected ? I18n.tr("common.connected") : (NetworkService.isSecured(modelData.security) ? modelData.security : I18n.tr("wifi.panel.security-open"))
          secondaryColor: Colors.onShellTertiary
          check: modelData.connected
          onClicked: {
            if (modelData.connected) {
              NetworkService.disconnect(modelData.ssid);
            } else {
              NetworkService.scan();
              NetworkService.connect(modelData.ssid, "");
            }
          }
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginS
        Layout.rightMargin: Style.marginS
        Layout.topMargin: Style.marginS
        visible: NetworkService.wifiEnabled && root.wifiRows.length === 0
        text: I18n.tr("wifi.panel.no-networks")
        pointSize: Style.fontSizeS
        color: Colors.onShellTertiary
      }
    }

    // ---- Bluetooth: adapter switch row + device rows ----
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.page === "bluetooth"
      spacing: Style.settingsGroupGap

      NToggle {
        label: I18n.tr("common.bluetooth")
        icon: BluetoothService.enabled ? "bluetooth" : "bluetooth-off"
        checked: BluetoothService.enabled
        enabled: !NetworkService.airplaneModeEnabled
        onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
      }

      Repeater {
        // Model is index keys, not the entries: boxing the JS-array model
        // turns the BluetoothDevice refs into raw pointers (CODING_STANDARDS
        // "QML 规则"). The delegate resolves the live JS entry itself.
        model: BluetoothService.enabled ? root.bluetoothRows.map((_, i) => i) : []

        delegate: DetailRow {
          readonly property var entry: root.bluetoothRows[index]
          glyph: "bt-device-generic"
          glyphColor: entry?.connected ? Colors.accent : Colors.onShellSecondary
          rowText: entry?.name || entry?.deviceName || I18n.tr("common.devices")
          secondary: entry?.connected ? I18n.tr("common.connected") : ""
          secondaryColor: Colors.onShellTertiary
          check: entry?.connected ?? false
          onClicked: {
            if (!entry)
              return;
            if (entry.connected) {
              entry.disconnect();
            } else {
              BluetoothService.connectToDevice(entry);
            }
          }
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginS
        Layout.rightMargin: Style.marginS
        Layout.topMargin: Style.marginS
        visible: BluetoothService.enabled && root.bluetoothRows.length === 0
        text: I18n.tr("bluetooth.panel.no-devices")
        pointSize: Style.fontSizeS
        color: Colors.onShellTertiary
      }
    }

    // ---- VPN ----
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.page === "vpn"
      spacing: Style.settingsGroupGap

      Repeater {
        model: root.vpnRows

        delegate: DetailRow {
          required property var modelData
          glyph: modelData.active ? "shield-lock" : "shield-off"
          glyphColor: modelData.active ? Colors.accent : Colors.onShellSecondary
          rowText: modelData.name
          secondary: modelData.active ? I18n.tr("common.connected") : ""
          secondaryColor: Colors.onShellTertiary
          check: modelData.active
          onClicked: VPNService.toggle(modelData.uuid)
        }
      }
    }
  }

  // A 36 px list row (DESIGN §3.5.4) reusing the settings-row chrome: glyph,
  // name, secondary text, accent check when active. An NDccRow, so these lists
  // share the row fill, hover, auto head/tail corners and (20, 10) padding.
  // The row's label is `rowText` rather than `text` so the NText inside the
  // row isn't shadowed by an Item-level `text` property.
  component DetailRow: NDccRow {
    property string glyph: ""
    property color glyphColor: Colors.onShellSecondary
    property string rowText: ""
    property string secondary: ""
    property color secondaryColor: Colors.onShellTertiary
    property bool check: false

    clickable: true

    NIcon {
      Layout.preferredWidth: Style.fontSizeXL
      Layout.preferredHeight: Style.fontSizeXL
      Layout.alignment: Qt.AlignVCenter
      icon: glyph
      color: glyphColor
    }

    NText {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignVCenter
      verticalAlignment: Text.AlignVCenter
      text: rowText
      pointSize: Style.fontSizeM
      color: Colors.onShell
      elide: Text.ElideRight
    }

    NText {
      visible: secondary !== ""
      Layout.alignment: Qt.AlignVCenter
      verticalAlignment: Text.AlignVCenter
      text: secondary
      pointSize: Style.fontSizeS
      color: secondaryColor
      elide: Text.ElideRight
    }

    NIcon {
      visible: check
      Layout.alignment: Qt.AlignVCenter
      icon: "check"
      pointSize: Style.fontSizeL
      color: Colors.accent
    }
  }
}
