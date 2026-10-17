import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../Bar" as BarSettings
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// Bar keys — the "状态栏" sub-tab of the stacked 任务栏 module page
// (DESIGN §3.5.3): the optional status bar feature switch first, then its
// placement/density/monitor configuration; then the bar appearance,
// behaviour and auto-hide groups that apply to whichever bar exists. The
// status-bar section is fashion-only (in efficient mode the bar IS the
// taskbar — BarService.effectivelyVisible) so it hides with the mode, and
// its configuration hides when the feature is off.
ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  readonly property bool fashionMode: Settings.data.dock.mode === "fashion"
  readonly property string effectiveWheelAction: Settings.data.bar.mouseWheelAction || "none"
  readonly property string effectiveMiddleClickAction: Settings.data.bar.middleClickAction || "none"
  readonly property string effectiveRightClickAction: Settings.data.bar.rightClickAction || "controlCenter"

  // 二级页 content: the global widget-layout editor (screen: null edits
  // Settings.data.bar.widgets directly).
  Component {
    id: widgetsPage
    BarSettings.MonitorWidgetsConfig {
      objectName: "widgetsEditorPage"
    }
  }

  // ---- Status bar feature (DESIGN §3.13): switch, then its settings ----
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    visible: root.fashionMode

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("settings.taskbar.statusbar-enabled-label")
      description: I18n.tr("settings.taskbar.statusbar-enabled-description")
      checked: Settings.data.bar.enabled
      defaultValue: Settings.getDefaultValue("bar.enabled")
      onToggled: checked => Settings.data.bar.enabled = checked
    }

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
      visible: Settings.data.bar.enabled
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap
      visible: Settings.data.bar.enabled

      NComboBox {
        Layout.fillWidth: true
        label: I18n.tr("settings.taskbar.statusbar-position")
        model: [
          {
            "key": "top",
            "name": I18n.tr("dock-menu.location-top")
          },
          {
            "key": "bottom",
            "name": I18n.tr("dock-menu.location-bottom")
          },
          {
            "key": "left",
            "name": I18n.tr("dock-menu.location-left")
          },
          {
            "key": "right",
            "name": I18n.tr("dock-menu.location-right")
          }
        ]
        currentKey: Settings.data.bar.position
        defaultValue: Settings.getDefaultValue("bar.position")
        onSelected: key => Settings.data.bar.position = key
      }

      NComboBox {
        Layout.fillWidth: true
        label: I18n.tr("settings.taskbar.statusbar-state")
        model: [
          {
            "key": "always_visible",
            "name": I18n.tr("dock-menu.state-keep-showing")
          },
          {
            "key": "non_exclusive",
            "name": I18n.tr("hide-modes.non-exclusive")
          },
          {
            "key": "auto_hide",
            "name": I18n.tr("dock-menu.state-keep-hidden")
          }
        ]
        currentKey: Settings.data.bar.displayMode
        defaultValue: Settings.getDefaultValue("bar.displayMode")
        onSelected: key => Settings.data.bar.displayMode = key
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

      NComboBox {
        Layout.fillWidth: true
        label: I18n.tr("panels.bar.appearance-type-label")
        description: I18n.tr("panels.bar.appearance-type-description")
        model: [
          {
            "key": "simple",
            "name": I18n.tr("options.bar.type-simple")
          },
          {
            "key": "framed",
            "name": I18n.tr("options.bar.type-framed")
          }
        ]
        currentKey: Settings.data.bar.barType
        defaultValue: Settings.getDefaultValue("bar.barType")
        onSelected: key => Settings.data.bar.barType = key
      }

      NToggle {
        Layout.fillWidth: true
        label: I18n.tr("options.bar.type-floating")
        description: I18n.tr("panels.bar.appearance-floating-description")
        checked: Settings.data.bar.floating
        defaultValue: Settings.getDefaultValue("bar.floating")
        onToggled: checked => Settings.data.bar.floating = checked
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

      NText {
        visible: (Quickshell.screens || []).length > 1
        text: I18n.tr("settings.taskbar.statusbar-monitors")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      Repeater {
        model: (Quickshell.screens || []).length > 1 ? (Quickshell.screens || []) : []
        delegate: NCheckbox {
          Layout.fillWidth: true
          required property var modelData
          readonly property real compositorScale: {
            const info = CompositorService.displayScales[modelData.name];
            return (info && info.scale) ? info.scale : 1.0;
          }
          label: modelData.name || "Unknown"
          description: {
            I18n.tr("system.monitor-description", {
                      "model": modelData.model,
                      "width": modelData.width * compositorScale,
                      "height": modelData.height * compositorScale,
                      "scale": compositorScale
                    });
          }
          checked: (Settings.data.bar.monitors || []).indexOf(modelData.name) !== -1
          onToggled: checked => {
                       var arr = (Settings.data.bar.monitors || []).slice();
                       if (checked) {
                         if (arr.indexOf(modelData.name) === -1)
                         arr.push(modelData.name);
                       } else {
                         arr = arr.filter(function (n) {
                           return n !== modelData.name;
                         });
                       }
                       Settings.data.bar.monitors = arr;
                     }
        }
      }

      // Widget layout — the global bar.widgets editor gets its own 二级页
      // (DESIGN §3.5.3): a "下一页" row pushes it instead of folding it inline.
      NNextPageRow {
        objectName: "nextPage-barWidgets"
        Layout.fillWidth: true
        label: I18n.tr("panels.bar.monitor-configure-widgets")
        page: widgetsPage
      }
    }

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
      visible: root.anyBarAlive
    }
  }

  // Groups below configure whichever bar is on screen: in efficient mode the
  // bar is always the taskbar, in fashion mode only the enabled status bar —
  // so with the feature off they are dead settings and hide too.
  readonly property bool anyBarAlive: !fashionMode || Settings.data.bar.enabled

  // SettingsGroup: bar appearance (efficient-mode bar still reads these)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    visible: root.anyBarAlive
    NHeader {
      label: I18n.tr("settings.advanced.bar-appearance")
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
      visible: Settings.getEffectiveBarType() === "simple" && !Settings.isBarFloating()
      label: I18n.tr("panels.bar.appearance-outer-corners-label")
      description: I18n.tr("panels.bar.appearance-outer-corners-description")
      checked: Settings.data.bar.outerCorners
      defaultValue: Settings.getDefaultValue("bar.outerCorners")
      onToggled: checked => Settings.data.bar.outerCorners = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Settings.getEffectiveBarType() === "framed"
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
      visible: Settings.getEffectiveBarType() === "framed"
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
      visible: Settings.isBarFloating()
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
      visible: Settings.isBarFloating()
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
    visible: root.anyBarAlive
  }

  // SettingsGroup: bar behavior (wheel + middle click; the right-click trio
  // only applies to the fashion status bar — in efficient mode right-click
  // is the DDE dock settings menu, so its controls hide with the mode)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    visible: root.anyBarAlive
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

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-right-click-label")
      description: I18n.tr("panels.bar.behavior-right-click-description")
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
      currentKey: root.effectiveRightClickAction
      defaultValue: Settings.getDefaultValue("bar.rightClickAction")
      onSelected: key => Settings.data.bar.rightClickAction = key
      visible: root.fashionMode && Settings.data.bar.enabled
    }

    NTextInput {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-right-click-command-label")
      description: I18n.tr("panels.bar.behavior-right-click-command-description")
      placeholderText: I18n.tr("panels.bar.behavior-right-click-command-placeholder")
      text: Settings.data.bar.rightClickCommand
      fontFamily: Settings.data.ui.fontFixed
      onTextChanged: Settings.data.bar.rightClickCommand = text
      visible: root.fashionMode && Settings.data.bar.enabled && Settings.data.bar.rightClickAction === "command"
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.behavior-right-click-follow-mouse-label")
      description: I18n.tr("panels.bar.behavior-right-click-follow-mouse-description")
      checked: Settings.data.bar.rightClickFollowMouse
      defaultValue: Settings.getDefaultValue("bar.rightClickFollowMouse")
      onToggled: checked => Settings.data.bar.rightClickFollowMouse = checked
      visible: root.fashionMode && Settings.data.bar.enabled && Settings.data.bar.rightClickAction !== "none" && Settings.data.bar.rightClickAction !== "command" && !(Settings.data.bar.rightClickAction === "settings" && Settings.data.ui.settingsPanelMode === "window")
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

  NDccGap {
    Layout.fillWidth: true
    visible: root.anyBarAlive && (Settings.data.dock.hideMode !== "keep-showing" || (root.fashionMode && Settings.data.bar.enabled && Settings.data.bar.displayMode === "auto_hide"))
  }

  // SettingsGroup: auto-hide delays (effective when hideMode hides the bar,
  // or when the fashion status bar auto-hides while the dock stays shown —
  // BarContentWindow feeds the status-bar path from these delays)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    visible: root.anyBarAlive && (Settings.data.dock.hideMode !== "keep-showing" || (root.fashionMode && Settings.data.bar.enabled && Settings.data.bar.displayMode === "auto_hide"))
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
  }
}
