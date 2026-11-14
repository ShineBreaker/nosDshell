import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  dimsBackground: false

  preferredWidth: Math.round(300 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    property real contentPreferredHeight: Math.min(Math.min(mainLayout.implicitHeight, Style.popupListMaxHeight) + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    function disconnectDevice(device) {
      if (device.blocked) {
        device.blocked = false;
      } else {
        device.disconnect();
      }
    }

    // Device lists — same filtering as BluetoothSubTab
    readonly property var _allDevices: {
      if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
        return [];
      return BluetoothService.adapter.devices.values;
    }

    readonly property var connectedDevices: {
      var filtered = _allDevices.filter(dev => dev && !dev.blocked && dev.connected);
      return BluetoothService.sortDevices(BluetoothService.dedupeDevices(filtered));
    }

    readonly property var pairedDevices: {
      var filtered = _allDevices.filter(dev => dev && !dev.blocked && !dev.connected && (dev.paired || dev.trusted));
      return BluetoothService.sortDevices(BluetoothService.dedupeDevices(filtered));
    }

    readonly property var unnamedAvailableDevices: {
      return _allDevices.filter(dev => dev && !dev.blocked && !dev.paired && !dev.trusted);
    }

    readonly property var availableDevices: {
      var list = unnamedAvailableDevices;
      if (Settings.data.network.bluetoothHideUnnamedDevices) {
        list = list.filter(function (dev) {
          var s = String(dev.name || dev.deviceName || "").trim().toLowerCase();
          return s.length > 0 && s !== "unknown" && s !== "unnamed" && s !== "n/a" && s !== "na";
        });
      }
      return list;
    }

    NScrollView {
      id: scrollView
      anchors.fill: parent
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false

      ColumnLayout {
        id: mainLayout
        width: scrollView.availableWidth
        spacing: Style.marginS

        // Toggle switch row + auto-connect + settings gear
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.quickPanelRowHeight
          Layout.topMargin: Style.marginS
          visible: BluetoothService.bluetoothAvailable

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginS
            spacing: Style.marginXS

            NIcon {
              icon: "bluetooth"
              pointSize: Style.fontSizeXL
              color: BluetoothService.enabled ? Colors.accent : Colors.onShellSecondary
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("common.bluetooth")
              pointSize: Style.fontSizeM
              elide: Text.ElideRight
            }

            NIconButton {
              icon: Settings.data.network.bluetoothAutoConnect ? "bluetooth-connected" : "bluetooth"
              colorFg: Settings.data.network.bluetoothAutoConnect ? Colors.accent : Colors.onShellTertiary
              tooltipText: Settings.data.network.bluetoothAutoConnect ? I18n.tr("tooltips.bluetooth-auto-connect-on") : I18n.tr("tooltips.bluetooth-auto-connect-off")
              onClicked: Settings.data.network.bluetoothAutoConnect = !Settings.data.network.bluetoothAutoConnect
            }

            NIconButton {
              icon: "settings"
              colorFg: Colors.onShell
              tooltipText: I18n.tr("tooltips.open-settings")
              onClicked: SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 1, screen)
            }

            // DSwitchButton at the end of the switch row
            NToggle {
              Layout.fillWidth: false
              label: ""
              checked: BluetoothService.enabled
              enabled: !NetworkService.airplaneModeEnabled && BluetoothService.bluetoothAvailable
              onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
            }
          }
        }

        NText {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          visible: !BluetoothService.bluetoothAvailable
          text: I18n.tr("bluetooth.panel.unavailable")
          pointSize: Style.fontSizeS
          color: Colors.onShellTertiary
        }

        // ---- Connected devices ----
        NPanelSection {
          text: I18n.tr("bluetooth.panel.connected-devices")
          Layout.fillWidth: true
          visible: connectedDevices.length > 0
        }

        Repeater {
          // Model is index keys, not the entries: boxing the JS-array model
          // turns the BluetoothDevice refs into raw pointers (CODING_STANDARDS
          // "QML 规则"). The delegate resolves the live JS entry itself.
          model: panelContent.connectedDevices.map((_, i) => i)
          delegate: BtDeviceRow {
            devices: panelContent.connectedDevices
            onDisconnectRequested: device => panelContent.disconnectDevice(device)
            onDetailsRequested: device => SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 1, screen)
          }
        }

        // ---- Paired devices ----
        NPanelSection {
          text: I18n.tr("bluetooth.panel.paired-devices")
          Layout.fillWidth: true
          visible: pairedDevices.length > 0
        }

        Repeater {
          // Index-key model — see the comment on the connected-devices
          // Repeater above (CODING_STANDARDS "QML 规则").
          model: panelContent.pairedDevices.map((_, i) => i)
          delegate: BtDeviceRow {
            devices: panelContent.pairedDevices
            onDisconnectRequested: device => panelContent.disconnectDevice(device)
            onDetailsRequested: device => SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 1, screen)
          }
        }

        // ---- Available devices ----
        NPanelSection {
          text: I18n.tr("bluetooth.panel.available-devices")
          Layout.fillWidth: true
          visible: BluetoothService.enabled
        }

        NText {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          visible: BluetoothService.enabled && panelContent.availableDevices.length === 0 && !BluetoothService.scanningActive
          text: I18n.tr("bluetooth.panel.no-devices")
          pointSize: Style.fontSizeS
          color: Colors.onShellTertiary
        }

        Repeater {
          // Index-key model — see the comment on the connected-devices
          // Repeater above (CODING_STANDARDS "QML 规则").
          model: panelContent.availableDevices.map((_, i) => i)
          delegate: BtDeviceRow {
            devices: panelContent.availableDevices
            onDisconnectRequested: device => panelContent.disconnectDevice(device)
          }
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }
  }
}
