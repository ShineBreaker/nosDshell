import Quickshell
import qs.Commons
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
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // "fashion" = DDE fashion dock presentation (square item, icon at 0.8)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool onShellSurface: efficientMode || fashionMode

  icon: "dark-mode"
  iconSource: onShellSurface ? ThemeIcons.symbolicOnlyAny(["dark-mode", "preferences-desktop-theme"]) : ""
  recolorIcon: onShellSurface
  iconRatio: fashionMode ? 0.45 : (efficientMode ? 16.0 / baseSize : 0.48)
  tooltipText: Settings.data.colorSchemes.darkMode ? I18n.tr("tooltips.switch-to-light-mode") : I18n.tr("tooltips.switch-to-dark-mode")
  tooltipDirection: BarService.getTooltipDirection(screen?.name, root.section === "dock")
  baseSize: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screen?.name))
  bgSize: fashionMode ? Math.round(baseSize * 0.66) : -1
  applyUiScale: false
  customRadius: onShellSurface ? Style.radiusPopup : Style.radiusL
  colorBg: fashionMode ? Color.overlay("subtle") : (efficientMode ? "transparent" : Style.capsuleColor)
  colorFg: onShellSurface ? Color.onShell : Color.resolveColorKey(iconColorKey)
  onClicked: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode

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

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
