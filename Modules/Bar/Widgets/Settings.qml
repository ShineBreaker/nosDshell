import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
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

  readonly property string valueIconColor: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  readonly property color iconColor: Color.resolveColorKey(valueIconColor)
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // "fashion" = DDE fashion dock presentation (square item, icon at 0.8)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool onShellSurface: efficientMode || fashionMode

  icon: "settings"
  iconSource: onShellSurface ? ThemeIcons.symbolicOnlyAny(["preferences-system", "applications-system"]) : ""
  recolorIcon: onShellSurface
  iconRatio: fashionMode ? 0.45 : (efficientMode ? 16.0 / baseSize : 0.48)
  tooltipText: {
    // The settings surface depends on the panel mode (controlCenter → the
    // frame's all-settings page; window → FloatingWindow; else this panel).
    const mode = Settings.data.ui.settingsPanelMode;
    var open = false;
    if (mode === "controlCenter")
      open = PanelService.getPanel("controlCenterPanel", screen)?.isPanelOpen ?? false;
    else if (mode === "window")
      open = SettingsPanelService.isWindowOpen;
    else
      open = PanelService.getPanel("settingsPanel", screen)?.isPanelOpen ?? false;
    return open ? "" : I18n.tr("tooltips.open-settings");
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screen?.name))
  bgSize: fashionMode ? Math.round(baseSize * 0.66) : -1
  applyUiScale: false
  customRadius: onShellSurface ? Style.radiusPopup : Style.radiusL
  colorBg: fashionMode ? Color.overlay("subtle") : (efficientMode ? "transparent" : Style.capsuleColor)
  colorFg: onShellSurface ? Color.onShell : iconColor
  colorBgHover: onShellSurface ? Color.overlay("hover") : Color.mHover
  colorFgHover: onShellSurface ? Color.onShell : Color.mOnHover
  colorBorder: Style.capsuleBorderColor
  colorBorderHover: Style.capsuleBorderColor

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

  onClicked: {
    // Route through the service: "controlCenter" opens the DDE all-settings
    // page inside the control-center frame, not this panel.
    SettingsPanelService.toggle(SettingsPanel.Tab.General, -1, screen);
  }
  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
