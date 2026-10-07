import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: (Settings.data.notifications.doNotDisturb ?? false) ? "bell-off" : "bell"
  hot: Settings.data.notifications.doNotDisturb ?? false
  tooltipText: I18n.tr("common.notifications")
  onClicked: {
    // DDE §3.5.2: notifications live on the control center's notification page
    var cc = PanelService.getPanel("controlCenterPanel", screen);
    if (!cc)
      return;
    cc.notificationPage = true;
    cc.open?.();
  }
  onRightClicked: Settings.data.notifications.doNotDisturb = !(Settings.data.notifications.doNotDisturb ?? false)
}
