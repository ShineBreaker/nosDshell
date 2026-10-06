import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
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

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
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

  readonly property string iconColorKey: (widgetSettings.iconColor !== undefined) ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // "fashion" = DDE fashion dock presentation (square item, icon at 0.8)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool onShellSurface: efficientMode || fashionMode

  baseSize: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screenName))
  bgSize: fashionMode ? Math.round(baseSize * 0.66) : -1
  applyUiScale: false
  customRadius: onShellSurface ? Style.radiusPopup : Style.radiusL
  icon: "power"
  iconSource: onShellSurface ? ThemeIcons.symbolicOnlyAny(["system-shutdown", "system-log-out"]) : ""
  recolorIcon: onShellSurface
  iconRatio: fashionMode ? 0.45 : (efficientMode ? 16.0 / baseSize : 0.48)
  tooltipText: {
    if (PanelService.getPanel("sessionMenuPanel", screen)?.isPanelOpen)
      return "";
    else
      return I18n.tr("tooltips.session-menu");
  }
  tooltipDirection: BarService.getTooltipDirection(screenName)
  colorBg: onShellSurface ? Color.overlay("subtle") : Style.capsuleColor
  colorFg: onShellSurface ? Color.onShell : Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: fashionMode ? 0 : Style.capsuleBorderWidth

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

  onClicked: PanelService.getPanel("sessionMenuPanel", screen)?.toggle()
  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
