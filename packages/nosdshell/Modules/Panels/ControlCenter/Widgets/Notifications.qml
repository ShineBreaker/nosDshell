import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: (Settings.data.notifications.doNotDisturb) ? "bell-off" : "bell"
  hot: Settings.data.notifications.doNotDisturb
  tooltipText: I18n.tr("common.notifications")
  onClicked: {
    // DDE §3.5.2: notifications are the control center's home page
    var cc = PanelService.getPanel("controlCenterPanel", screen);
    if (!cc)
      return;
    cc.showNotifications();
    cc.open?.();
  }
  onRightClicked: Settings.data.notifications.doNotDisturb = !(Settings.data.notifications.doNotDisturb)
}
