import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Hardware
import qs.Services.Power
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  dimsBackground: false

  preferredWidth: Math.round(260 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    property real contentPreferredHeight: Math.min(mainLayout.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    property var batteryWidgetInstance: BarService.lookupWidget("Battery", screen ? screen.name : null)
    readonly property var batteryWidgetSettings: batteryWidgetInstance ? batteryWidgetInstance.widgetSettings : null
    readonly property var batteryWidgetMetadata: BarWidgetRegistry.widgetMetadata["Battery"]
    readonly property bool profilesAvailable: PowerProfileService.available
    readonly property var powerProfiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    property int profileIndex: profileToIndex(PowerProfileService.profile)
    readonly property bool showPowerProfiles: panelID ? panelID.showPowerProfiles : resolveWidgetSetting("showPowerProfiles", false)
    readonly property bool showPerformanceMode: panelID ? panelID.showPerformanceMode : resolveWidgetSetting("showPerformanceMode", false)

    function profileToIndex(p) {
      return powerProfiles.indexOf(p) ?? 1;
    }

    function indexToProfile(idx) {
      return powerProfiles[idx] ?? PowerProfile.Balanced;
    }

    function setProfileByIndex(idx) {
      var prof = indexToProfile(idx);
      profileIndex = idx;
      PowerProfileService.setProfile(prof);
    }

    function resolveWidgetSetting(key, defaultValue) {
      if (batteryWidgetSettings && batteryWidgetSettings[key] !== undefined)
        return batteryWidgetSettings[key];
      if (batteryWidgetMetadata && batteryWidgetMetadata[key] !== undefined)
        return batteryWidgetMetadata[key];
      return defaultValue;
    }

    Connections {
      target: PowerProfileService
      function onProfileChanged() {
        panelContent.profileIndex = panelContent.profileToIndex(PowerProfileService.profile);
      }
    }

    Connections {
      target: BarService
      function onActiveWidgetsChanged() {
        panelContent.batteryWidgetInstance = BarService.lookupWidget("Battery", screen ? screen.name : null);
      }
    }

    component BatteryRow: ColumnLayout {
      id: batteryRow

      property var device: null

      spacing: Style.marginXXS
      Layout.fillWidth: true

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 36

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginM
          spacing: Style.marginS

          NIcon {
            icon: BatteryService.getIcon(BatteryService.getPercentage(batteryRow.device), BatteryService.isCharging(batteryRow.device), BatteryService.isPluggedIn(batteryRow.device), BatteryService.isDeviceReady(batteryRow.device))
            color: (BatteryService.isCharging(batteryRow.device) || BatteryService.isPluggedIn(batteryRow.device)) ? Color.accent : (BatteryService.isCriticalBattery(batteryRow.device) || BatteryService.isLowBattery(batteryRow.device)) ? Color.mError : Color.onShell
            pointSize: Style.fontSizeXL
          }

          NText {
            Layout.fillWidth: true
            text: BatteryService.getDeviceName(batteryRow.device) || I18n.tr("common.battery")
            pointSize: Style.fontSizeM
            elide: Text.ElideRight

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: {
                if (batteryRow.device && batteryRow.device.healthSupported) {
                  TooltipService.show(parent, `${I18n.tr("battery.battery-health")}: ${Math.round(batteryRow.device.healthPercentage)}%`);
                }
              }
              onExited: TooltipService.hide()
            }
          }

          NText {
            text: `${BatteryService.getPercentage(batteryRow.device)}%`
            pointSize: Style.fontSizeS
            font.weight: Font.DemiBold
            color: (BatteryService.isCharging(batteryRow.device) || BatteryService.isPluggedIn(batteryRow.device)) ? Color.accent : Color.onShellSecondary
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 22

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginM
          spacing: Style.marginM

          NLinearGauge {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            orientation: Qt.Horizontal
            ratio: Math.max(0, Math.min(1, BatteryService.getPercentage(batteryRow.device) / 100))
            fillColor: (BatteryService.isCriticalBattery(batteryRow.device) || BatteryService.isLowBattery(batteryRow.device)) ? Color.mError : Color.accent
          }

          NText {
            text: BatteryService.getTimeRemainingText(batteryRow.device)
            pointSize: Style.fontSizeXS
            color: Color.onShellTertiary
          }
        }
      }
    }

    NScrollView {
      id: scrollView
      anchors.fill: parent
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      contentWidth: availableWidth

      ColumnLayout {
        id: mainLayout
        width: scrollView.availableWidth
        spacing: Style.marginS

        // ---- Battery ----
        NPanelSection {
          text: I18n.tr("common.battery")
          Layout.fillWidth: true
          Layout.topMargin: Style.marginM
          visible: BatteryService.laptopBatteries.length > 0 || BatteryService.bluetoothBatteries.length > 0
        }

        Repeater {
          model: BatteryService.laptopBatteries
          delegate: BatteryRow {
            device: modelData
          }
        }

        Repeater {
          model: BatteryService.bluetoothBatteries
          delegate: BatteryRow {
            device: modelData
          }
        }

        NText {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          Layout.preferredHeight: 36
          visible: BatteryService.laptopBatteries.length === 0 && BatteryService.bluetoothBatteries.length === 0
          text: I18n.tr("battery.no-battery-detected")
          pointSize: Style.fontSizeM
          color: Color.onShellSecondary
          verticalAlignment: Text.AlignVCenter
        }

        // ---- Power profile ----
        NPanelSection {
          text: I18n.tr("battery.power-profile")
          Layout.fillWidth: true
          visible: panelContent.showPowerProfiles && panelContent.profilesAvailable
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          visible: panelContent.showPowerProfiles && panelContent.profilesAvailable

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginM

            NText {
              Layout.fillWidth: true
              text: PowerProfileService.getName(panelContent.profileIndex)
              pointSize: Style.fontSizeM
              elide: Text.ElideRight
            }

            NIcon {
              icon: "powersaver"
              pointSize: Style.fontSizeS
              color: PowerProfileService.getIcon() === "powersaver" ? Color.accent : Color.onShellTertiary
            }

            NIcon {
              icon: "balanced"
              pointSize: Style.fontSizeS
              color: PowerProfileService.getIcon() === "balanced" ? Color.accent : Color.onShellTertiary
            }

            NIcon {
              icon: "performance"
              pointSize: Style.fontSizeS
              color: PowerProfileService.getIcon() === "performance" ? Color.accent : Color.onShellTertiary
            }
          }
        }

        NValueSlider {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          Layout.preferredHeight: 22
          visible: panelContent.showPowerProfiles && panelContent.profilesAvailable
          from: 0
          to: 2
          stepSize: 1
          snapAlways: true
          value: panelContent.profileIndex
          enabled: panelContent.profilesAvailable
          onPressedChanged: (pressed, v) => {
                              if (!pressed) {
                                panelContent.setProfileByIndex(v);
                              }
                            }
          onMoved: v => {
                     panelContent.profileIndex = v;
                   }
        }

        // Performance mode toggle (opt-in)
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          Layout.topMargin: Style.marginS
          visible: panelContent.showPerformanceMode

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginS
            spacing: Style.marginS

            NIcon {
              icon: PowerProfileService.performanceMode ? "rocket" : "rocket-off"
              pointSize: Style.fontSizeXL
              color: PowerProfileService.performanceMode ? Color.accent : Color.onShellTertiary
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("toast.performance-mode.label")
              pointSize: Style.fontSizeM
              elide: Text.ElideRight
            }

            NToggle {
              Layout.fillWidth: false
              checked: PowerProfileService.performanceMode
              onToggled: checked => PowerProfileService.performanceMode = checked
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
