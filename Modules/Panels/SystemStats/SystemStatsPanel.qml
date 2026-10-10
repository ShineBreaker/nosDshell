import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  dimsBackground: false

  Component.onCompleted: SystemStatService.registerComponent("panel-systemstats")
  Component.onDestruction: SystemStatService.unregisterComponent("panel-systemstats")

  preferredWidth: Math.round(300 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent
    property real contentPreferredHeight: Math.min(mainColumn.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    // Get diskPath from bar's SystemMonitor widget if available, otherwise use "/"
    readonly property string diskPath: {
      const sysMonWidget = BarService.lookupWidget("SystemMonitor");
      if (sysMonWidget && sysMonWidget.diskPath) {
        return sysMonWidget.diskPath;
      }
      return "/";
    }

    component StatRow: ColumnLayout {
      id: statRow

      property string label: ""
      property string value: ""
      property real gaugeRatio: -1 // < 0 hides the gauge
      property color gaugeColor: Color.accent

      spacing: Style.marginXXS
      Layout.fillWidth: true

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginM
          spacing: Style.marginM

          NText {
            Layout.fillWidth: true
            text: statRow.label
            pointSize: Style.fontSizeM
            elide: Text.ElideRight
          }

          NText {
            text: statRow.value
            pointSize: Style.fontSizeS
            color: Color.onShellSecondary
            font.family: Settings.data.ui.fontFixed
          }
        }
      }

      NLinearGauge {
        visible: statRow.gaugeRatio >= 0
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginM
        Layout.rightMargin: Style.marginM
        Layout.preferredHeight: 2
        orientation: Qt.Horizontal
        ratio: Math.max(0, Math.min(1, statRow.gaugeRatio))
        fillColor: statRow.gaugeColor
      }
    }

    NScrollView {
      id: scrollView
      anchors.fill: parent
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      contentWidth: availableWidth

      ColumnLayout {
        id: mainColumn
        width: scrollView.availableWidth
        spacing: Style.marginXS

        NPanelSection {
          text: I18n.tr("system-monitor.title")
          Layout.fillWidth: true
          Layout.topMargin: Style.marginM
        }

        StatRow {
          label: I18n.tr("system-monitor.cpu-usage")
          value: `${Math.round(SystemStatService.cpuUsage)}% (${SystemStatService.cpuFreq.replace(/[^0-9.]/g, "")} GHz)`
          gaugeRatio: SystemStatService.cpuUsage / 100
        }

        StatRow {
          label: I18n.tr("system-monitor.cpu-temp")
          value: `${Math.round(SystemStatService.cpuTemp)}°C`
          gaugeRatio: Math.min(SystemStatService.cpuTemp / 100, 1)
          visible: SystemStatService.cpuTemp > 0
        }

        StatRow {
          label: I18n.tr("common.memory")
          value: `${Math.round(SystemStatService.memPercent)}% (${(SystemStatService.memGb).toFixed(1)} GiB)`
          gaugeRatio: SystemStatService.memPercent / 100
        }

        StatRow {
          label: I18n.tr("bar.system-monitor.swap-usage-label")
          value: `${(SystemStatService.swapGb).toFixed(1)} / ${(SystemStatService.swapTotalGb).toFixed(1)} GiB`
          gaugeRatio: SystemStatService.swapTotalGb > 0 ? SystemStatService.swapGb / SystemStatService.swapTotalGb : 0
          visible: SystemStatService.swapTotalGb > 0
        }

        StatRow {
          label: I18n.tr("system-monitor.gpu-temp")
          value: `${Math.round(SystemStatService.gpuTemp)}°C`
          visible: SystemStatService.gpuAvailable
        }

        StatRow {
          label: I18n.tr("system-monitor.load-average")
          value: `${SystemStatService.loadAvg1.toFixed(2)} • ${SystemStatService.loadAvg5.toFixed(2)} • ${SystemStatService.loadAvg15.toFixed(2)}`
          visible: SystemStatService.nproc > 0
        }

        StatRow {
          label: I18n.tr("system-monitor.disk")
          value: {
            const usedGb = SystemStatService.diskUsedGb[panelContent.diskPath] || 0;
            const sizeGb = SystemStatService.diskSizeGb[panelContent.diskPath] || 0;
            const percent = SystemStatService.diskPercents[panelContent.diskPath] || 0;
            return `${percent}% (${usedGb.toFixed(1)} / ${sizeGb.toFixed(1)} GB)`;
          }
          gaugeRatio: (SystemStatService.diskPercents[panelContent.diskPath] || 0) / 100
        }

        NPanelSection {
          text: I18n.tr("common.network")
          Layout.fillWidth: true
        }

        StatRow {
          label: I18n.tr("system-monitor.rx")
          value: SystemStatService.formatSpeed(SystemStatService.rxSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
          gaugeRatio: SystemStatService.rxMaxSpeed > 0 ? SystemStatService.rxSpeed / SystemStatService.rxMaxSpeed : 0
        }

        StatRow {
          label: I18n.tr("system-monitor.tx")
          value: SystemStatService.formatSpeed(SystemStatService.txSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
          gaugeRatio: SystemStatService.txMaxSpeed > 0 ? SystemStatService.txSpeed / SystemStatService.txMaxSpeed : 0
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }
  }
}
