import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Modules.Dock
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

  // Efficient (DDE taskbar) mode: icon-only, no capsule, one launcher icon
  // source shared with the fashion dock tile — the dock.launcher* keys
  // edited on the Dock settings page (DESIGN §1.9). The per-instance
  // widgetSettings lookup is dead in this mode: the synthesized taskbar
  // entry carries no user fields, and writes there land on the unused
  // bar.widgets store.
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  readonly property string customIcon: efficientMode ? Settings.data.dock.launcherIcon : (widgetSettings.icon || (widgetMetadata ? widgetMetadata.icon : "rocket"))
  // A user-picked glyph. The registry's default metadata icon ("rocket") is
  // only a Tabler stand-in: with no user choice the widget shows the shared
  // DDE launcher icon instead, the same one the fashion dock tile uses
  // (DESIGN §1.9).
  readonly property bool hasCustomIcon: efficientMode ? (Settings.data.dock.launcherIcon !== "") : (widgetSettings.icon !== undefined && widgetSettings.icon !== "")
  readonly property bool useDistroLogo: efficientMode ? Settings.data.dock.launcherUseDistroLogo : (widgetSettings.useDistroLogo !== undefined ? widgetSettings.useDistroLogo : widgetMetadata.useDistroLogo)
  readonly property string customIconPath: efficientMode ? "" : (widgetSettings.customIconPath !== undefined ? widgetSettings.customIconPath : widgetMetadata.customIconPath)
  // The dock.launcherIconColor key plays the colorize role on the taskbar:
  // "none" keeps the flat on-shell glyph, any scheme key tints it.
  readonly property bool enableColorization: efficientMode ? (Settings.data.dock.launcherIconColor !== "none") : (widgetSettings.enableColorization !== undefined ? widgetSettings.enableColorization : widgetMetadata.enableColorization)
  readonly property string colorizeSystemIcon: efficientMode ? Settings.data.dock.launcherIconColor : (widgetSettings.colorizeSystemIcon !== undefined ? widgetSettings.colorizeSystemIcon : widgetMetadata.colorizeSystemIcon)

  // True when the theme/glyph icon is hidden in favour of the overlay image
  // below (distro logo or an explicit icon path).
  readonly property bool usesOverlayIcon: useDistroLogo || customIconPath !== ""

  readonly property color iconColor: {
    if (!enableColorization)
      return Colors.mOnSurface;
    return Colors.resolveColorKey(colorizeSystemIcon);
  }

  // Without a user-picked glyph this bar widget shows the same launcher icon
  // as the fashion dock tile (DESIGN §1.9) rather than a Tabler glyph.
  icon: usesOverlayIcon ? "" : customIcon
  iconSource: (usesOverlayIcon || hasCustomIcon) ? "" : ThemeIcons.launcherIconPath()
  // Flat silhouette on the shell surface (efficient mode), full-colour on the
  // capsule — same split the other bar widgets use.
  recolorIcon: efficientMode
  tooltipText: I18n.tr("actions.open-launcher")
  tooltipDirection: BarService.getTooltipDirection(screenName, root.section === "dock")
  baseSize: efficientMode ? Style.getBarHeightForScreen(screenName) : Style.getCapsuleHeightForScreen(screenName)
  // dock.launcherIconSize sizes the launcher *item*: the efficient taskbar
  // glyph here and the fashion dock tile in DockContent. The fashion
  // status-bar capsule never reads it — its icon derives from the fixed
  // capsule height and a dock-sized px value would burst the capsule.
  readonly property int launcherIconPx: efficientMode ? Settings.data.dock.launcherIconSize : 0
  readonly property real launcherGlyphPx: launcherIconPx > 0 ? Math.max(8, launcherIconPx) : (efficientMode ? 16 : root.buttonSize * 0.48)
  iconRatio: launcherGlyphPx / Math.max(1, root.buttonSize)
  applyUiScale: false
  customRadius: efficientMode ? Style.radiusPopup : Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: efficientMode ? (enableColorization ? iconColor : Colors.onShell) : iconColor
  colorBgHover: efficientMode ? Colors.overlay("hover") : Colors.mHover
  colorFgHover: efficientMode ? (enableColorization ? iconColor : Colors.onShell) : Colors.mOnHover
  colorBorder: Style.capsuleBorderColor
  colorBorderHover: Style.capsuleBorderColor

  // Efficient mode uses the same dark arrowed launcher menu the fashion dock
  // shows (DESIGN §3.1.1): launcher settings + taskbar settings. The generic
  // widget-settings dialog is unreachable here — its writes land on the
  // synthesized taskbar entry, which carries no user fields.
  DockMenu {
    id: launcherDockMenu
    dockPosition: Settings.getTaskbarPositionForScreen(screenName)
    menuMode: "launcher"
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.launcher-settings"),
        "action": "launcher-settings",
        "icon": "adjustments"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "launcher-settings") {
                     SettingsPanelService.toggle(SettingsPanel.Tab.Launcher, -1, screen);
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onClicked: PanelService.toggleLauncher(screen)
  onMiddleClicked: PanelService.toggleLauncher(screen)
  onRightClicked: {
    TooltipService.hideImmediately();
    if (efficientMode) {
      launcherDockMenu.show(root, null, screen);
    } else {
      PanelService.showContextMenu(contextMenu, root, screen);
    }
  }

  IconImage {
    id: customOrDistroLogo
    anchors.centerIn: parent
    width: root.launcherIconPx > 0 ? Math.max(8, root.launcherIconPx) : (root.efficientMode ? 16 : root.buttonSize * 0.8)
    height: width
    source: {
      if (useDistroLogo)
        return HostService.osLogo;
      if (customIconPath !== "")
        return customIconPath.startsWith("file://") ? customIconPath : "file://" + customIconPath;
      return "";
    }
    visible: source !== ""
    smooth: true
    asynchronous: true
    layer.enabled: (enableColorization) && (useDistroLogo || customIconPath !== "")
    layer.effect: ShaderEffect {
      property color targetColor: !hovering ? iconColor : Colors.mOnHover
      property real colorizeMode: 2.0

      fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
    }
  }
}
