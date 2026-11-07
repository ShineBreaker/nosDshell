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

  NSettingsGroup {
    Layout.fillWidth: true

    NTextInput {
      label: I18n.tr("panels.launcher.settings-terminal-command-label")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.terminalCommand
      onTextChanged: Settings.data.appLauncher.terminalCommand = text
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-custom-launch-prefix-enabled-label")
      checked: Settings.data.appLauncher.customLaunchPrefixEnabled
      onToggled: checked => Settings.data.appLauncher.customLaunchPrefixEnabled = checked
      defaultValue: Settings.getDefaultValue("appLauncher.customLaunchPrefixEnabled")
    }

    NTextInput {
      label: I18n.tr("panels.launcher.settings-custom-launch-prefix-label")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.customLaunchPrefix
      visible: Settings.data.appLauncher.customLaunchPrefixEnabled
      onTextChanged: Settings.data.appLauncher.customLaunchPrefix = text
    }

    NTextInput {
      label: I18n.tr("panels.launcher.settings-annotation-tool-label")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.screenshotAnnotationTool
      placeholderText: I18n.tr("panels.launcher.settings-annotation-tool-placeholder")
      onTextChanged: Settings.data.appLauncher.screenshotAnnotationTool = text
    }
  }
}
