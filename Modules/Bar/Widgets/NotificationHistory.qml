import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Bar.Extras
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
  readonly property bool showUnreadBadge: widgetSettings.showUnreadBadge !== undefined ? widgetSettings.showUnreadBadge : widgetMetadata.showUnreadBadge
  readonly property bool hideWhenZero: widgetSettings.hideWhenZero !== undefined ? widgetSettings.hideWhenZero : widgetMetadata.hideWhenZero
  readonly property bool hideWhenZeroUnread: widgetSettings.hideWhenZeroUnread !== undefined ? widgetSettings.hideWhenZeroUnread : widgetMetadata.hideWhenZeroUnread
  readonly property string unreadBadgeColor: widgetSettings.unreadBadgeColor !== undefined ? widgetSettings.unreadBadgeColor : widgetMetadata.unreadBadgeColor
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  readonly property color badgeColor: Color.resolveColorKey(unreadBadgeColor)

  function computeUnreadCount() {
    var since = NotificationService.lastSeenTs;
    var count = 0;
    var model = NotificationService.historyModel;
    for (var i = 0; i < model.count; i++) {
      var item = model.get(i);
      var ts = item.timestamp instanceof Date ? item.timestamp.getTime() : item.timestamp;
      if (ts > since)
        count++;
    }
    return count;
  }

  readonly property int count: computeUnreadCount()

  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // "fashion" = DDE fashion dock presentation (square item, icon at 0.8)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool onShellSurface: efficientMode || fashionMode

  baseSize: fashionMode ? Style.dockItemThickness : (efficientMode ? Style.dockPluginSize : Style.getCapsuleHeightForScreen(screen?.name))
  // Fashion plugins are a 36 px rounded tile with a 16 px symbolic icon —
  // the DDE plugin-button look (onboard tile), not a bare colored icon.
  bgSize: fashionMode ? Math.round(baseSize * 0.66) : -1
  applyUiScale: false
  customRadius: onShellSurface ? Style.radiusPopup : Style.radiusL
  icon: (Settings.data.notifications.doNotDisturb ?? false) ? "bell-off" : "bell"
  iconSource: onShellSurface ? ThemeIcons.symbolicOnlyAny((Settings.data.notifications.doNotDisturb ?? false) ? ["notification-disabled", "notifications-disabled"] : ["notification", "preferences-system-notifications"]) : ""
  recolorIcon: onShellSurface
  iconRatio: fashionMode ? 0.45 : (efficientMode ? 16.0 / baseSize : 0.48)
  tooltipText: {
    if (PanelService.getPanel("controlCenterPanel", screen)?.isPanelOpen) {
      return "";
    } else {
      return I18n.tr("tooltips.open-notification-history-enable-dnd");
    }
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name, root.section === "dock")
  colorBg: fashionMode ? Color.overlay("subtle") : (efficientMode ? "transparent" : Style.capsuleColor)
  colorFg: onShellSurface ? Color.onShell : Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: fashionMode ? 0 : Style.capsuleBorderWidth
  visible: !((hideWhenZero && NotificationService.historyModel.count === 0) || (hideWhenZeroUnread && count === 0))
  opacity: !((hideWhenZero && NotificationService.historyModel.count === 0) || (hideWhenZeroUnread && count === 0)) ? 1.0 : 0.0

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": (Settings.data.notifications.doNotDisturb ?? false) ? I18n.tr("actions.disable-dnd") : I18n.tr("actions.enable-dnd"),
        "action": "toggle-dnd",
        "icon": (Settings.data.notifications.doNotDisturb ?? false) ? "bell" : "bell-off"
      },
      {
        "label": I18n.tr("actions.clear-history"),
        "action": "clear-history",
        "icon": "trash"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "toggle-dnd") {
                     Settings.data.notifications.doNotDisturb = !(Settings.data.notifications.doNotDisturb ?? false);
                   } else if (action === "clear-history") {
                     NotificationService.clearHistory();
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onClicked: {
    // DDE: the bell page inside the control center (DESIGN §3.5.2)
    var controlCenterPanel = PanelService.getPanel("controlCenterPanel", screen);
    if (!controlCenterPanel)
      return;
    controlCenterPanel.notificationPage = true;
    if (!controlCenterPanel.isPanelOpen)
      controlCenterPanel.open();
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }

  Loader {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenterOffset: parent.baseSize / 4
    anchors.verticalCenterOffset: -parent.baseSize / 4
    z: 2
    active: showUnreadBadge
    sourceComponent: Rectangle {
      id: badge
      height: 7
      width: height
      radius: Style.radiusXS
      color: root.hovering ? Color.mOnHover : (root.badgeColor || Color.mError)
      border.color: Color.mSurface
      border.width: Style.borderS
      visible: count > 0
    }
  }
}
