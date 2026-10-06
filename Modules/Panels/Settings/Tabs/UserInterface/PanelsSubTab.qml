import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings // For SettingsPanel
import qs.Services.UI
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
    NHeader {
      label: I18n.tr("panels.user-interface.settings-panel-header")
    }

    NComboBox {
      label: I18n.tr("panels.user-interface.settings-panel-mode-label")
      description: I18n.tr("panels.user-interface.settings-panel-mode-description")
      Layout.fillWidth: true
      minimumWidth: 220 * Style.uiScaleRatio
      model: [
        {
          "key": "attached",
          "name": I18n.tr("options.settings-panel-mode.attached")
        },
        {
          "key": "centered",
          "name": I18n.tr("options.settings-panel-mode.centered")
        },
        {
          "key": "window",
          "name": I18n.tr("options.settings-panel-mode.window")
        }
      ]
      currentKey: Settings.data.ui.settingsPanelMode
      defaultValue: Settings.getDefaultValue("ui.settingsPanelMode")
      onSelected: key => {
                    // Defer setup to next update so close can do its work properly
                    Qt.callLater(() => {
                                   Settings.data.ui.settingsPanelMode = key;
                                 });
                    if (Settings.data.ui.settingsPanelMode === "window" || key === "window") {
                      // Just switched from/to window, need to close panel
                      var screen = PanelService.openedPanel?.screen || SettingsPanelService.settingsWindow?.screen || PanelService.findScreenForPanels();
                      SettingsPanelService.close(screen);

                      Qt.callLater(() => {
                                     SettingsPanelService.openToTab(SettingsPanel.Tab.UserInterface, 1, screen);
                                   });
                    }
                  }
    }
  }
}
