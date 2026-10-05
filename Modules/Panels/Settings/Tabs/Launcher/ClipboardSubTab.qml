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
  NHeader {
    label: I18n.tr("panels.launcher.clipboard-header")
  }

  // SettingsGroup 1: the rows sit flush, the 1 px seam
  // between them comes from the dcc row (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    NToggle {
      label: I18n.tr("panels.launcher.settings-clipboard-history-label")
      description: I18n.tr("panels.launcher.settings-clipboard-history-description")
      checked: Settings.data.appLauncher.enableClipboardHistory
      onToggled: checked => Settings.data.appLauncher.enableClipboardHistory = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipboardHistory")
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-preview-label")
      description: I18n.tr("panels.launcher.settings-clip-preview-description")
      checked: Settings.data.appLauncher.enableClipPreview
      onToggled: checked => Settings.data.appLauncher.enableClipPreview = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipPreview")
      enabled: Settings.data.appLauncher.enableClipboardHistory
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-wrap-text-label")
      description: I18n.tr("panels.launcher.settings-clip-wrap-text-description")
      checked: Settings.data.appLauncher.clipboardWrapText
      onToggled: checked => Settings.data.appLauncher.clipboardWrapText = checked
      defaultValue: Settings.getDefaultValue("appLauncher.clipboardWrapText")
      enabled: Settings.data.appLauncher.enableClipboardHistory
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-auto-paste-label")
      description: I18n.tr("panels.launcher.settings-auto-paste-description")
      checked: Settings.data.appLauncher.autoPasteClipboard
      onToggled: checked => Settings.data.appLauncher.autoPasteClipboard = checked
      defaultValue: Settings.getDefaultValue("appLauncher.autoPasteClipboard")
      enabled: Settings.data.appLauncher.enableClipboardHistory && ProgramCheckerService.wtypeAvailable
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-smart-icons-label")
      description: I18n.tr("panels.launcher.settings-clip-smart-icons-description")
      checked: Settings.data.appLauncher.enableClipboardSmartIcons
      onToggled: checked => Settings.data.appLauncher.enableClipboardSmartIcons = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipboardSmartIcons")
      enabled: Settings.data.appLauncher.enableClipboardHistory
    }

    NToggle {
      label: I18n.tr("panels.launcher.settings-clip-chips-label")
      description: I18n.tr("panels.launcher.settings-clip-chips-description")
      checked: Settings.data.appLauncher.enableClipboardChips
      onToggled: checked => Settings.data.appLauncher.enableClipboardChips = checked
      defaultValue: Settings.getDefaultValue("appLauncher.enableClipboardChips")
      enabled: Settings.data.appLauncher.enableClipboardHistory
    }
  }

  // SettingsGroup gap (DESIGN §3.5.4)
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.settingsGroupSpacing ?? 15
  }
  // SettingsGroup 2: the rows sit flush, the 1 px seam
  // between them comes from the dcc row (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    NTextInput {
      label: I18n.tr("panels.launcher.settings-clipboard-watch-text-label")
      description: I18n.tr("panels.launcher.settings-clipboard-watch-text-description")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.clipboardWatchTextCommand
      onTextChanged: Settings.data.appLauncher.clipboardWatchTextCommand = text
      enabled: Settings.data.appLauncher.enableClipboardHistory
      visible: Settings.data.appLauncher.enableClipboardHistory
    }

    NTextInput {
      label: I18n.tr("panels.launcher.settings-clipboard-watch-image-label")
      description: I18n.tr("panels.launcher.settings-clipboard-watch-image-description")
      Layout.fillWidth: true
      text: Settings.data.appLauncher.clipboardWatchImageCommand
      onTextChanged: Settings.data.appLauncher.clipboardWatchImageCommand = text
      enabled: Settings.data.appLauncher.enableClipboardHistory
      visible: Settings.data.appLauncher.enableClipboardHistory
    }
  }
}
