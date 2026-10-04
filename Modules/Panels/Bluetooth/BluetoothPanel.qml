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

  preferredWidth: Math.round(300 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    property real contentPreferredHeight: Math.min(mainLayout.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

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
      contentWidth: availableWidth

      ColumnLayout {
        id: mainLayout
        width: scrollView.availableWidth
        spacing: Style.marginS

        // Toggle switch row + auto-connect + settings gear
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
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
              color: BluetoothService.enabled ? Color.accent : Color.onShellSecondary
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("common.bluetooth")
              pointSize: Style.fontSizeM
              elide: Text.ElideRight
            }

            NIconButton {
              icon: Settings.data.network.bluetoothAutoConnect ? "bluetooth-connected" : "bluetooth"
              colorFg: Settings.data.network.bluetoothAutoConnect ? Color.accent : Color.onShellTertiary
              tooltipText: Settings.data.network.bluetoothAutoConnect ? I18n.tr("tooltips.bluetooth-auto-connect-on") : I18n.tr("tooltips.bluetooth-auto-connect-off")
              onClicked: Settings.data.network.bluetoothAutoConnect = !Settings.data.network.bluetoothAutoConnect
            }

            NIconButton {
              icon: "settings"
              colorFg: Color.onShell
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
          color: Color.onShellTertiary
        }

        // ---- Connected devices ----
        NPanelSection {
          text: I18n.tr("bluetooth.panel.connected-devices")
          Layout.fillWidth: true
          visible: connectedDevices.length > 0
        }

        Repeater {
          model: connectedDevices
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Style.radiusRow
            color: connRowMouse.containsMouse ? Color.overlay("hover") : "transparent"

            MouseArea {
              id: connRowMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: panelContent.disconnectDevice(modelData)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: BluetoothService.getDeviceIcon(modelData)
                pointSize: Style.fontSizeXL
                color: Color.onShell
              }

              NText {
                Layout.fillWidth: true
                text: modelData.name || modelData.deviceName
                pointSize: Style.fontSizeM
                elide: Text.ElideRight
              }

              NIcon {
                icon: "check"
                pointSize: Style.fontSizeXL
                color: Color.accent
              }

              NIconButton {
                icon: "bluetooth-off"
                colorFg: Color.onShell
                onClicked: panelContent.disconnectDevice(modelData)
              }

              NIconButton {
                icon: "trash"
                colorFg: Color.onShell
                onClicked: BluetoothService.forgetDevice(modelData)
              }
            }
          }
        }

        // ---- Paired devices ----
        NPanelSection {
          text: I18n.tr("bluetooth.panel.paired-devices")
          Layout.fillWidth: true
          visible: pairedDevices.length > 0
        }

        Repeater {
          model: pairedDevices
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Style.radiusRow
            color: btRowMouse.containsMouse ? Color.overlay("hover") : "transparent"

            MouseArea {
              id: btRowMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                if (modelData.connected) {
                  panelContent.disconnectDevice(modelData);
                } else {
                  BluetoothService.connectDeviceWithTrust(modelData);
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: BluetoothService.getDeviceIcon(modelData)
                pointSize: Style.fontSizeXL
                color: Color.onShell
                visible: icon !== ""
              }

              NText {
                Layout.fillWidth: true
                text: modelData.name || modelData.deviceName
                pointSize: Style.fontSizeM
                elide: Text.ElideRight
              }

              NIcon {
                visible: modelData.connected
                icon: "check"
                pointSize: Style.fontSizeXL
                color: Color.accent
              }

              NIconButton {
                icon: "bluetooth-off"
                colorFg: Color.onShell
                visible: modelData.connected || modelData.pairing || modelData.state === BluetoothDeviceState.Disconnecting
                onClicked: panelContent.disconnectDevice(modelData)
              }

              NIconButton {
                icon: "info-circle"
                colorFg: Color.onShell
                onClicked: BluetoothService.toggleDeviceInfo(modelData)
              }

              NIconButton {
                icon: "trash"
                colorFg: Color.onShell
                onClicked: BluetoothService.forgetDevice(modelData)
              }
            }
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
          color: Color.onShellTertiary
        }

        Repeater {
          model: panelContent.availableDevices
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Style.radiusRow
            color: availRowMouse.containsMouse ? Color.overlay("hover") : "transparent"

            MouseArea {
              id: availRowMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: BluetoothService.connectDeviceWithTrust(modelData)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: BluetoothService.getDeviceIcon(modelData)
                pointSize: Style.fontSizeXL
                color: Color.onShell
                visible: icon !== ""
              }

              NText {
                Layout.fillWidth: true
                text: modelData.name || modelData.deviceName
                pointSize: Style.fontSizeM
                elide: Text.ElideRight
              }

              NIconButton {
                icon: BluetoothService.isDeviceBusy(modelData) ? "bluetooth-connecting" : "link"
                colorFg: Color.onShell
                tooltipText: BluetoothService.isDeviceBusy(modelData) ? "" : I18n.tr("tooltips.pair")
                onClicked: {
                  if (!BluetoothService.isDeviceBusy(modelData)) {
                    BluetoothService.connectDeviceWithTrust(modelData);
                  }
                }
              }
            }
          }
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }
  }
}
