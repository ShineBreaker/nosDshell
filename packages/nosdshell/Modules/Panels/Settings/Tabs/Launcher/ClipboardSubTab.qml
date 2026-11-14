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
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true
    NToggle {
      label: I18n.tr("panels.launcher.settings-clipboard-history-label")
      checked: Settings.data.appLauncher.enableClipboardHistory
      onToggled: checked => Settings.data.appLauncher.enableClipboardHistory = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipboardHistory")
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-preview-label")
      checked: Settings.data.appLauncher.enableClipPreview
      onToggled: checked => Settings.data.appLauncher.enableClipPreview = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipPreview")
      visible: Settings.data.appLauncher.enableClipboardHistory
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-wrap-text-label")
      checked: Settings.data.appLauncher.clipboardWrapText
      onToggled: checked => Settings.data.appLauncher.clipboardWrapText = checked
      defaultValue: Settings.getDefaultValue("appLauncher.clipboardWrapText")
      visible: Settings.data.appLauncher.enableClipboardHistory
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-auto-paste-label")
      checked: Settings.data.appLauncher.autoPasteClipboard
      onToggled: checked => Settings.data.appLauncher.autoPasteClipboard = checked
      defaultValue: Settings.getDefaultValue("appLauncher.autoPasteClipboard")
      visible: Settings.data.appLauncher.enableClipboardHistory && ProgramCheckerService.wtypeAvailable
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-smart-icons-label")
      checked: Settings.data.appLauncher.enableClipboardSmartIcons
      onToggled: checked => Settings.data.appLauncher.enableClipboardSmartIcons = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipboardSmartIcons")
      visible: Settings.data.appLauncher.enableClipboardHistory
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-chips-label")
      checked: Settings.data.appLauncher.enableClipboardChips
      onToggled: checked => Settings.data.appLauncher.enableClipboardChips = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipboardChips")
      visible: Settings.data.appLauncher.enableClipboardHistory
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
    visible: Settings.data.appLauncher.enableClipboardHistory
  }
  // SettingsGroup 2: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true
    visible: Settings.data.appLauncher.enableClipboardHistory
    NTextInput {
      label: I18n.tr("panels.launcher.settings-clipboard-watch-text-label")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.clipboardWatchTextCommand
      onTextChanged: Settings.data.appLauncher.clipboardWatchTextCommand = text
      visible: Settings.data.appLauncher.enableClipboardHistory
    }

    NTextInput {
      label: I18n.tr("panels.launcher.settings-clipboard-watch-image-label")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.clipboardWatchImageCommand
      onTextChanged: Settings.data.appLauncher.clipboardWatchImageCommand = text
      visible: Settings.data.appLauncher.enableClipboardHistory
    }
  }
}
