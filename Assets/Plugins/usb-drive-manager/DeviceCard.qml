import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

// Device row in the dock-popup shape (BtDeviceRow convention): transparent
// background with a hover overlay, leading icon, two-line text, trailing
// action buttons — no card chrome of its own.
Rectangle {
    id: root

    // ===== PROPERTIES =====
    property var device: null
    property var pluginApi: null
    property var mainInstance: null

    // Signals
    signal mountRequested(string devicePath, string deviceLabel)
    signal unmountRequested(string devicePath, string deviceLabel)
    signal ejectRequested(string devicePath, string parentPath, string deviceLabel)
    signal openRequested(string mountpoint)
    signal copyPathRequested(string mountpoint)

    // ===== COMPUTED =====
    readonly property string displayLabel: {
        if (!device) return ""
        if (device.label && device.label !== device.name) return device.label
        if (device.model) return device.model
        return device.name
    }

    readonly property string displaySubtitle: {
        if (!device) return ""
        const parts = []
        if (device.size) parts.push(device.size)
        if (device.fstype) parts.push(device.fstype.toUpperCase())
        if (device.vendor && device.vendor !== device.model) parts.push(device.vendor)
        return parts.join(" · ")
    }

    // ===== APPEARANCE =====
    color: rowHover.hovered ? Colors.overlay("hover") : "transparent"
    radius: Style.radiusRow
    implicitHeight: cardLayout.implicitHeight + Style.marginS * 2

    HoverHandler {
        id: rowHover
    }

    ColumnLayout {
        id: cardLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.marginS
        }
        spacing: Style.marginXS

        // ── Header Row ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            // USB icon
            NIcon {
                icon: "usb"
                pointSize: Style.fontSizeL
                color: device?.isMounted ? Colors.accent : Colors.onShellSecondary
            }

            // Label + subtitle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                NText {
                    Layout.fillWidth: true
                    text: root.displayLabel
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightMedium
                    color: Colors.onShell
                    elide: Text.ElideRight
                }

                NText {
                    Layout.fillWidth: true
                    text: root.displaySubtitle
                    pointSize: Style.fontSizeXS
                    color: Colors.onShellSecondary
                    elide: Text.ElideRight
                }
            }

            // ── Action Buttons ───────────────────────────────────────────────

            // Open in file browser (only when mounted)
            NIconButton {
                visible: device?.isMounted ?? false
                icon: "folder-open"
                tooltipText: pluginApi?.tr("device.action-open")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: "transparent"
                colorFg: Colors.onShellSecondary
                colorBgHover: Colors.overlay("hover")
                colorFgHover: Colors.onShell
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.openRequested(device.mountpoint)
            }

            // Copy path (only when mounted)
            NIconButton {
                visible: device?.isMounted ?? false
                icon: "copy"
                tooltipText: pluginApi?.tr("device.action-copy-path")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: "transparent"
                colorFg: Colors.onShellSecondary
                colorBgHover: Colors.overlay("hover")
                colorFgHover: Colors.onShell
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.copyPathRequested(device.mountpoint)
            }

            // Mount (only when not mounted)
            NIconButton {
                visible: !(device?.isMounted ?? false)
                icon: "plug-connected"
                tooltipText: pluginApi?.tr("device.action-mount")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: "transparent"
                colorFg: Colors.onShellSecondary
                colorBgHover: Colors.overlay("hover")
                colorFgHover: Colors.onShell
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.mountRequested(device.path, root.displayLabel)
            }

            // Unmount
            NIconButton {
                visible: device?.isMounted ?? false
                icon: "plug-connected-x"
                tooltipText: pluginApi?.tr("device.action-unmount")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: "transparent"
                colorFg: Colors.onShellSecondary
                colorBgHover: Colors.overlay("hover")
                colorFgHover: Colors.onShell
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.unmountRequested(device.path, root.displayLabel)
            }

            // Eject (safe remove)
            NIconButton {
                icon: "player-eject"
                tooltipText: pluginApi?.tr("device.action-eject")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: "transparent"
                colorFg: Colors.onShellSecondary
                colorBgHover: Colors.overlay("hover")
                colorFgHover: Colors.alert
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.ejectRequested(device.path, device.parentPath, root.displayLabel)
            }
        }

        // ── Mountpoint + usage (mounted only) ───────────────────────────────
        NText {
            visible: device?.isMounted ?? false
            Layout.fillWidth: true
            text: device?.mountpoint || ""
            pointSize: Style.fontSizeXS
            color: Colors.onShellSecondary
            elide: Text.ElideMiddle
        }

        NLinearGauge {
            visible: device?.isMounted ?? false
            Layout.fillWidth: true
            Layout.preferredHeight: Style.marginXS
            orientation: Qt.Horizontal
            ratio: (device?.usedPercent ?? 0) / 100
            fillColor: (device?.usedPercent ?? 0) > 90 ? Colors.alert
                     : (device?.usedPercent ?? 0) > 75 ? Colors.attention
                     : Colors.accent
        }

        // Usage text
        RowLayout {
            visible: device?.isMounted ?? false
            Layout.fillWidth: true

            NText {
                text: device?.usedSize ?? ""
                    ? pluginApi?.tr("device.used", { size: device?.usedSize ?? "" })
                    : pluginApi?.tr("device.loading")
                pointSize: Style.fontSizeXXS
                color: Colors.onShellSecondary
            }

            Item { Layout.fillWidth: true }

            NText {
                text: device?.freeSize ?? ""
                    ? pluginApi?.tr("device.free", { size: device?.freeSize ?? "" })
                    : ""
                pointSize: Style.fontSizeXXS
                color: Colors.onShellSecondary
            }
        }
    }
}
