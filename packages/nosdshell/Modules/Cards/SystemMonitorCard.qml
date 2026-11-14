import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// Unified system card: monitors CPU, temp, memory, disk
NBox {
  id: root

  Component.onCompleted: SystemStatService.registerComponent("card-sysmonitor")
  Component.onDestruction: SystemStatService.unregisterComponent("card-sysmonitor")

  readonly property string diskPath: Settings.data.controlCenter.diskPath || "/"
  readonly property real contentScale: 0.95 * Style.uiScaleRatio

  // Canonical gauge order; Settings.data.controlCenter.sysmonMetrics selects
  // the subset. An empty or all-invalid selection falls back to the declared
  // default so the card never renders blank.
  readonly property var _allMetrics: ["cpu", "temp", "mem", "disk"]
  readonly property var metrics: {
    const cfg = Settings.data.controlCenter.sysmonMetrics || [];
    const sel = _allMetrics.filter(m => cfg.indexOf(m) !== -1);
    return sel.length > 0 ? sel : (Settings.getDefaultValue("controlCenter.sysmonMetrics") || ["cpu", "temp", "mem"]);
  }

  function _ratio(m) {
    switch (m) {
    case "cpu":
      return SystemStatService.cpuUsage / 100;
    case "temp":
      return SystemStatService.cpuTemp / 100;
    case "mem":
      return SystemStatService.memPercent / 100;
    case "disk":
      return (SystemStatService.diskPercents[root.diskPath] ?? 0) / 100;
    }
    return 0;
  }

  function _icon(m) {
    switch (m) {
    case "cpu":
      return "cpu-usage";
    case "temp":
      return "cpu-temperature";
    case "mem":
      return "memory";
    case "disk":
      return "storage";
    }
    return "";
  }

  function _color(m) {
    switch (m) {
    case "cpu":
      return SystemStatService.cpuColor;
    case "temp":
      return SystemStatService.tempColor;
    case "mem":
      return SystemStatService.memColor;
    case "disk":
      return SystemStatService.getDiskColor(root.diskPath);
    }
    return Colors.accent;
  }

  function _tooltip(m) {
    switch (m) {
    case "cpu":
      return I18n.tr("system-monitor.cpu-usage") + `: ${Math.round(SystemStatService.cpuUsage)}%`;
    case "temp":
      return I18n.tr("system-monitor.cpu-temp") + `: ${Math.round(SystemStatService.cpuTemp)}°C`;
    case "mem":
      return I18n.tr("common.memory") + `: ${Math.round(SystemStatService.memPercent)}%`;
    case "disk":
      return I18n.tr("system-monitor.disk") + `: ${SystemStatService.diskPercents[root.diskPath] || 0}%\n${root.diskPath}`;
    }
    return "";
  }

  function _refreshTooltip(gauge) {
    if (TooltipService.activeTooltip && TooltipService.activeTooltip.targetItem === gauge) {
      TooltipService.updateText(gauge.tooltipText);
    }
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.margins: Style.marginS

    Column {
      anchors.fill: parent

      Repeater {
        model: root.metrics

        delegate: Item {
          id: metricCell

          required property string modelData

          width: parent.width
          height: parent.height / Math.max(1, root.metrics.length)

          NCircleStat {
            id: gauge
            anchors.centerIn: parent
            ratio: root._ratio(metricCell.modelData)
            suffix: metricCell.modelData === "temp" ? "°C" : "%"
            icon: root._icon(metricCell.modelData)
            contentScale: root.contentScale
            fillColor: root._color(metricCell.modelData)
            tooltipText: root._tooltip(metricCell.modelData)
          }

          Connections {
            target: SystemStatService
            function onCpuUsageChanged() {
              if (metricCell.modelData === "cpu")
                root._refreshTooltip(gauge);
            }
            function onCpuTempChanged() {
              if (metricCell.modelData === "temp")
                root._refreshTooltip(gauge);
            }
            function onMemPercentChanged() {
              if (metricCell.modelData === "mem")
                root._refreshTooltip(gauge);
            }
            function onDiskPercentsChanged() {
              if (metricCell.modelData === "disk")
                root._refreshTooltip(gauge);
            }
          }
        }
      }
    }
  }
}
