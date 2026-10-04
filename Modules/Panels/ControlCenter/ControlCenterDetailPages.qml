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

  readonly property real listWidth: Math.max(1, root.width)

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
      spacing: 0

      Item {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginS
        Layout.rightMargin: Style.marginS
        Layout.preferredHeight: Style.detailRowHeight

        RowLayout {
          anchors.fill: parent
          spacing: Style.marginS

          NIcon {
            icon: NetworkService.wifiEnabled ? "wifi" : "wifi-off"
            pointSize: Style.fontSizeXL
            color: NetworkService.wifiEnabled ? Color.accent : Color.onShellSecondary
          }

          NText {
            Layout.fillWidth: true
            text: I18n.tr("common.wifi")
            pointSize: Style.fontSizeM
          }

          NToggle {
            label: ""
            checked: NetworkService.wifiEnabled
            enabled: !NetworkService.airplaneModeEnabled
            onToggled: checked => NetworkService.setWifiEnabled(checked)
          }
        }
      }

      HD {}
      HD { text: I18n.tr("common.available") }

      Repeater {
        model: NetworkService.wifiEnabled ? root.wifiRows : []

        delegate: DetailRow {
          required property var modelData
          width: root.listWidth
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
      spacing: 0

      Item {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginS
        Layout.rightMargin: Style.marginS
        Layout.preferredHeight: Style.detailRowHeight

        RowLayout {
          anchors.fill: parent
          spacing: Style.marginS

          NIcon {
            icon: BluetoothService.enabled ? "bluetooth" : "bluetooth-off"
            pointSize: Style.fontSizeXL
            color: BluetoothService.enabled ? Color.accent : Color.onShellSecondary
          }

          NText {
            Layout.fillWidth: true
            text: I18n.tr("common.bluetooth")
            pointSize: Style.fontSizeM
          }

          NToggle {
            label: ""
            checked: BluetoothService.enabled
            enabled: !NetworkService.airplaneModeEnabled
            onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
          }
        }
      }

      HD {}

      Repeater {
        model: BluetoothService.enabled ? root.bluetoothRows : []

        delegate: DetailRow {
          required property var modelData
          width: root.listWidth
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
      spacing: 0

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

      HD {}

      Item {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginS
        Layout.rightMargin: Style.marginS
        Layout.preferredHeight: Style.detailRowHeight

        RowLayout {
          anchors.fill: parent
          spacing: Style.marginS

          NIcon {
            icon: Settings.data.nightLight.enabled ? "nightlight-on" : "nightlight-off"
            pointSize: Style.fontSizeXL
            color: Settings.data.nightLight.enabled ? Color.accent : Color.onShellSecondary
          }

          NText {
            Layout.fillWidth: true
            text: I18n.tr("common.night-light")
            pointSize: Style.fontSizeM
          }

          NToggle {
            label: ""
            checked: Settings.data.nightLight.enabled
            enabled: ProgramCheckerService.wlsunsetAvailable
            onToggled: checked => {
              Settings.data.nightLight.enabled = checked;
              Settings.data.nightLight.forced = false;
            }
          }
        }
      }
    }

    // ---- VPN ----
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.page === "vpn"
      spacing: 0

      HD {}

      Repeater {
        model: root.vpnRows

        delegate: DetailRow {
          required property var modelData
          width: root.listWidth
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

  // 1 px separator using overlay("hover") — DESIGN §3.5.4
  component HD: Item {
    property string text: ""
    Layout.fillWidth: true
    Layout.preferredHeight: text !== "" ? 24 : 1
    visible: true

    NText {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.marginM
      anchors.rightMargin: Style.marginS
      text: parent.text
      pointSize: Style.fontSizeS
      color: Color.onShellSecondary
      visible: parent.text !== ""
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 1
      color: Color.overlay("hover")
      visible: parent.text === ""
    }
  }

  // A 36 px list row (§3.5.4): glyph, name, secondary text, accent ✓ when active.
  // The row's label is `rowText` rather than `text` so the NText inside the
  // row isn't shadowed by an Item-level `text` property.
  component DetailRow: Item {
    property string glyph: ""
    property color glyphColor: Color.onShellSecondary
    property string rowText: ""
    property string secondary: ""
    property color secondaryColor: Color.onShellTertiary
    property bool check: false
    signal clicked()

    height: Style.detailRowHeight

    Rectangle {
      anchors.fill: parent
      color: rowMouse.containsMouse ? Color.overlay("hover") : "transparent"
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 1
      color: Color.overlay("hover")
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.marginS
      anchors.rightMargin: Style.marginS
      spacing: Style.marginS

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
        verticalAlignment: Text.AlignVCenter
        text: rowText
        pointSize: Style.fontSizeM
        color: Color.onShell
        elide: Text.ElideRight
      }

      NText {
        visible: secondary !== ""
        verticalAlignment: Text.AlignVCenter
        text: secondary
        pointSize: Style.fontSizeS
        color: secondaryColor
        elide: Text.ElideRight
      }

      NIcon {
        visible: check
        icon: "check"
        pointSize: Style.fontSizeL
        color: Color.accent
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
  }
}
