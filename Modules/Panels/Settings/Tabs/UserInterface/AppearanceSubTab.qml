import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      label: I18n.tr("panels.user-interface.tooltips-label")
      description: I18n.tr("panels.user-interface.tooltips-description")
      checked: Settings.data.ui.tooltipsEnabled
      defaultValue: Settings.getDefaultValue("ui.tooltipsEnabled")
      onToggled: checked => Settings.data.ui.tooltipsEnabled = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.box-border-label")
      description: I18n.tr("panels.user-interface.box-border-description")
      checked: Settings.data.ui.boxBorderEnabled
      defaultValue: Settings.getDefaultValue("ui.boxBorderEnabled")
      onToggled: checked => Settings.data.ui.boxBorderEnabled = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.scrollbar-always-visible-label")
      description: I18n.tr("panels.user-interface.scrollbar-always-visible-description")
      checked: Settings.data.ui.scrollbarAlwaysVisible
      defaultValue: Settings.getDefaultValue("ui.scrollbarAlwaysVisible")
      onToggled: checked => Settings.data.ui.scrollbarAlwaysVisible = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.shadows-label")
      description: I18n.tr("panels.user-interface.shadows-description")
      checked: Settings.data.general.enableShadows
      defaultValue: Settings.getDefaultValue("general.enableShadows")
      onToggled: checked => Settings.data.general.enableShadows = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.blur-behind-label")
      description: I18n.tr("panels.user-interface.blur-behind-description")
      checked: Settings.data.general.enableBlurBehind
      defaultValue: Settings.getDefaultValue("general.enableBlurBehind")
      onToggled: checked => Settings.data.general.enableBlurBehind = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.translucent-widgets-label")
      description: I18n.tr("panels.user-interface.translucent-widgets-description")
      checked: Settings.data.ui.translucentWidgets
      defaultValue: Settings.getDefaultValue("ui.translucentWidgets")
      onToggled: checked => Settings.data.ui.translucentWidgets = checked
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 2: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.scaling-label")
      description: I18n.tr("panels.user-interface.scaling-description")
      from: 0.8
      to: 1.2
      stepSize: 0.05
      showReset: true
      value: Settings.data.general.scaleRatio
      defaultValue: Settings.getDefaultValue("general.scaleRatio")
      onMoved: value => Settings.data.general.scaleRatio = value
      text: Math.floor(Settings.data.general.scaleRatio * 100) + "%"
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 3: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.box-border-radius-label")
      description: I18n.tr("panels.user-interface.box-border-radius-description")
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.radiusRatio
      defaultValue: Settings.getDefaultValue("general.radiusRatio")
      onMoved: value => Settings.data.general.radiusRatio = value
      text: Math.floor(Settings.data.general.radiusRatio * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.control-border-radius-label")
      description: I18n.tr("panels.user-interface.control-border-radius-description")
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.iRadiusRatio
      defaultValue: Settings.getDefaultValue("general.iRadiusRatio")
      onMoved: value => Settings.data.general.iRadiusRatio = value
      text: Math.floor(Settings.data.general.iRadiusRatio * 100) + "%"
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  ColumnLayout {
    spacing: Style.settingsGroupGap
    Layout.fillWidth: true

    NToggle {
      label: I18n.tr("panels.user-interface.animation-disable-label")
      description: I18n.tr("panels.user-interface.animation-disable-description")
      checked: Settings.data.general.animationDisabled
      defaultValue: Settings.getDefaultValue("general.animationDisabled")
      onToggled: checked => Settings.data.general.animationDisabled = checked
    }

    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true
      visible: !Settings.data.general.animationDisabled

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.user-interface.animation-speed-label")
        description: I18n.tr("panels.user-interface.animation-speed-description")
        from: 0
        to: 2.0
        stepSize: 0.01
        showReset: true
        value: Settings.data.general.animationSpeed
        defaultValue: Settings.getDefaultValue("general.animationSpeed")
        onMoved: value => Settings.data.general.animationSpeed = Math.max(value, 0.05)
        text: Math.round(Settings.data.general.animationSpeed * 100) + "%"
      }
    }
  }
}
