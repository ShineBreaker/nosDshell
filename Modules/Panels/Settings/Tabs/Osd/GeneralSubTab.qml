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

  property var addMonitor
  property var removeMonitor

  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  // SettingsGroup 1: the master switch on its own, so the rows it gates can
  // form one SettingsGroup of their own -- same shape as Dock/GeneralSubTab.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      label: I18n.tr("panels.osd.enabled-label")
      description: I18n.tr("panels.osd.enabled-description")
      checked: Settings.data.osd.enabled
      defaultValue: Settings.getDefaultValue("osd.enabled")
      onToggled: checked => Settings.data.osd.enabled = checked
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 2: everything the master switch gates. OSD draws nothing
  // while it is off, so the position choice is gated along with the rest.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    enabled: Settings.data.osd.enabled
    NComboBox {
      label: I18n.tr("common.position")
      description: I18n.tr("panels.osd.location-description")
      model: [
        {
          "key": "top",
          "name": I18n.tr("positions.top-center")
        },
        {
          "key": "top_left",
          "name": I18n.tr("positions.top-left")
        },
        {
          "key": "top_right",
          "name": I18n.tr("positions.top-right")
        },
        {
          "key": "bottom_center",
          "name": I18n.tr("positions.bottom-center")
        },
        {
          "key": "bottom_left",
          "name": I18n.tr("positions.bottom-left")
        },
        {
          "key": "bottom_right",
          "name": I18n.tr("positions.bottom-right")
        },
        {
          "key": "left",
          "name": I18n.tr("positions.center-left")
        },
        {
          "key": "right",
          "name": I18n.tr("positions.center-right")
        }
      ]
      currentKey: Settings.data.osd.location || "top_right"
      defaultValue: Settings.getDefaultValue("osd.location")
      onSelected: key => Settings.data.osd.location = key
    }

    NToggle {
      label: I18n.tr("panels.osd.always-on-top-label")
      description: I18n.tr("panels.osd.always-on-top-description")
      checked: Settings.data.osd.overlayLayer
      defaultValue: Settings.getDefaultValue("osd.overlayLayer")
      onToggled: checked => Settings.data.osd.overlayLayer = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.osd.duration-auto-hide-label")
      description: I18n.tr("panels.osd.duration-auto-hide-description")
      from: 500
      to: 5000
      stepSize: 100
      showReset: true
      value: Settings.data.osd.autoHideMs
      defaultValue: Settings.getDefaultValue("osd.autoHideMs")
      onMoved: value => Settings.data.osd.autoHideMs = value
      text: Math.round(Settings.data.osd.autoHideMs / 1000 * 10) / 10 + "s"
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 3: monitor selection, gated like the rest while off.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    enabled: Settings.data.osd.enabled
    NText {
      text: I18n.tr("panels.osd.monitors-desc")
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Repeater {
      model: Quickshell.screens || []
      delegate: NCheckbox {
        Layout.fillWidth: true
        readonly property real compositorScale: {
          const info = CompositorService.displayScales[modelData.name];
          return (info && info.scale) ? info.scale : 1.0;
        }
        label: modelData.name || I18n.tr("common.unknown")
        description: {
          I18n.tr("system.monitor-description", {
                    "model": modelData.model,
                    "width": modelData.width * compositorScale,
                    "height": modelData.height * compositorScale,
                    "scale": compositorScale
                  });
        }
        checked: (Settings.data.osd.monitors || []).indexOf(modelData.name) !== -1
        onToggled: checked => {
                     if (checked) {
                       Settings.data.osd.monitors = root.addMonitor(Settings.data.osd.monitors, modelData.name);
                     } else {
                       Settings.data.osd.monitors = root.removeMonitor(Settings.data.osd.monitors, modelData.name);
                     }
                   }
      }
    }
  }
}
