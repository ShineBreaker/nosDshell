import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root

  spacing: Style.marginM

  // Options
  NScrollView {
    id: dockScrollView
    Layout.fillWidth: true
    Layout.fillHeight: true
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded

    ColumnLayout {
      width: dockScrollView.availableWidth
      spacing: Style.marginL

      NToggle {
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.enabled-label")
        description: I18n.tr("panels.dock.enabled-description")
        checked: Settings.data.dock.enabled
        onToggled: checked => Settings.data.dock.enabled = checked
      }

      // 任务栏模式（DESIGN §3.1）：fashion 悬浮居中，efficient 通栏贴边
      NComboBox {
        visible: Settings.data.dock.enabled
        Layout.fillWidth: true
        label: I18n.tr("dock-menu.mode")
        model: [
          {
            "key": "fashion",
            "name": I18n.tr("dock-menu.mode-fashion")
          },
          {
            "key": "efficient",
            "name": I18n.tr("dock-menu.mode-efficient")
          }
        ]
        currentKey: Settings.data.dock.mode
        onSelected: key => Settings.data.dock.mode = key
      }

      // 显示行为：DDE hide-mode 三态（DESIGN §3.1.1）；旧 dock.displayMode 在 fashion 下 inert
      NComboBox {
        visible: Settings.data.dock.enabled
        Layout.fillWidth: true
        label: I18n.tr("panels.display.title")
        description: I18n.tr("panels.dock.appearance-display-description")
        model: [
          {
            "key": "keep-showing",
            "name": I18n.tr("dock-menu.state-keep-showing")
          },
          {
            "key": "keep-hidden",
            "name": I18n.tr("dock-menu.state-keep-hidden")
          },
          {
            "key": "smart-hide",
            "name": I18n.tr("dock-menu.state-smart-hide")
          }
        ]
        currentKey: Settings.data.dock.hideMode
        onSelected: key => Settings.data.dock.hideMode = key
      }

      // 图标尺寸：DDE 三档 30/36/48（DESIGN §3.1.1）；旧 dock.size 是 0–2 比例，已改写 iconSize
      NComboBox {
        visible: Settings.data.dock.enabled
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.appearance-icon-size-label")
        description: I18n.tr("panels.dock.appearance-icon-size-description")
        model: [
          {
            "key": "30",
            "name": I18n.tr("dock-menu.size-small")
          },
          {
            "key": "36",
            "name": I18n.tr("dock-menu.size-medium")
          },
          {
            "key": "48",
            "name": I18n.tr("dock-menu.size-large")
          }
        ]
        currentKey: Settings.data.dock.iconSize
        onSelected: key => Settings.data.dock.iconSize = parseInt(key)
      }

      NToggle {
        visible: Settings.data.dock.enabled
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.monitors-only-same-monitor-label")
        description: I18n.tr("panels.dock.monitors-only-same-monitor-description")
        checked: Settings.data.dock.onlySameOutput
        onToggled: checked => Settings.data.dock.onlySameOutput = checked
      }

      NToggle {
        visible: Settings.data.dock.enabled
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.appearance-colorize-icons-label")
        description: I18n.tr("panels.dock.appearance-colorize-icons-description")
        checked: Settings.data.dock.colorizeIcons
        onToggled: checked => Settings.data.dock.colorizeIcons = checked
      }

      NHeader {
        visible: Settings.data.dock.enabled
        label: I18n.tr("panels.dock.monitors-title")
        description: I18n.tr("panels.dock.monitors-desc")
      }

      Repeater {
        visible: Settings.data.dock.enabled
        model: Quickshell.screens || []
        delegate: NCheckbox {
          Layout.fillWidth: true
          readonly property real compositorScale: {
            const info = CompositorService.displayScales[modelData.name];
            return (info && info.scale) ? info.scale : 1.0;
          }
          label: modelData.name || "Unknown"
          visible: Settings.data.dock.enabled
          description: {
            I18n.tr("system.monitor-description", {
                      "model": modelData.model,
                      "width": modelData.width * compositorScale,
                      "height": modelData.height * compositorScale,
                      "scale": compositorScale
                    });
          }
          checked: (Settings.data.dock.monitors || []).indexOf(modelData.name) !== -1
          onToggled: checked => {
                       if (checked) {
                         const arr = (Settings.data.dock.monitors || []).slice();
                         if (arr.indexOf(modelData.name) === -1)
                         arr.push(modelData.name);
                         Settings.data.dock.monitors = arr;
                       } else {
                         Settings.data.dock.monitors = (Settings.data.dock.monitors || []).filter(function (n) {
                           return n !== modelData.name;
                         });
                       }
                     }
        }
      }
    }
  }
}
