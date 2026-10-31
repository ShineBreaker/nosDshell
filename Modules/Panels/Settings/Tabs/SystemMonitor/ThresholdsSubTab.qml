import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NHeader {
      Layout.fillWidth: true
      description: I18n.tr("panels.system-monitor.thresholds-section-description")
    }
  }

  NDccGap {
    Layout.fillWidth: true
  }

  // Warning and critical are two SettingsGroups of ordinary rows. A 3-column
  // grid of bare spin boxes had no gutter and the critical column was clipped
  // by the panel edge (DESIGN §3.5.4: one control column, titles wrap).
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NHeader {
      label: I18n.tr("panels.system-monitor.threshold-warning")
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.cpu-usage-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.cpuWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.cpuWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.cpuWarningThreshold = value;
        if (Settings.data.systemMonitor.cpuCriticalThreshold < value)
          Settings.data.systemMonitor.cpuCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.cpu-temperature-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "°C"
      value: Settings.data.systemMonitor.tempWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.tempWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.tempWarningThreshold = value;
        if (Settings.data.systemMonitor.tempCriticalThreshold < value)
          Settings.data.systemMonitor.tempCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      visible: SystemStatService.gpuAvailable
      label: I18n.tr("panels.system-monitor.gpu-section-label")
      from: 0
      to: 120
      stepSize: 5
      suffix: "°C"
      value: Settings.data.systemMonitor.gpuWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.gpuWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.gpuWarningThreshold = value;
        if (Settings.data.systemMonitor.gpuCriticalThreshold < value)
          Settings.data.systemMonitor.gpuCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.memory-usage-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.memWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.memWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.memWarningThreshold = value;
        if (Settings.data.systemMonitor.memCriticalThreshold < value)
          Settings.data.systemMonitor.memCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.swap-usage-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.swapWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.swapWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.swapWarningThreshold = value;
        if (Settings.data.systemMonitor.swapCriticalThreshold < value)
          Settings.data.systemMonitor.swapCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.system-monitor.disk-section-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.diskWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.diskWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.diskWarningThreshold = value;
        if (Settings.data.systemMonitor.diskCriticalThreshold < value)
          Settings.data.systemMonitor.diskCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.system-monitor.disk-available-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.diskAvailWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.diskAvailWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.diskAvailWarningThreshold = value;
        if (Settings.data.systemMonitor.diskAvailCriticalThreshold > value)
          Settings.data.systemMonitor.diskAvailCriticalThreshold = value;
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-battery-label")
      from: 0
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.batteryWarningThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.batteryWarningThreshold")
      onValueChanged: {
        Settings.data.systemMonitor.batteryWarningThreshold = value;
        if (Settings.data.systemMonitor.batteryCriticalThreshold > value)
          Settings.data.systemMonitor.batteryCriticalThreshold = value;
      }
    }
  }

  NDccGap {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NHeader {
      label: I18n.tr("panels.system-monitor.threshold-critical")
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.cpu-usage-label")
      from: Settings.data.systemMonitor.cpuWarningThreshold
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.cpuCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.cpuCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.cpuCriticalThreshold = value
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.cpu-temperature-label")
      from: Settings.data.systemMonitor.tempWarningThreshold
      to: 100
      stepSize: 5
      suffix: "°C"
      value: Settings.data.systemMonitor.tempCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.tempCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.tempCriticalThreshold = value
    }

    NSpinBox {
      Layout.fillWidth: true
      visible: SystemStatService.gpuAvailable
      label: I18n.tr("panels.system-monitor.gpu-section-label")
      from: Settings.data.systemMonitor.gpuWarningThreshold
      to: 120
      stepSize: 5
      suffix: "°C"
      value: Settings.data.systemMonitor.gpuCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.gpuCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.gpuCriticalThreshold = value
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.memory-usage-label")
      from: Settings.data.systemMonitor.memWarningThreshold
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.memCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.memCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.memCriticalThreshold = value
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("bar.system-monitor.swap-usage-label")
      from: Settings.data.systemMonitor.swapWarningThreshold
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.swapCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.swapCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.swapCriticalThreshold = value
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.system-monitor.disk-section-label")
      from: Settings.data.systemMonitor.diskWarningThreshold
      to: 100
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.diskCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.diskCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.diskCriticalThreshold = value
    }

    // Free disk is "low is bad", so critical cannot sit above the warning.
    // The old hard-coded `to: 20` ignored a warning the user had raised.
    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.system-monitor.disk-available-label")
      from: 0
      to: Settings.data.systemMonitor.diskAvailWarningThreshold
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.diskAvailCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.diskAvailCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.diskAvailCriticalThreshold = value
    }

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-battery-label")
      from: 0
      to: Settings.data.systemMonitor.batteryWarningThreshold
      stepSize: 5
      suffix: "%"
      value: Settings.data.systemMonitor.batteryCriticalThreshold
      defaultValue: Settings.getDefaultValue("systemMonitor.batteryCriticalThreshold")
      onValueChanged: Settings.data.systemMonitor.batteryCriticalThreshold = value
    }
  }
}
