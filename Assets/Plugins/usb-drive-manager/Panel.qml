import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 300 * Style.uiScaleRatio
    // Same bounded-list rule as the built-in popups: the viewport follows
    // content up to Style.popupListMaxHeight and scrolls internally.
    property real contentPreferredHeight: Math.min(Math.min(mainLayout.implicitHeight, Style.popupListMaxHeight) + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)
    readonly property bool allowAttach: true
    anchors.fill: parent

    readonly property var screen: pluginApi?.panelOpenScreen
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var devices: mainInstance?.devices ?? []
    readonly property int mountedCount: mainInstance?.mountedCount ?? 0

    Component.onCompleted: {
        mainInstance?.refreshDevices()
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n " + JSON.stringify(text) + " | wl-copy"])
        ToastService.showNotice(
            pluginApi?.tr("notifications.path-copied"),
            text
        )
    }

    Item {
        id: panelContainer
        anchors.fill: parent

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

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.marginS
                    Layout.leftMargin: Style.marginM
                    Layout.rightMargin: Style.marginS
                    spacing: Style.marginM

                    NIcon {
                        icon: "usb"
                        pointSize: Style.fontSizeL
                        color: Colors.onShell
                    }

                    NText {
                        text: pluginApi?.tr("panel.title")
                        font.pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightMedium
                        color: Colors.onShell
                        Layout.fillWidth: true
                    }

                    NIconButton {
                        icon: "refresh"
                        baseSize: Style.baseWidgetSize * 0.8
                        tooltipText: pluginApi?.tr("panel.refresh")
                        onClicked: mainInstance?.refreshDevices()

                        RotationAnimation on rotation {
                            running: mainInstance?.loading ?? false
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                }

                // Empty state (text required — DESIGN §1.10: no icon-only empty)
                Item {
                    visible: root.devices.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: emptyColumn.implicitHeight + Style.marginL * 2

                    ColumnLayout {
                        id: emptyColumn
                        anchors.centerIn: parent
                        spacing: Style.marginS

                        NIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "usb"
                            pointSize: Style.fontSizeXXL
                            color: Colors.onShellSecondary
                            opacity: 0.4
                        }

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.empty")
                            pointSize: Style.fontSizeM
                            color: Colors.onShellSecondary
                        }

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.empty-hint")
                            pointSize: Style.fontSizeS
                            color: Colors.onShellSecondary
                            opacity: 0.7
                        }
                    }
                }

                // Device rows (Repeater like BtDeviceRow lists — implicitHeight
                // is correct at creation, unlike a delegate ListView's)
                Repeater {
                    model: root.devices

                    delegate: DeviceCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: Style.marginS
                        Layout.rightMargin: Style.marginS
                        device: modelData
                        pluginApi: root.pluginApi
                        mainInstance: root.mainInstance

                        onMountRequested: (path, label) => mainInstance?.mountDevice(path, label)
                        onUnmountRequested: (path, label) => mainInstance?.unmountDevice(path, label)
                        onEjectRequested: (path, parentPath, label) => mainInstance?.ejectDevice(path, parentPath, label)
                        onOpenRequested: mountpoint => mainInstance?.openInFileBrowser(mountpoint)
                        onCopyPathRequested: mountpoint => root.copyToClipboard(mountpoint)
                    }
                }

                // Footer
                ColumnLayout {
                    visible: root.devices.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.marginM
                    Layout.rightMargin: Style.marginM
                    Layout.bottomMargin: Style.marginS
                    spacing: Style.marginXS

                    Rectangle {
                        height: Math.max(1, Style.marginXXS)
                        color: Colors.separator
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NButton {
                            Layout.fillWidth: true
                            text: pluginApi?.tr("panel.unmount-all")
                            icon: "plug-connected-x"
                            enabled: mountedCount > 0
                            onClicked: mainInstance?.unmountAll()
                        }

                        NButton {
                            Layout.fillWidth: true
                            text: pluginApi?.tr("panel.eject-all")
                            icon: "player-eject"
                            enabled: root.devices.length > 0
                            onClicked: mainInstance?.ejectAll()
                        }
                    }
                }
            }
        }
    }
}
