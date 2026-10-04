import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(260 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent
    property real contentPreferredHeight: Math.min(mainColumn.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    property var brightnessWidgetInstance: BarService.lookupWidget("Brightness", screen ? screen.name : null)
    readonly property var brightnessWidgetSettings: brightnessWidgetInstance ? brightnessWidgetInstance.widgetSettings : null
    readonly property var brightnessWidgetMetadata: BarWidgetRegistry.widgetMetadata["Brightness"]

    function resolveWidgetSetting(key, defaultValue) {
      if (brightnessWidgetSettings && brightnessWidgetSettings[key] !== undefined)
        return brightnessWidgetSettings[key];
      if (brightnessWidgetMetadata && brightnessWidgetMetadata[key] !== undefined)
        return brightnessWidgetMetadata[key];
      return defaultValue;
    }

    Connections {
      target: BarService
      function onActiveWidgetsChanged() {
        panelContent.brightnessWidgetInstance = BarService.lookupWidget("Brightness", screen ? screen.name : null);
      }
    }

    property real globalBrightness: 0
    property bool globalBrightnessChanging: false
    property int globalBrightnessCapableMonitors: 0

    function getIcon(brightness) {
      return brightness <= 0.5 ? "brightness-low" : "brightness-high";
    }

    function getControllableMonitors() {
      var monitors = BrightnessService.monitors || [];
      return monitors.filter(m => m && m.brightnessControlAvailable);
    }

    function updateGlobalBrightness() {
      var monitors = getControllableMonitors();
      panelContent.globalBrightnessCapableMonitors = monitors.length;

      if (panelContent.globalBrightnessChanging)
        return;

      if (monitors.length === 0) {
        panelContent.globalBrightness = 0;
        return;
      }

      var total = 0;
      monitors.forEach(m => {
                         var brightnessValue = isNaN(m.brightness) ? 0 : m.brightness;
                         total += brightnessValue;
                       });
      panelContent.globalBrightness = total / monitors.length;
    }

    function applyGlobalBrightness(value) {
      var monitors = BrightnessService.monitors || [];
      monitors.forEach(m => {
                         if (m && m.brightnessControlAvailable) {
                           m.setBrightness(value);
                         }
                       });
    }

    Component.onCompleted: updateGlobalBrightness()

    Connections {
      target: BrightnessService
      function onMonitorBrightnessChanged(monitor, newBrightness) {
        panelContent.updateGlobalBrightness();
      }
      function onMonitorsChanged() {
        panelContent.updateGlobalBrightness();
      }
      function onDdcMonitorsChanged() {
        panelContent.updateGlobalBrightness();
      }
    }

    NScrollView {
      id: brightnessScrollView
      anchors.fill: parent
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      contentWidth: availableWidth
      reserveScrollbarSpace: false

      ColumnLayout {
        id: mainColumn
        spacing: Style.marginS
        width: brightnessScrollView.availableWidth

        // ---- Global brightness (when the widget applies to all monitors) ----
        NPanelSection {
          Layout.fillWidth: true
          Layout.topMargin: Style.marginM
          text: I18n.tr("panels.display.monitors-global-brightness-label")
          visible: panelContent.globalBrightnessCapableMonitors > 1 && panelContent.resolveWidgetSetting("applyToAllMonitors", false)
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          visible: panelContent.globalBrightnessCapableMonitors > 1 && panelContent.resolveWidgetSetting("applyToAllMonitors", false)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginS

            NIcon {
              icon: panelContent.getIcon(panelContent.globalBrightness)
              pointSize: Style.fontSizeXL
              color: Color.onShell
            }

            NValueSlider {
              id: globalBrightnessSlider
              from: 0
              to: 1
              value: panelContent.globalBrightness
              stepSize: 0.01
              enabled: panelContent.globalBrightnessCapableMonitors > 0
              onMoved: value => {
                         panelContent.globalBrightness = value;
                         panelContent.applyGlobalBrightness(value);
                       }
              onPressedChanged: (pressed, value) => {
                                  panelContent.globalBrightnessChanging = pressed;
                                  panelContent.globalBrightness = value;
                                  panelContent.applyGlobalBrightness(value);
                                }
              Layout.fillWidth: true
              Layout.preferredHeight: 22
              text: ""
            }

            NText {
              text: panelContent.globalBrightnessCapableMonitors > 0 ? Math.round(panelContent.globalBrightness * 100) + "%" : "N/A"
              Layout.preferredWidth: 40
              horizontalAlignment: Text.AlignRight
              color: Color.onShellSecondary
              pointSize: Style.fontSizeS
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }

        // ---- Per-monitor sliders ----
        NPanelSection {
          Layout.fillWidth: true
          Layout.topMargin: (panelContent.globalBrightnessCapableMonitors <= 1 || !panelContent.resolveWidgetSetting("applyToAllMonitors", false)) ? Style.marginM : 0
          text: I18n.tr("panels.display.section-monitors")
          visible: (Quickshell.screens || []).length > 0
        }

        Repeater {
          model: Quickshell.screens || []
          delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            property var brightnessMonitor: BrightnessService.getMonitorForScreen(modelData)
            readonly property real compositorScale: {
              const info = CompositorService.displayScales[modelData.name];
              return (info && info.scale) ? info.scale : 1.0;
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 36

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginM
                spacing: Style.marginM

                NText {
                  Layout.fillWidth: true
                  text: modelData.name || "Unknown"
                  pointSize: Style.fontSizeM
                  elide: Text.ElideRight
                }

                NText {
                  text: Math.round(modelData.width * compositorScale) + "x" + Math.round(modelData.height * compositorScale)
                  pointSize: Style.fontSizeS
                  color: Color.onShellTertiary
                }
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 36

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginM
                spacing: Style.marginS

                NIcon {
                  icon: getIcon(brightnessMonitor ? brightnessMonitor.brightness : 0)
                  pointSize: Style.fontSizeXL
                  color: Color.onShell
                }

                NValueSlider {
                  id: brightnessSlider
                  from: 0
                  to: 1
                  value: brightnessMonitor ? brightnessMonitor.brightness : 0.5
                  stepSize: 0.01
                  enabled: brightnessMonitor ? brightnessMonitor.brightnessControlAvailable : false
                  onMoved: value => {
                             if (brightnessMonitor && brightnessMonitor.brightnessControlAvailable) {
                               brightnessMonitor.setBrightness(value);
                             }
                           }
                  onPressedChanged: (pressed, value) => {
                                      if (brightnessMonitor && brightnessMonitor.brightnessControlAvailable) {
                                        brightnessMonitor.setBrightness(value);
                                      }
                                    }
                  Layout.fillWidth: true
                  Layout.preferredHeight: 22
                  text: brightnessMonitor ? Math.round(brightnessSlider.value * 100) + "%" : "N/A"
                }
              }
            }
          }
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }
  }
}
