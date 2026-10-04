import QtQuick
import QtQuick.Controls
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

  icon: "settings"
  iconSource: efficientMode ? ThemeIcons.symbolicForAny(["preferences-system", "applications-system"]) : ""
  iconRatio: efficientMode ? 16.0 / baseSize : 0.48
  tooltipText: {
    if (PanelService.getPanel("settingsPanel", screen)?.isPanelOpen) {
      return "";
    } else {
      return I18n.tr("tooltips.open-settings");
    }
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: efficientMode ? Style.radiusPopup : Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: efficientMode ? Color.onShell : iconColor
  colorBgHover: efficientMode ? Color.overlay("hover") : Color.mHover
  colorFgHover: efficientMode ? Color.onShell : Color.mOnHover
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
    if (Settings.data.ui.settingsPanelMode === "attached") {
      PanelService.getPanel("settingsPanel", screen)?.toggle(this);
    } else {
      PanelService.getPanel("settingsPanel", screen)?.toggle();
    }
  }
  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
