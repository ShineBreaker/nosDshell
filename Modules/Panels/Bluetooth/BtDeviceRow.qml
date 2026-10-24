import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.Commons
import qs.Services.Networking
import qs.Widgets

// One device row for all three Bluetooth lists in the panel — connected, paired
// and available (DESIGN §3.2 弹出层列表): the whole row is the primary action
// (connect an open device, disconnect a connected one) and the trailing controls
// are secondary, surfacing only on the hovered row. The list already marks a
// connected device with the accent check and its status line, so a permanent
// column of disconnect / forget / details buttons on every row would only repeat
// that. The three sections differ solely in which entries they hold, so they
// share this component instead of each Repeater growing its own copy of the row.
Rectangle {
  id: root

  // The section's device list. Its Repeaters are modelled on index keys rather
  // than the entries themselves: boxing the JS-array model turns the
  // BluetoothDevice refs into raw pointers (CODING_STANDARDS "QML 规则"), so the
  // row resolves the live JS entry itself and repaints when the device changes.
  required property var devices
  required property int index

  readonly property var entry: devices[index]

  Layout.fillWidth: true
  Layout.preferredHeight: Style.quickPanelRowHeight

  readonly property bool connected: entry?.connected ?? false
  // Pairing or (dis)connecting: the row shows an in-row spinner and stops
  // taking taps while the adapter works on the device.
  readonly property bool busy: BluetoothService.isDeviceBusy(entry)
  readonly property bool pairing: entry?.pairing ?? false
  // Only a device we already paired or trusted can be forgotten, and only a
  // connected one has details worth opening.
  readonly property bool known: (entry?.paired ?? false) || (entry?.trusted ?? false)

  radius: Style.radiusRow
  color: rowHover.hovered ? Colors.overlay("hover") : "transparent"

  HoverHandler {
    id: rowHover
  }

  // Secondary actions live here so they never shift the name when they appear.
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginM
    anchors.rightMargin: Style.marginS
    spacing: Style.marginS

    NIcon {
      icon: BluetoothService.getDeviceIcon(root.entry)
      pointSize: Style.fontSizeXL
      color: Colors.onShell
      visible: icon !== ""
    }

    NText {
      Layout.fillWidth: true
      text: root.entry?.name || root.entry?.deviceName || ""
      pointSize: Style.fontSizeM
      elide: Text.ElideRight
    }

    // Status of the row's primary action, in words — the accent check alone
    // only says "connected", not "still working on it".
    NText {
      visible: root.connected || root.busy
      text: {
        if (root.pairing)
          return I18n.tr("common.pairing");
        if (root.entry?.state === BluetoothDevice.Disconnecting)
          return I18n.tr("common.disconnecting");
        if (root.busy)
          return I18n.tr("common.connecting");
        return I18n.tr("common.connected");
      }
      pointSize: Style.fontSizeS
      color: Colors.onShellSecondary
    }

    NIcon {
      visible: root.connected && !root.busy
      icon: "check"
      pointSize: Style.fontSizeXL
      color: Colors.accent
    }

    NBusyIndicator {
      visible: root.busy
      running: root.busy
      size: Style.fontSizeM
    }

    // Secondary actions (DESIGN §3.2): only on the hovered row.
    NIconButton {
      visible: rowHover.hovered && root.connected
      icon: "bluetooth-off"
      colorFg: Colors.onShell
      tooltipText: I18n.tr("common.disconnect")
      onClicked: root.disconnectRequested(root.entry)
    }

    NIconButton {
      visible: rowHover.hovered && root.known
      icon: "info-circle"
      colorFg: Colors.onShell
      onClicked: root.detailsRequested(root.entry)
    }

    NIconButton {
      visible: rowHover.hovered && root.known && !root.connected && !root.busy
      icon: "trash"
      colorFg: Colors.onShell
      onClicked: {
        if (root.entry)
          BluetoothService.forgetDevice(root.entry);
      }
    }
  }

  // The row itself is the primary action. A TapHandler rather than a MouseArea
  // so the row-end buttons above still take their own clicks.
  TapHandler {
    enabled: root.entry !== undefined && !root.busy
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onTapped: {
      if (root.connected) {
        root.disconnectRequested(root.entry);
      } else {
        BluetoothService.connectDeviceWithTrust(root.entry);
      }
    }
  }

  signal disconnectRequested(var device)
  signal detailsRequested(var device)
}
