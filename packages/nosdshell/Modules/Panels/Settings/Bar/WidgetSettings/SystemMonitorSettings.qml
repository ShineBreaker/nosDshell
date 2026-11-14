import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"

  // Local, editable state for checkboxes
  property bool valueCompactMode: settingsHelper.value("compactMode")
  property string valueIconColor: settingsHelper.value("iconColor")
  property string valueTextColor: settingsHelper.value("textColor")
  property bool valueUseMonospaceFont: settingsHelper.value("useMonospaceFont")
  property bool valueUsePadding: settingsHelper.value("usePadding")
  property bool valueShowCpuUsage: settingsHelper.value("showCpuUsage")
  property bool valueShowCpuCores: settingsHelper.value("showCpuCores")
  property bool valueShowCpuFreq: settingsHelper.value("showCpuFreq")
  property bool valueShowCpuTemp: settingsHelper.value("showCpuTemp")
  property bool valueShowGpuTemp: settingsHelper.value("showGpuTemp")
  property bool valueShowLoadAverage: settingsHelper.value("showLoadAverage")
  property bool valueShowMemoryUsage: settingsHelper.value("showMemoryUsage")
  property bool valueShowMemoryAsPercent: settingsHelper.value("showMemoryAsPercent")
  property bool valueShowSwapUsage: settingsHelper.value("showSwapUsage")
  property bool valueShowNetworkStats: settingsHelper.value("showNetworkStats")
  property bool valueShowDiskUsage: settingsHelper.value("showDiskUsage")
  property bool valueShowDiskUsageAsPercent: settingsHelper.value("showDiskUsageAsPercent")
  property bool valueShowDiskAvailable: settingsHelper.value("showDiskAvailable")
  property string valueDiskPath: settingsHelper.value("diskPath")

  function saveSettings() {
    var settings = settingsHelper.save();

    settingsChanged(settings);
    return settings;
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.compact-mode-label")
    checked: valueCompactMode
    onToggled: checked => {
      settingsHelper.set("compactMode", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.compactMode
  }

  NColorChoice {
    label: I18n.tr("common.select-icon-color")
    currentKey: valueIconColor
    onSelected: key => {
      settingsHelper.set("iconColor", key);
      saveSettings();
    }
    defaultValue: widgetMetadata.iconColor
  }

  NColorChoice {
    label: I18n.tr("common.select-text-color")
    currentKey: valueTextColor
    onSelected: key => {
      settingsHelper.set("textColor", key);
      saveSettings();
    }
    visible: !valueCompactMode
    defaultValue: widgetMetadata.textColor
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.use-monospace-font-label")
    checked: valueUseMonospaceFont
    onToggled: checked => {
      settingsHelper.set("useMonospaceFont", checked);
      saveSettings();
    }
    visible: !valueCompactMode
    defaultValue: widgetMetadata.useMonospaceFont
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.use-padding-label")
    checked: valueUsePadding && !isVerticalBar && valueUseMonospaceFont
    onToggled: checked => {
      settingsHelper.set("usePadding", checked);
      saveSettings();
    }
    visible: !valueCompactMode
    enabled: !isVerticalBar && valueUseMonospaceFont
    defaultValue: widgetMetadata.usePadding
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    id: showCpuUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.cpu-usage-label")
    checked: valueShowCpuUsage
    onToggled: checked => {
      settingsHelper.set("showCpuUsage", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showCpuUsage
  }

  NToggle {
    id: showCpuCores
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.cpu-cores-label")
    checked: valueShowCpuCores
    onToggled: checked => {
      settingsHelper.set("showCpuCores", checked);
      saveSettings();
    }
    visible: valueCompactMode
  }

  NToggle {
    id: showCpuFreq
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.cpu-frequency-label")
    checked: valueShowCpuFreq
    onToggled: checked => {
      settingsHelper.set("showCpuFreq", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showCpuFreq
  }

  NToggle {
    id: showCpuTemp
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.cpu-temperature-label")
    checked: valueShowCpuTemp
    onToggled: checked => {
      settingsHelper.set("showCpuTemp", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showCpuTemp
  }

  NToggle {
    id: showLoadAverage
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.load-average-label")
    checked: valueShowLoadAverage
    onToggled: checked => {
      settingsHelper.set("showLoadAverage", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showLoadAverage
  }

  NToggle {
    id: showGpuTemp
    Layout.fillWidth: true
    label: I18n.tr("panels.system-monitor.gpu-section-label")
    checked: valueShowGpuTemp
    onToggled: checked => {
      settingsHelper.set("showGpuTemp", checked);
      saveSettings();
    }
    visible: SystemStatService.gpuAvailable
    defaultValue: widgetMetadata.showGpuTemp
  }

  NToggle {
    id: showMemoryUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.memory-usage-label")
    checked: valueShowMemoryUsage
    onToggled: checked => {
      settingsHelper.set("showMemoryUsage", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showMemoryUsage
  }

  NToggle {
    id: showMemoryAsPercent
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.memory-percentage-label")
    checked: valueShowMemoryAsPercent
    onToggled: checked => {
      settingsHelper.set("showMemoryAsPercent", checked);
      saveSettings();
    }
    visible: valueShowMemoryUsage
    defaultValue: widgetMetadata.showMemoryAsPercent
  }

  NToggle {
    id: showSwapUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.swap-usage-label")
    checked: valueShowSwapUsage
    onToggled: checked => {
      settingsHelper.set("showSwapUsage", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showSwapUsage
  }

  NToggle {
    id: showNetworkStats
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.network-traffic-label")
    checked: valueShowNetworkStats
    onToggled: checked => {
      settingsHelper.set("showNetworkStats", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showNetworkStats
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    id: showDiskUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.storage-usage-label")
    checked: valueShowDiskUsage
    onToggled: checked => {
      settingsHelper.set("showDiskUsage", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showDiskUsage
  }

  NToggle {
    id: showDiskUsageAsPercent
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.storage-as-percentage-label")
    checked: valueShowDiskUsageAsPercent
    onToggled: checked => {
      settingsHelper.set("showDiskUsageAsPercent", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showDiskUsageAsPercent
  }

  NToggle {
    id: showDiskAvailable
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.storage-available-label")
    checked: valueShowDiskAvailable
    onToggled: checked => {
      settingsHelper.set("showDiskAvailable", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showDiskAvailable
  }

  NComboBox {
    id: diskPathComboBox
    Layout.fillWidth: true
    label: I18n.tr("bar.system-monitor.disk-path-label")
    model: {
      const paths = Object.keys(SystemStatService.diskPercents).sort();
      return paths.map(path => ({
        key: path,
        name: path
      }));
    }
      currentKey: valueDiskPath
      onSelected: key => {
      settingsHelper.set("diskPath", key);
      saveSettings();
    }
      defaultValue: widgetMetadata.diskPath
    }
    }
