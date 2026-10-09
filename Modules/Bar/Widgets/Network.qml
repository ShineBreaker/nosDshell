import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings // For SettingsPanel
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: Settings.getWidgetSettings(screenName, section, sectionWidgetIndex)

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : widgetMetadata.displayMode
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // "fashion" = DDE fashion dock presentation (square item, icon at 0.8)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"

  // Map the current glyph to a freedesktop symbolic name (DDE status icons)
  function symbolicName() {
    switch (NetworkService.getIcon()) {
    case "wifi":
      return "network-wireless-signal-excellent";
    case "wifi-3":
      return "network-wireless-signal-good";
    case "wifi-2":
      return "network-wireless-signal-ok";
    case "wifi-1":
      return "network-wireless-signal-low";
    case "wifi-0":
      return "network-wireless-signal-none";
    case "wifi-exclamation":
    case "wifi-question":
      return "network-wireless-acquiring";
    case "wifi-off":
      return "network-wireless-disabled";
    case "ethernet":
      return "network-wired";
    case "ethernet-exclamation":
    case "ethernet-question":
      return "network-wired-limited";
    case "ethernet-off":
      return "network-wired-offline";
    case "plane":
      return "airplane-mode";
    default:
      return "";
    }
  }

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarWidgetSettingsMenu {
    id: contextMenu

    widget: root

    extraModel: [
      {
        "label": NetworkService.wifiEnabled ? I18n.tr("actions.disable-wifi") : I18n.tr("actions.enable-wifi"),
        "action": "toggle-wifi",
        "icon": NetworkService.wifiEnabled ? "wifi-off" : "wifi",
        "enabled": !NetworkService.airplaneModeEnabled && NetworkService.wifiAvailable
      },
      {
        "label": I18n.tr("common.wifi") + " " + I18n.tr("tooltips.open-settings"),
        "action": "wifi-settings",
        "icon": "settings"
      }
    ]

    onExtraActionTriggered: (action, item) => {
                              if (action === "toggle-wifi") {
                                NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
                              } else if (action === "wifi-settings") {
                                SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 0, screen);
                              }
                            }
  }

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)
    icon: NetworkService.getIcon()
    iconSource: root.onShellSurface ? ThemeIcons.symbolicOnly(root.symbolicName()) : ""
    dockPresentation: root.dockPresentation
    text: NetworkService.getStatusText(false)
    autoHide: false
    forceOpen: !isBarVertical && root.displayMode === "alwaysShow"
    forceClose: isBarVertical || root.displayMode === "alwaysHide" || text === ""
    onClicked: {
      var panel = PanelService.getPanel("networkPanel", screen);
      panel?.toggle(this);
    }
    onRightClicked: {
      PanelService.showContextMenu(contextMenu, pill, screen);
    }
    tooltipText: {
      if (PanelService.getPanel("networkPanel", screen)?.isPanelOpen) {
        return "";
      }
      return NetworkService.getStatusText(true);
    }
  }
}
