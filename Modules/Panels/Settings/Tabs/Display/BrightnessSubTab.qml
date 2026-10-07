import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.settingsGroupSpacing
  Layout.fillWidth: true

  // §3.5.4 — one SettingsGroup per monitor: an identity row, a DCCSlider
  // brightness row and, for internal panels, a backlight-device Option row.
  Repeater {
    model: Quickshell.screens || []
    delegate: ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap

      property var brightnessMonitor: BrightnessService.getMonitorForScreen(modelData)
      property real localBrightness: 0.5
      property bool localBrightnessChanging: false
      readonly property string automaticOptionLabel: {
        var baseLabel = I18n.tr("panels.display.monitors-backlight-device-auto-option");
        var autoDevicePath = (BrightnessService.availableBacklightDevices && BrightnessService.availableBacklightDevices.length > 0) ? BrightnessService.availableBacklightDevices[0] : "";
        if (autoDevicePath === "")
          return baseLabel;

        var autoDeviceName = BrightnessService.getBacklightDeviceName(autoDevicePath) || autoDevicePath;
        return baseLabel + "(" + autoDeviceName + ")";
      }
      readonly property var backlightDeviceOptions: {
        var options = [
              {
                "key": "",
                "name": automaticOptionLabel
              }
            ];

        var devices = BrightnessService.availableBacklightDevices || [];
        for (var i = 0; i < devices.length; i++) {
          var devicePath = devices[i];
          var deviceName = BrightnessService.getBacklightDeviceName(devicePath) || devicePath;
          options.push({
                         "key": devicePath,
                         "name": deviceName
                       });
        }
        return options;
      }

      onBrightnessMonitorChanged: {
        if (brightnessMonitor && !localBrightnessChanging)
          localBrightness = brightnessMonitor.brightness || 0.5;
      }

      Connections {
        target: BrightnessService
        function onMonitorBrightnessChanged(monitor, newBrightness) {
          if (monitor === brightnessMonitor && !localBrightnessChanging) {
            localBrightness = newBrightness;
          }
        }
      }
      Connections {
        target: brightnessMonitor
        ignoreUnknownSignals: true
        function onBrightnessUpdated() {
          if (brightnessMonitor && !localBrightnessChanging) {
            localBrightness = brightnessMonitor.brightness || 0;
          }
        }
      }
      Timer {
        id: debounceTimer
        interval: 120
        repeat: false
        onTriggered: {
          if (brightnessMonitor && brightnessMonitor.brightnessControlAvailable && Math.abs(localBrightness - brightnessMonitor.brightness) >= 0.005) {
            brightnessMonitor.setBrightness(localBrightness);
          }
        }
      }

      NDccRow {
        interactive: false
        Layout.fillWidth: true

        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignBottom
          spacing: Style.marginM

          NIcon {
            icon: brightnessMonitor && brightnessMonitor.method == "internal" ? "device-laptop" : "device-desktop"
            pointSize: Style.fontSizeXL
            color: Color.onShell
            Layout.alignment: Qt.AlignVCenter
          }

          NText {
            text: modelData.name || "Unknown"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightSemiBold
            Layout.alignment: Qt.AlignBottom
          }

          NText {
            Layout.fillWidth: true
            readonly property real compositorScale: {
              const info = CompositorService.displayScales[modelData.name];
              return (info && info.scale) ? info.scale : 1.0;
            }
            text: {
              I18n.tr("system.monitor-description", {
                        "model": modelData.model,
                        "width": modelData.width * compositorScale,
                        "height": modelData.height * compositorScale,
                        "scale": compositorScale
                      });
            }
            pointSize: Style.fontSizeS
            color: Color.onShellTertiary
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignBottom
          }
        }
      }

      NValueSlider {
        id: brightnessSlider
        Layout.fillWidth: true
        visible: brightnessMonitor !== undefined && brightnessMonitor !== null
        label: I18n.tr("common.brightness")
        description: (brightnessMonitor && !brightnessMonitor.brightnessControlAvailable && !(brightnessMonitor.method === "internal" && brightnessMonitor.initInProgress)) ? (!Settings.data.brightness.enableDdcSupport ? I18n.tr("panels.display.monitors-brightness-unavailable-ddc-disabled") : I18n.tr("panels.display.monitors-brightness-unavailable-generic")) :
                                                                                                                                                                              ""
        text: brightnessMonitor ? Math.round(localBrightness * 100) + "%" : "N/A"
        from: 0
        to: 1
        value: localBrightness
        stepSize: 0.01
        enabled: brightnessMonitor ? brightnessMonitor.brightnessControlAvailable : false
        onMoved: value => {
                   if (brightnessMonitor && brightnessMonitor.brightnessControlAvailable) {
                     localBrightness = value;
                     debounceTimer.restart();
                   }
                 }
        onPressedChanged: (pressed, value) => {
                            localBrightnessChanging = pressed;
                            if (brightnessMonitor && brightnessMonitor.brightnessControlAvailable) {
                              localBrightness = value;
                              debounceTimer.restart();
                            }
                          }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: brightnessMonitor && brightnessMonitor.method === "internal"
        label: I18n.tr("panels.display.monitors-backlight-device-label")
        description: I18n.tr("panels.display.monitors-backlight-device-description")
        model: backlightDeviceOptions
        currentKey: BrightnessService.getMappedBacklightDevice(modelData.name) || ""
        onSelected: key => BrightnessService.setMappedBacklightDevice(modelData.name, key)
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NSpinBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.display.monitors-brightness-step-label")
      description: I18n.tr("panels.display.monitors-brightness-step-description")
      minimum: 1
      maximum: 50
      value: Settings.data.brightness.brightnessStep
      stepSize: 1
      suffix: "%"
      onValueChanged: Settings.data.brightness.brightnessStep = value
      defaultValue: Settings.getDefaultValue("brightness.brightnessStep")
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.display.monitors-enforce-minimum-label")
      description: I18n.tr("panels.display.monitors-enforce-minimum-description")
      checked: Settings.data.brightness.enforceMinimum
      onToggled: checked => Settings.data.brightness.enforceMinimum = checked
      defaultValue: Settings.getDefaultValue("brightness.enforceMinimum")
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.display.monitors-external-brightness-label")
      description: I18n.tr("panels.display.monitors-external-brightness-description")
      checked: Settings.data.brightness.enableDdcSupport
      onToggled: checked => {
                   Settings.data.brightness.enableDdcSupport = checked;
                 }
      defaultValue: Settings.getDefaultValue("brightness.enableDdcSupport")
    }
  }
}
