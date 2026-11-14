import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.performanceMode ? "rocket" : "rocket-off"
  tooltipText: I18n.tr("tooltips.performance-mode-enabled")
  hot: PowerProfileService.performanceMode
  onClicked: PowerProfileService.togglePerformanceMode()
}
