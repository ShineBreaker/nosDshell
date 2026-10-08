import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// Advanced bar keys — the "状态栏" sub-tab of the stacked 高级 module page
// (DESIGN §3.5.3): appearance, behaviour and auto-hide groups.
ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  readonly property string effectiveWheelAction: Settings.data.bar.mouseWheelAction || "none"
  readonly property string effectiveMiddleClickAction: Settings.data.bar.middleClickAction || "none"

  // SettingsGroup: bar appearance (efficient-mode bar still reads these)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NHeader {
      label: I18n.tr("settings.advanced.bar-appearance")
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-density-label")
      description: I18n.tr("panels.bar.appearance-density-description")
      model: [
        {
          "key": "mini",
          "name": I18n.tr("options.bar.density-mini")
        },
        {
          "key": "compact",
          "name": I18n.tr("options.bar.density-compact")
        },
        {
          "key": "default",
          "name": I18n.tr("options.bar.density-default")
        },
        {
          "key": "comfortable",
          "name": I18n.tr("options.bar.density-comfortable")
        },
        {
          "key": "spacious",
          "name": I18n.tr("options.bar.density-spacious")
        }
      ]
      currentKey: Settings.data.bar.density
      defaultValue: Settings.getDefaultValue("bar.density")
      onSelected: key => Settings.data.bar.density = key
    }

    NToggle {
      label: I18n.tr("panels.bar.appearance-use-separate-opacity-label")
      description: I18n.tr("panels.bar.appearance-use-separate-opacity-description")
      checked: Settings.data.bar.useSeparateOpacity
      defaultValue: Settings.getDefaultValue("bar.useSeparateOpacity")
      onToggled: checked => Settings.data.bar.useSeparateOpacity = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Settings.data.bar.useSeparateOpacity
      label: I18n.tr("panels.bar.appearance-background-opacity-label")
      description: I18n.tr("panels.bar.appearance-background-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.bar.backgroundOpacity
      defaultValue: Settings.getDefaultValue("bar.backgroundOpacity")
      onMoved: value => Settings.data.bar.backgroundOpacity = value
      text: Math.floor(Settings.data.bar.backgroundOpacity * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-font-scale-label")
      description: I18n.tr("panels.bar.appearance-font-scale-description")
      from: 0.5
      to: 2.0
      stepSize: 0.01
      showReset: true
      value: Settings.data.bar.fontScale
      defaultValue: Settings.getDefaultValue("bar.fontScale")
      onMoved: value => Settings.data.bar.fontScale = value
      text: Math.floor(Settings.data.bar.fontScale * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-widget-spacing-label")
      description: I18n.tr("panels.bar.appearance-widget-spacing-description")
      from: 0
      to: 30
      stepSize: 1
      showReset: true
      value: Settings.data.bar.widgetSpacing
      defaultValue: Settings.getDefaultValue("bar.widgetSpacing")
      onMoved: value => Settings.data.bar.widgetSpacing = value
      text: Settings.data.bar.widgetSpacing + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-content-padding-label")
      description: I18n.tr("panels.bar.appearance-content-padding-description")
      from: 0
      to: 30
      stepSize: 1
      showReset: true
      value: Settings.data.bar.contentPadding
      defaultValue: Settings.getDefaultValue("bar.contentPadding")
      onMoved: value => Settings.data.bar.contentPadding = value
      text: Settings.data.bar.contentPadding + "px"
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-show-outline-label")
      description: I18n.tr("panels.bar.appearance-show-outline-description")
      checked: Settings.data.bar.showOutline
      defaultValue: Settings.getDefaultValue("bar.showOutline")
      onToggled: checked => Settings.data.bar.showOutline = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-show-capsule-label")
      description: I18n.tr("panels.bar.appearance-show-capsule-description")
      checked: Settings.data.bar.showCapsule
      defaultValue: Settings.getDefaultValue("bar.showCapsule")
      onToggled: checked => Settings.data.bar.showCapsule = checked
    }

    NColorChoice {
      Layout.fillWidth: true
      visible: Settings.data.bar.showCapsule
      label: I18n.tr("panels.bar.appearance-capsule-color-label")
      description: I18n.tr("panels.bar.appearance-capsule-color-description")
      noneColor: Color.overlay("field")
      noneOnColor: Color.onShellTertiary
      currentKey: Settings.data.bar.capsuleColorKey
      onSelected: key => Settings.data.bar.capsuleColorKey = key
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Settings.data.bar.showCapsule
      label: I18n.tr("panels.bar.appearance-capsule-opacity-label")
      description: I18n.tr("panels.bar.appearance-capsule-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.bar.capsuleOpacity
      defaultValue: Settings.getDefaultValue("bar.capsuleOpacity")
      onMoved: value => Settings.data.bar.capsuleOpacity = value
      text: Math.floor(Settings.data.bar.capsuleOpacity * 100) + "%"
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-enable-exclusion-zone-inset-label")
      description: I18n.tr("panels.bar.appearance-enable-exclusion-zone-inset-description")
      checked: Settings.data.bar.enableExclusionZoneInset
      defaultValue: Settings.getDefaultValue("bar.enableExclusionZoneInset")
      onToggled: checked => Settings.data.bar.enableExclusionZoneInset = checked
    }

    NToggle {
      Layout.fillWidth: true
      visible: CompositorService.isNiri
      label: I18n.tr("panels.bar.appearance-hide-on-overview-label")
      description: I18n.tr("panels.bar.appearance-hide-on-overview-description")
      checked: Settings.data.bar.hideOnOverview
      defaultValue: Settings.getDefaultValue("bar.hideOnOverview")
      onToggled: checked => Settings.data.bar.hideOnOverview = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-outer-corners-label")
      description: I18n.tr("panels.bar.appearance-outer-corners-description")
      checked: Settings.data.bar.outerCorners
      defaultValue: Settings.getDefaultValue("bar.outerCorners")
      onToggled: checked => Settings.data.bar.outerCorners = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-frame-thickness")
      description: I18n.tr("panels.bar.appearance-frame-settings-description")
      from: 4
      to: 24
      stepSize: 1
      showReset: true
      value: Settings.data.bar.frameThickness
      defaultValue: Settings.getDefaultValue("bar.frameThickness")
      onMoved: value => Settings.data.bar.frameThickness = value
      text: Settings.data.bar.frameThickness + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-frame-radius")
      from: 4
      to: 24
      stepSize: 1
      showReset: true
      value: Settings.data.bar.frameRadius
      defaultValue: Settings.getDefaultValue("bar.frameRadius")
      onMoved: value => Settings.data.bar.frameRadius = value
      text: Settings.data.bar.frameRadius + "px"
    }

    NSpinBox {
      label: I18n.tr("panels.bar.appearance-margins-vertical")
      description: I18n.tr("panels.bar.appearance-margins-description")
      from: 0
      to: 500
      suffix: "px"
      value: Settings.data.bar.marginVertical
      defaultValue: Settings.getDefaultValue("bar.marginVertical")
      onValueChanged: Settings.data.bar.marginVertical = value
    }

    NSpinBox {
      label: I18n.tr("panels.bar.appearance-margins-horizontal")
      description: I18n.tr("panels.bar.appearance-margins-description")
      from: 0
      to: 500
      suffix: "px"
      value: Settings.data.bar.marginHorizontal
      defaultValue: Settings.getDefaultValue("bar.marginHorizontal")
      onValueChanged: Settings.data.bar.marginHorizontal = value
    }
  }

  NDccGap {
    Layout.fillWidth: true
  }

  // SettingsGroup: bar behavior (wheel + middle click; right click is
  // hardcoded to the settings menu so it has no control)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NHeader {
      label: I18n.tr("settings.advanced.bar-behavior")
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-workspace-scroll-label")
      description: I18n.tr("panels.bar.behavior-workspace-scroll-description")
      model: {
        var items = [
              {
                "key": "none",
                "name": I18n.tr("common.none")
              },
              {
                "key": "volume",
                "name": I18n.tr("common.volume")
              },
              {
                "key": "workspace",
                "name": I18n.tr("panels.bar.behavior-workspace-scroll-option-workspace")
              }
            ];
        if (CompositorService.isNiri) {
          items.push({
                       "key": "content",
                       "name": I18n.tr("panels.bar.behavior-workspace-scroll-option-content")
                     });
        }
        return items;
      }
      currentKey: root.effectiveWheelAction
      defaultValue: Settings.getDefaultValue("bar.mouseWheelAction")
      onSelected: key => Settings.data.bar.mouseWheelAction = key
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.reverse-scrolling-label")
      description: I18n.tr("panels.general.reverse-scrolling-description")
      checked: Settings.data.bar.reverseScroll
      defaultValue: Settings.getDefaultValue("bar.reverseScroll")
      onToggled: checked => Settings.data.bar.reverseScroll = checked
      visible: Settings.data.bar.mouseWheelAction !== "none"
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-wheel-wrap-label")
      description: I18n.tr("panels.bar.behavior-wheel-wrap-description")
      checked: Settings.data.bar.mouseWheelWrap
      defaultValue: Settings.getDefaultValue("bar.mouseWheelWrap")
      onToggled: checked => Settings.data.bar.mouseWheelWrap = checked
      visible: Settings.data.bar.mouseWheelAction === "workspace"
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-middle-click-label")
      description: I18n.tr("panels.bar.behavior-middle-click-description")
      model: [
        {
          "key": "none",
          "name": I18n.tr("common.none")
        },
        {
          "key": "controlCenter",
          "name": I18n.tr("tooltips.open-control-center")
        },
        {
          "key": "settings",
          "name": I18n.tr("tooltips.open-settings")
        },
        {
          "key": "launcherPanel",
          "name": I18n.tr("actions.open-launcher")
        },
        {
          "key": "command",
          "name": I18n.tr("actions.run-custom-command")
        }
      ]
      currentKey: root.effectiveMiddleClickAction
      defaultValue: Settings.getDefaultValue("bar.middleClickAction")
      onSelected: key => Settings.data.bar.middleClickAction = key
    }

    NTextInput {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-middle-click-command-label")
      description: I18n.tr("panels.bar.behavior-middle-click-command-description")
      placeholderText: I18n.tr("panels.bar.behavior-middle-click-command-placeholder")
      text: Settings.data.bar.middleClickCommand
      fontFamily: Settings.data.ui.fontFixed
      onTextChanged: Settings.data.bar.middleClickCommand = text
      visible: Settings.data.bar.middleClickAction === "command"
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-middle-click-follow-mouse-label")
      description: I18n.tr("panels.bar.behavior-middle-click-follow-mouse-description")
      checked: Settings.data.bar.middleClickFollowMouse
      defaultValue: Settings.getDefaultValue("bar.middleClickFollowMouse")
      onToggled: checked => Settings.data.bar.middleClickFollowMouse = checked
      visible: Settings.data.bar.middleClickAction !== "none" && Settings.data.bar.middleClickAction !== "command"
    }
  }

  NDccGap {
    Layout.fillWidth: true
    visible: Settings.data.dock.hideMode !== "keep-showing"
  }

  // SettingsGroup: auto-hide delays (effective when hideMode hides the bar)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    visible: Settings.data.dock.hideMode !== "keep-showing"
    NHeader {
      label: I18n.tr("settings.advanced.bar-autohide")
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-auto-hide-delay-label")
      description: I18n.tr("panels.bar.appearance-auto-hide-delay-description")
      from: 100
      to: 2000
      stepSize: 100
      showReset: true
      value: Settings.data.bar.autoHideDelay
      defaultValue: Settings.getDefaultValue("bar.autoHideDelay")
      onMoved: value => Settings.data.bar.autoHideDelay = value
      text: Settings.data.bar.autoHideDelay + "ms"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-auto-show-delay-label")
      description: I18n.tr("panels.bar.appearance-auto-show-delay-description")
      from: 0
      to: 500
      stepSize: 50
      showReset: true
      value: Settings.data.bar.autoShowDelay
      defaultValue: Settings.getDefaultValue("bar.autoShowDelay")
      onMoved: value => Settings.data.bar.autoShowDelay = value
      text: Settings.data.bar.autoShowDelay + "ms"
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.appearance-show-on-workspace-switch-label")
      description: I18n.tr("panels.bar.appearance-show-on-workspace-switch-description")
      checked: Settings.data.bar.showOnWorkspaceSwitch
      defaultValue: Settings.getDefaultValue("bar.showOnWorkspaceSwitch")
      onToggled: checked => Settings.data.bar.showOnWorkspaceSwitch = checked
    }
  }
}
