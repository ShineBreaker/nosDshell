import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../Bar" as BarSettings
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.settingsGroupSpacing
  Layout.fillWidth: true

  NText {
    text: I18n.tr("panels.bar.monitors-desc-new")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  // §3.5.4 — one SettingsGroup per monitor: an identity row, the override
  // switch, the override rows and an expandable widgets editor.
  Repeater {
    model: Quickshell.screens || []
    delegate: ColumnLayout {
      id: monitorGroup
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap

      required property var modelData
      readonly property string screenName: modelData.name || "Unknown"
      readonly property real compositorScale: {
        const info = CompositorService.displayScales[screenName];
        return (info && info.scale) ? info.scale : 1.0;
      }
      readonly property bool hasOverride: Settings.hasScreenOverride(screenName)
      readonly property bool overrideEnabled: Settings.isScreenOverrideEnabled(screenName)
      readonly property string effectivePosition: Settings.getTaskbarPositionForScreen(screenName)
      readonly property string effectiveDensity: Settings.getBarDensityForScreen(screenName)

      NDccRow {
        interactive: false
        Layout.fillWidth: true

        NLabel {
          label: monitorGroup.screenName
          description: I18n.tr("system.monitor-description", {
                                 "model": monitorGroup.modelData.model || I18n.tr("common.unknown"),
                                 "width": Math.round(monitorGroup.modelData.width * monitorGroup.compositorScale),
                                 "height": Math.round(monitorGroup.modelData.height * monitorGroup.compositorScale),
                                 "scale": monitorGroup.compositorScale
                               })
          Layout.fillWidth: true
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: I18n.tr("panels.bar.monitor-override-settings")
        description: I18n.tr("panels.bar.monitor-override-settings-description")
        checked: monitorGroup.overrideEnabled
        onToggled: checked => {
                     Settings.setScreenOverride(monitorGroup.screenName, "enabled", checked);
                     BarService.widgetsRevision++;
                   }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: monitorGroup.overrideEnabled
        label: I18n.tr("panels.bar.appearance-position-label")
        description: I18n.tr("panels.bar.appearance-position-description")
        model: [
          {
            "key": "top",
            "name": I18n.tr("positions.top")
          },
          {
            "key": "bottom",
            "name": I18n.tr("positions.bottom")
          },
          {
            "key": "left",
            "name": I18n.tr("positions.left")
          },
          {
            "key": "right",
            "name": I18n.tr("positions.right")
          }
        ]
        currentKey: monitorGroup.effectivePosition
        onSelected: key => Settings.setScreenOverride(monitorGroup.screenName, "position", key)
      }

      NComboBox {
        Layout.fillWidth: true
        visible: monitorGroup.overrideEnabled
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
        currentKey: monitorGroup.effectiveDensity
        onSelected: key => Settings.setScreenOverride(monitorGroup.screenName, "density", key)
      }

      NComboBox {
        Layout.fillWidth: true
        visible: monitorGroup.overrideEnabled
        label: I18n.tr("common.display-mode")
        description: I18n.tr("panels.bar.appearance-display-mode-description")
        model: [
          {
            "key": "always_visible",
            "name": I18n.tr("hide-modes.visible")
          },
          {
            "key": "non_exclusive",
            "name": I18n.tr("hide-modes.non-exclusive")
          },
          {
            "key": "auto_hide",
            "name": I18n.tr("hide-modes.auto-hide")
          }
        ]
        currentKey: Settings.getBarDisplayModeForScreen(monitorGroup.screenName)
        onSelected: key => Settings.setScreenOverride(monitorGroup.screenName, "displayMode", key)
      }

      NDccRow {
        id: widgetsRow
        Layout.fillWidth: true
        visible: monitorGroup.overrideEnabled
        clickable: true
        onClicked: widgetsEditor.visible = !widgetsEditor.visible

        NText {
          text: I18n.tr("panels.bar.monitor-configure-widgets")
          pointSize: Style.fontSizeS
          color: Color.onShell
          Layout.fillWidth: true
        }

        NIcon {
          icon: widgetsEditor.visible ? "chevron-up" : "chevron-down"
          pointSize: Style.fontSizeL
          color: Color.onShellTertiary
        }
      }

      BarSettings.MonitorWidgetsConfig {
        id: widgetsEditor
        visible: false
        screen: PanelService.liveScreen(monitorGroup.modelData)
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
      }

      NDccRow {
        interactive: false
        Layout.fillWidth: true
        visible: monitorGroup.overrideEnabled

        Item {
          Layout.fillWidth: true
        }

        NButton {
          visible: Settings.hasScreenOverride(monitorGroup.screenName, "widgets")
          fontSize: Style.fontSizeS
          text: I18n.tr("panels.bar.use-global-widgets")
          icon: "refresh"
          onClicked: {
            Settings.clearScreenOverride(monitorGroup.screenName, "widgets");
            BarService.widgetsRevision++;
          }
        }

        NButton {
          fontSize: Style.fontSizeS
          text: I18n.tr("panels.bar.monitor-reset-all")
          icon: "restore"
          onClicked: {
            Settings.clearScreenOverride(monitorGroup.screenName);
            BarService.widgetsRevision++;
          }
        }
      }
    }
  }
}
