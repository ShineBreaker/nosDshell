import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Hardware
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
  readonly property bool reverseScroll: Settings.data.general.reverseScroll
  property int wheelAccumulator: 0
  // Wheel over the power button adjusts this screen's display brightness.
  property var brightnessMonitor: {
    var _ = BrightnessService.monitors; // reactive dependency
    var __ = BrightnessService.ddcMonitors; // reactive dependency
    if (!screen)
      return null;
    return BrightnessService.getMonitorForScreen(screen) ?? null;
  }

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
  tooltipDirection: BarService.getTooltipDirection(screenName, root.section === "dock")
  colorBg: fashionMode ? Color.overlay("subtle") : (efficientMode ? "transparent" : Style.capsuleColor)
  colorFg: onShellSurface ? Color.onShell : Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: fashionMode ? 0 : Style.capsuleBorderWidth
  handleWheel: true

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
  onWheel: function (delta) {
    var monitor = brightnessMonitor;
    if (!monitor || !monitor.brightnessControlAvailable)
      return;

    // Hide tooltip as soon as the user starts scrolling to adjust brightness
    TooltipService.hide();

    if (root.reverseScroll)
      delta *= -1;

    wheelAccumulator += delta;
    if (wheelAccumulator >= 120) {
      wheelAccumulator = 0;
      monitor.increaseBrightness();
    } else if (wheelAccumulator <= -120) {
      wheelAccumulator = 0;
      monitor.decreaseBrightness();
    }
  }
}
