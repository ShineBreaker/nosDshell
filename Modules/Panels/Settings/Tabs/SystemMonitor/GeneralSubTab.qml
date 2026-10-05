import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  property var screen

  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  NHeader {
    label: I18n.tr("control-center.module.system-monitor")
  }

  // SettingsGroup 1: the rows sit flush, the 1 px seam
  // between them comes from the dcc row (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    NToggle {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginM
      label: I18n.tr("panels.system-monitor.enable-dgpu-monitoring-label")
      description: I18n.tr("panels.system-monitor.enable-dgpu-monitoring-description")
      checked: Settings.data.systemMonitor.enableDgpuMonitoring
      defaultValue: Settings.getDefaultValue("systemMonitor.enableDgpuMonitoring")
      onToggled: checked => Settings.data.systemMonitor.enableDgpuMonitoring = checked
    }

    // Colors Section
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NToggle {
        label: I18n.tr("panels.system-monitor.use-custom-highlight-colors-label")
        description: I18n.tr("panels.system-monitor.use-custom-highlight-colors-description")
        checked: Settings.data.systemMonitor.useCustomColors
        defaultValue: Settings.getDefaultValue("systemMonitor.useCustomColors")
        onToggled: checked => {
                     // If enabling custom colors and no custom color is saved, persist current theme colors
                     if (checked) {
                       if (!Settings.data.systemMonitor.warningColor || Settings.data.systemMonitor.warningColor === "") {
                         Settings.data.systemMonitor.warningColor = Color.mTertiary.toString();
                       }
                       if (!Settings.data.systemMonitor.criticalColor || Settings.data.systemMonitor.criticalColor === "") {
                         Settings.data.systemMonitor.criticalColor = Color.mError.toString();
                       }
                     }
                     Settings.data.systemMonitor.useCustomColors = checked;
                   }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginXL
      visible: Settings.data.systemMonitor.useCustomColors

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: I18n.tr("panels.system-monitor.warning-color-label")
          pointSize: Style.fontSizeM
        }

        NColorPicker {
          screen: root.screen
          Layout.preferredWidth: Style.sliderWidth
          Layout.preferredHeight: Style.baseWidgetSize
          enabled: Settings.data.systemMonitor.useCustomColors
          selectedColor: Settings.data.systemMonitor.warningColor || Color.mTertiary
          onColorSelected: color => Settings.data.systemMonitor.warningColor = color
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: I18n.tr("panels.system-monitor.critical-color-label")
          pointSize: Style.fontSizeM
        }

        NColorPicker {
          screen: root.screen
          Layout.preferredWidth: Style.sliderWidth
          Layout.preferredHeight: Style.baseWidgetSize
          enabled: Settings.data.systemMonitor.useCustomColors
          selectedColor: Settings.data.systemMonitor.criticalColor || Color.mError
          onColorSelected: color => Settings.data.systemMonitor.criticalColor = color
        }
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 2: the rows sit flush, the 1 px seam
  // between them comes from the dcc row (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    NTextInput {
      label: I18n.tr("panels.system-monitor.external-monitor-label")
      description: I18n.tr("panels.system-monitor.external-monitor-description")
      placeholderText: I18n.tr("panels.system-monitor.external-monitor-placeholder")
      text: Settings.data.systemMonitor.externalMonitor
      defaultValue: Settings.getDefaultValue("systemMonitor.externalMonitor")
      onTextChanged: Settings.data.systemMonitor.externalMonitor = text
    }
  }
}
