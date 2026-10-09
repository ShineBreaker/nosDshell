import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // Helper functions to update arrays immutably
  function addMonitor(list, name) {
    const arr = (list || []).slice();
    if (!arr.includes(name))
      arr.push(name);
    return arr;
  }
  function removeMonitor(list, name) {
    return (list || []).filter(function (n) {
      return n !== name;
    });
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    enabled: Settings.data.dock.enabled

    NText {
      text: I18n.tr("panels.dock.monitors-desc")
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.dock.monitors-only-same-monitor-label")
      description: I18n.tr("panels.dock.monitors-only-same-monitor-description")
      checked: Settings.data.dock.onlySameOutput
      defaultValue: Settings.getDefaultValue("dock.onlySameOutput")
      onToggled: checked => Settings.data.dock.onlySameOutput = checked
    }

    Repeater {
      model: Quickshell.screens || []
      delegate: NCheckbox {
        Layout.fillWidth: true
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
        checked: (Settings.data.dock.monitors || []).indexOf(modelData.name) !== -1
        onToggled: checked => {
                     if (checked) {
                       Settings.data.dock.monitors = root.addMonitor(Settings.data.dock.monitors, modelData.name);
                     } else {
                       Settings.data.dock.monitors = root.removeMonitor(Settings.data.dock.monitors, modelData.name);
                     }
                   }
      }
    }
  }

  NDccGap {
    Layout.fillWidth: true
  }

  // Per-screen overrides of the bar/taskbar itself (position, density,
  // display mode, widget layout) — the bar is the taskbar in efficient mode
  // and the status bar in fashion mode.
  ScreenOverridesSubTab {
    Layout.fillWidth: true
  }
}
