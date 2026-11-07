import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true
  visible: Settings.data.notifications.enabled

  signal openUnifiedPicker
  signal openLowPicker
  signal openNormalPicker
  signal openCriticalPicker

  // QtMultimedia unavailable message
  NBox {
    Layout.fillWidth: true
    visible: !SoundService.multimediaAvailable
    implicitHeight: unavailableContent.implicitHeight + Style.margin2L

    RowLayout {
      id: unavailableContent
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NIcon {
        icon: "warning"
        color: Colors.onShellTertiary
        pointSize: Style.fontSizeXL
        Layout.alignment: Qt.AlignVCenter
      }

      NLabel {
        Layout.fillWidth: true
        label: I18n.tr("panels.notifications.sounds-unavailable-label")
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  NSettingsGroup {
    Layout.fillWidth: true

    NToggle {
      enabled: SoundService.multimediaAvailable
      label: I18n.tr("panels.notifications.sounds-enabled-label")
      checked: Settings.data.notifications?.sounds?.enabled
      onToggled: checked => Settings.data.notifications.sounds.enabled = checked
      defaultValue: Settings.getDefaultValue("notifications.sounds.enabled")
    }

    // Sound Volume
    NValueSlider {
      visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled)
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.sounds-volume-label")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.notifications?.sounds?.volume
      onMoved: value => Settings.data.notifications.sounds.volume = value
      text: Math.round((Settings.data.notifications?.sounds?.volume) * 100) + "%"
      defaultValue: Settings.getDefaultValue("notifications.sounds.volume")
    }

    // Separate Sounds Toggle
    NToggle {
      visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled)
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.sounds-separate-label")
      checked: Settings.data.notifications?.sounds?.separateSounds
      onToggled: checked => Settings.data.notifications.sounds.separateSounds = checked
      defaultValue: Settings.getDefaultValue("notifications.sounds.separateSounds")
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4).
  // Hidden with the group, otherwise a disabled sounds block leaves a stack of empty gaps.
  NDccGap {
    Layout.fillWidth: true
    visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled) && !(Settings.data.notifications?.sounds?.separateSounds)
  }
  // Unified Sound File (shown when separateSounds is false)
  NSettingsGroup {
    visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled) && !(Settings.data.notifications?.sounds?.separateSounds)
    Layout.fillWidth: true

    NTextInputButton {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.sounds-files-unified-label")
      placeholderText: I18n.tr("panels.notifications.sounds-files-placeholder")
      text: Settings.data.notifications?.sounds?.normalSoundFile
      buttonIcon: "folder-open"
      buttonTooltip: I18n.tr("panels.notifications.sounds-files-select-file")
      onInputTextChanged: text => {
        // When separate sounds are enabled, this row is hidden but still
        // bound to normalSoundFile; user edits to normal still update that
        // key and would re-trigger this handler and wipe low/critical.
        if (Settings.data.notifications.sounds.separateSounds) {
          return;
        }
        const soundPath = text;
        Settings.data.notifications.sounds.normalSoundFile = soundPath;
        Settings.data.notifications.sounds.lowSoundFile = soundPath;
        Settings.data.notifications.sounds.criticalSoundFile = soundPath;
      }
      onButtonClicked: root.openUnifiedPicker()
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
    visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled) && (Settings.data.notifications?.sounds?.separateSounds)
  }
  // Separate Sound Files (shown when separateSounds is true)
  NSettingsGroup {
    visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled) && (Settings.data.notifications?.sounds?.separateSounds)
    Layout.fillWidth: true

    NTextInputButton {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.sounds-files-low-label")
      placeholderText: I18n.tr("panels.notifications.sounds-files-placeholder")
      text: Settings.data.notifications?.sounds?.lowSoundFile
      buttonIcon: "folder-open"
      buttonTooltip: I18n.tr("panels.notifications.sounds-files-select-file")
      onInputTextChanged: text => Settings.data.notifications.sounds.lowSoundFile = text
      onButtonClicked: root.openLowPicker()
    }

    NTextInputButton {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.sounds-files-normal-label")
      placeholderText: I18n.tr("panels.notifications.sounds-files-placeholder")
      text: Settings.data.notifications?.sounds?.normalSoundFile
      buttonIcon: "folder-open"
      buttonTooltip: I18n.tr("panels.notifications.sounds-files-select-file")
      onInputTextChanged: text => Settings.data.notifications.sounds.normalSoundFile = text
      onButtonClicked: root.openNormalPicker()
    }

    NTextInputButton {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.sounds-files-critical-label")
      placeholderText: I18n.tr("panels.notifications.sounds-files-placeholder")
      text: Settings.data.notifications?.sounds?.criticalSoundFile
      buttonIcon: "folder-open"
      buttonTooltip: I18n.tr("panels.notifications.sounds-files-select-file")
      onInputTextChanged: text => Settings.data.notifications.sounds.criticalSoundFile = text
      onButtonClicked: root.openCriticalPicker()
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
    visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled)
  }
  // Excluded Apps List
  NSettingsGroup {
    visible: SoundService.multimediaAvailable && (Settings.data.notifications?.sounds?.enabled)
    Layout.fillWidth: true

    NTextInput {
      label: I18n.tr("panels.notifications.sounds-excluded-apps-label")
      Layout.fillWidth: true
      placeholderText: I18n.tr("panels.notifications.sounds-excluded-apps-placeholder")
      text: Settings.data.notifications?.sounds?.excludedApps
      onTextChanged: Settings.data.notifications.sounds.excludedApps = text
    }
  }
}
