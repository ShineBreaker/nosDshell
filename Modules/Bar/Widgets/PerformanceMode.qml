import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.Power
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  // "fashion" = DDE fashion dock presentation (icon-only tile)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  baseSize: fashionMode ? Style.dockPluginCellSize : Style.getCapsuleHeightForScreen(screen?.name)
  bgSize: fashionMode ? Style.dockPluginTileSize : -1
  applyUiScale: false
  customRadius: fashionMode ? Style.radiusPopup : Style.radiusL
  iconRatio: fashionMode ? 0.45 : 0.48
  colorBg: fashionMode ? (Settings.data.dock.fusedPlugins ? "transparent" : Colors.overlay("subtle")) : (PowerProfileService.performanceMode ? Colors.mPrimary : Style.capsuleColor)
  colorFg: fashionMode ? Colors.onShell : (PowerProfileService.performanceMode ? Colors.mOnPrimary : Colors.resolveColorKey(iconColorKey))
  border.color: Style.capsuleBorderColor
  border.width: fashionMode ? 0 : Style.capsuleBorderWidth

  icon: PowerProfileService.performanceMode ? "rocket" : "rocket-off"
  tooltipText: PowerProfileService.performanceMode ? I18n.tr("tooltips.performance-mode-enabled") : I18n.tr("tooltips.performance-mode-disabled")
  tooltipDirection: BarService.getTooltipDirection(screen?.name, root.section === "dock")
  onClicked: PowerProfileService.togglePerformanceMode()

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
