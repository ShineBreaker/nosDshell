import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.System
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

  baseSize: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screen?.name))
  bgSize: fashionMode ? Math.round(baseSize * 0.66) : -1
  applyUiScale: false
  customRadius: onShellSurface ? Style.radiusPopup : Style.radiusL
  colorBg: fashionMode ? Color.overlay("subtle") : (efficientMode ? "transparent" : (Settings.data.nightLight.enabled ? Color.mPrimary : Style.capsuleColor))
  colorFg: onShellSurface ? Color.onShell : (Settings.data.nightLight.enabled ? Color.mOnPrimary : Color.resolveColorKey(iconColorKey))
  border.color: Style.capsuleBorderColor
  border.width: fashionMode ? 0 : Style.capsuleBorderWidth

  icon: Settings.data.nightLight.enabled ? (Settings.data.nightLight.forced ? "nightlight-forced" : "nightlight-on") : "nightlight-off"
  iconSource: onShellSurface ? ThemeIcons.symbolicOnlyAny(["night-light-enabled", "night-light", "redshift-status-on"]) : ""
  recolorIcon: onShellSurface
  iconRatio: fashionMode ? 0.45 : (efficientMode ? 16.0 / baseSize : 0.48)
  tooltipText: I18n.tr("common.night-light")
  tooltipDirection: BarService.getTooltipDirection(screen?.name, root.section === "dock")
  onClicked: {
    // Check if wlsunset is available before enabling night light
    if (!ProgramCheckerService.wlsunsetAvailable) {
      ToastService.showWarning(I18n.tr("common.night-light"), I18n.tr("toast.night-light.not-installed"));
      return;
    }

    if (!Settings.data.nightLight.enabled) {
      Settings.data.nightLight.enabled = true;
      Settings.data.nightLight.forced = false;
    } else if (Settings.data.nightLight.enabled && !Settings.data.nightLight.forced) {
      Settings.data.nightLight.forced = true;
    } else {
      Settings.data.nightLight.enabled = false;
      Settings.data.nightLight.forced = false;
    }
  }

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
