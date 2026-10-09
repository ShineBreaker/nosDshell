import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
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
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.panels-attached-to-bar-label")
      description: I18n.tr("panels.user-interface.panels-attached-to-bar-description")
      checked: Settings.data.ui.panelsAttachedToBar
      defaultValue: Settings.getDefaultValue("ui.panelsAttachedToBar")
      onToggled: checked => Settings.data.ui.panelsAttachedToBar = checked
    }

    NToggle {
      visible: (Quickshell.screens.length > 1)
      label: I18n.tr("panels.user-interface.allow-panels-without-bar-label")
      description: I18n.tr("panels.user-interface.allow-panels-without-bar-description")
      checked: Settings.data.general.allowPanelsOnScreenWithoutBar
      defaultValue: Settings.getDefaultValue("general.allowPanelsOnScreenWithoutBar")
      onToggled: checked => Settings.data.general.allowPanelsOnScreenWithoutBar = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.panel-background-opacity-label")
      description: I18n.tr("panels.user-interface.panel-background-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.panelBackgroundOpacity
      defaultValue: Settings.getDefaultValue("ui.panelBackgroundOpacity")
      onMoved: value => Settings.data.ui.panelBackgroundOpacity = value
      text: Math.floor(Settings.data.ui.panelBackgroundOpacity * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.dimmer-opacity-label")
      description: I18n.tr("panels.user-interface.dimmer-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.dimmerOpacity
      defaultValue: Settings.getDefaultValue("general.dimmerOpacity")
      onMoved: value => Settings.data.general.dimmerOpacity = value
      text: Math.floor(Settings.data.general.dimmerOpacity * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.popup-opacity-label")
      description: I18n.tr("panels.user-interface.popup-opacity-description")
      from: 0.3
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.popupOpacity
      defaultValue: Settings.getDefaultValue("ui.popupOpacity")
      onMoved: value => Settings.data.ui.popupOpacity = value
      text: Math.floor(Settings.data.ui.popupOpacity * 100) + "%"
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }

  // Transient tiles + panel borders (DESIGN §1.2)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.transient-surface-label")
      description: I18n.tr("panels.user-interface.transient-surface-description")
      model: [
        {
          "key": "auto",
          "name": I18n.tr("panels.user-interface.transient-surface-auto")
        },
        {
          "key": "light",
          "name": I18n.tr("panels.user-interface.transient-surface-light")
        },
        {
          "key": "dark",
          "name": I18n.tr("panels.user-interface.transient-surface-dark")
        }
      ]
      currentKey: Settings.data.ui.transientSurface
      defaultValue: Settings.getDefaultValue("ui.transientSurface")
      onSelected: key => Settings.data.ui.transientSurface = key
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.transient-opacity-label")
      description: I18n.tr("panels.user-interface.transient-opacity-description")
      from: 0.3
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.transientOpacity
      defaultValue: Settings.getDefaultValue("ui.transientOpacity")
      onMoved: value => Settings.data.ui.transientOpacity = value
      text: Math.floor(Settings.data.ui.transientOpacity * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.border-emphasis-label")
      description: I18n.tr("panels.user-interface.border-emphasis-description")
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.borderEmphasis
      defaultValue: Settings.getDefaultValue("ui.borderEmphasis")
      onMoved: value => Settings.data.ui.borderEmphasis = value
      text: Math.floor(Settings.data.ui.borderEmphasis * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.shadow-strength-label")
      description: I18n.tr("panels.user-interface.shadow-strength-description")
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.shadowStrength
      defaultValue: Settings.getDefaultValue("general.shadowStrength")
      onMoved: value => Settings.data.general.shadowStrength = value
      text: Math.floor(Settings.data.general.shadowStrength * 100) + "%"
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }

  // Screen corners (the rounded-corner masks at the screen edges)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.screen-corners-show-corners-label")
      description: I18n.tr("panels.general.screen-corners-show-corners-description")
      checked: Settings.data.general.showScreenCorners
      defaultValue: Settings.getDefaultValue("general.showScreenCorners")
      onToggled: checked => Settings.data.general.showScreenCorners = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.screen-corners-solid-black-label")
      description: I18n.tr("panels.general.screen-corners-solid-black-description")
      checked: Settings.data.general.forceBlackScreenCorners
      defaultValue: Settings.getDefaultValue("general.forceBlackScreenCorners")
      onToggled: checked => Settings.data.general.forceBlackScreenCorners = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.screen-corners-radius-label")
      description: I18n.tr("panels.general.screen-corners-radius-description")
      enabled: Settings.data.general.showScreenCorners
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.screenRadiusRatio
      defaultValue: Settings.getDefaultValue("general.screenRadiusRatio")
      onMoved: value => Settings.data.general.screenRadiusRatio = value
      text: Math.floor(Settings.data.general.screenRadiusRatio * 100) + "%"
    }
  }
}
