import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterDetailPages - quick-control detail pages (DESIGN §3.5.2/§3.5.4).
*
* Wi-Fi / Bluetooth / Display / VPN lists: 36 px rows, 1 px overlay("hover")
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

  readonly property var brightnessMonitor: BrightnessService.getMonitorForScreen(root.screen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)) ?? null

  readonly property var vpnRows: Object.values(VPNService.connections ?? {})

  implicitHeight: body.implicitHeight

  Component.onCompleted: {
    if (page === "wifi" && NetworkService.wifiEnabled) {
      NetworkService.scan();
      NetworkService.refreshActiveWifiDetails();
    } else if (page === "vpn") {
      VPNService.refresh();
    }
  }

  Connections {
    target: BluetoothService.adapter
    ignoreUnknownSignals: true
    function onDevicesChanged() {
      if (root.page === "bluetooth")
        BluetoothService.setScanActive(true);
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
      } else if (page === "bluetooth") {
        BluetoothService.setScanActive(true);
      }
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
          glyphColor: modelData.connected ? Color.accent : Color.onShellSecondary
          rowText: modelData.ssid
          secondary: modelData.connected ? I18n.tr("common.connected") : (NetworkService.isSecured(modelData.security) ? modelData.security : I18n.tr("wifi.panel.security-open"))
          secondaryColor: Color.onShellTertiary
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
        model: BluetoothService.enabled ? root.bluetoothRows : []

        delegate: DetailRow {
          required property var modelData
          glyph: "bt-device-generic"
          glyphColor: modelData.connected ? Color.accent : Color.onShellSecondary
          rowText: modelData.name || modelData.deviceName || I18n.tr("common.devices")
          secondary: modelData.connected ? I18n.tr("common.connected") : ""
          secondaryColor: Color.onShellTertiary
          check: modelData.connected
          onClicked: {
            if (modelData.connected) {
              modelData.disconnect();
            } else {
              BluetoothService.connectToDevice(modelData);
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
        color: Color.onShellTertiary
      }
    }

    // ---- Display: per-monitor brightness + night light ----
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.page === "display"
      spacing: Style.settingsGroupGap

      Repeater {
        model: root.brightnessMonitor ? [root.brightnessMonitor] : []

        delegate: ColumnLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginS
            Layout.rightMargin: Style.marginS
            Layout.topMargin: Style.marginS
            text: modelData.name || I18n.tr("common.display")
            pointSize: Style.fontSizeS
            color: Color.onShellTertiary
            elide: Text.ElideRight
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginS
            Layout.rightMargin: Style.marginS
            Layout.topMargin: Style.marginS
            spacing: Style.marginS

            NIcon {
              icon: "brightness-low"
              pointSize: Style.fontSizeTitle
              color: Color.onShellSecondary
            }

            NSlider {
              Layout.fillWidth: true
              from: 0
              to: 1
              value: modelData.brightness ?? 0
              stepSize: 0.01
              heightRatio: 0.5
              onMoved: {
                modelData.setBrightness(value);
              }
              tooltipText: `${Math.round(value * 100)}%`
            }

            NIcon {
              icon: "brightness-high"
              pointSize: Style.fontSizeTitle
              color: Color.onShellSecondary
            }
          }
        }
      }

      NToggle {
        label: I18n.tr("common.night-light")
        icon: Settings.data.nightLight.enabled ? "nightlight-on" : "nightlight-off"
        checked: Settings.data.nightLight.enabled
        enabled: ProgramCheckerService.wlsunsetAvailable
        onToggled: checked => {
          Settings.data.nightLight.enabled = checked;
          Settings.data.nightLight.forced = false;
        }
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
          glyphColor: modelData.active ? Color.accent : Color.onShellSecondary
          rowText: modelData.name
          secondary: modelData.active ? I18n.tr("common.connected") : ""
          secondaryColor: Color.onShellTertiary
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
    property color glyphColor: Color.onShellSecondary
    property string rowText: ""
    property string secondary: ""
    property color secondaryColor: Color.onShellTertiary
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
      color: Color.onShell
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
      color: Color.accent
    }
  }
}
