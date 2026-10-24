import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    // ===== REQUIRED PROPERTIES =====
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // ===== DATA BINDING =====
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property int mountedCount: mainInstance?.mountedCount ?? 0
    readonly property int totalDevices: mainInstance?.devices?.length ?? 0
    readonly property bool hasDevices: totalDevices > 0
    readonly property bool hasMountedDevices: mountedCount > 0

    readonly property bool showBadge:
        pluginApi?.pluginSettings?.showBadge ??
        pluginApi?.manifest?.metadata?.defaultSettings?.showBadge ??
        true

    readonly property bool hideWhenEmpty:
        pluginApi?.pluginSettings?.hideWhenEmpty ??
        pluginApi?.manifest?.metadata?.defaultSettings?.hideWhenEmpty ??
        true

    readonly property bool shouldShow: !hideWhenEmpty || hasDevices

    // ===== ICON COLOR =====
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
    readonly property color iconColor: Colors.resolveColorKey(iconColorKey)

    // ===== VISIBILITY =====
    visible: shouldShow

    // ===== APPEARANCE =====
    icon: "usb"
    tooltipText: mainInstance?.buildTooltip()
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL

    colorBg: hasMountedDevices ? Colors.mPrimary : Style.capsuleColor
    colorFg: hasMountedDevices ? Colors.mOnPrimary : root.iconColor !== "transparent" ? root.iconColor : Colors.mOnSurface
    colorBgHover: Colors.mHover
    colorFgHover: Colors.mOnHover
    colorBorder: "transparent"
    colorBorderHover: "transparent"

    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Rectangle {
        visible: hasMountedDevices && showBadge
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.marginXXS
        anchors.rightMargin: Style.marginXXS
        width: badgeText.implicitWidth + Style.marginS
        height: badgeText.implicitHeight + Style.marginXS
        radius: Style.radiusRow
        color: Colors.mPrimary
        z: 1

        NText {
            id: badgeText
            anchors.centerIn: parent
            text: mountedCount
            pointSize: Style.fontSizeXXS
            color: Colors.mOnPrimary
            font.weight: Style.fontWeightMedium
        }
    }

    // ===== INTERACTIONS =====
    onClicked: {
        if (mainInstance) {
            mainInstance.refreshDevices()
        }
        if (pluginApi?.openPanel) {
            pluginApi.openPanel(screen, root)
        }
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen)
    }

    // ===== CONTEXT MENU =====
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("context.open"),
                "action": "open-panel",
                "icon": "apps"
            },
            {
                "label": pluginApi?.tr("context.refresh"),
                "action": "refresh",
                "icon": "refresh"
            },
            {
                "label": pluginApi?.tr("context.unmount-all"),
                "action": "unmount-all",
                "icon": "plug-connected-x"
            },
            {
                "label": pluginApi?.tr("context.eject-all"),
                "action": "eject-all",
                "icon": "player-eject"
            },
            {
                "label": pluginApi?.tr("context.settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)

            if (action === "open-panel") {
                mainInstance?.refreshDevices()
                if (pluginApi?.openPanel) pluginApi.openPanel(screen, root)
            } else if (action === "refresh") {
                mainInstance?.refreshDevices()
            } else if (action === "unmount-all") {
                mainInstance?.unmountAll()
            } else if (action === "eject-all") {
                mainInstance?.ejectAll()
            } else if (action === "settings") {
                if (pluginApi?.manifest) {
                    BarService.openPluginSettings(screen, pluginApi.manifest)
                }
            }
        }
    }
}
