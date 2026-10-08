import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services.Media
import qs.Widgets

ColumnLayout {
    id: root
    spacing: 0
    Layout.fillWidth: true

    // Output Devices: one DDE SettingsGroup — head + option rows with the 1 px
    // seam; the active device carries the accent check (DESIGN §3.5.4).
    ColumnLayout {
        spacing: Style.settingsGroupGap
        Layout.fillWidth: true

        NHeader {
            label: I18n.tr("panels.audio.devices-output-device-label")
            description: I18n.tr("panels.audio.devices-output-device-description")
        }

        Repeater {
            model: AudioService.sinks
            NDccRow {
                required property PwNode modelData
                Layout.fillWidth: true
                clickable: true
                onClicked: AudioService.setAudioSink(modelData)

                NText {
                    text: modelData.description
                    pointSize: Style.fontSizeM
                    Layout.fillWidth: true
                }

                NIcon {
                    icon: "check"
                    pointSize: Style.fontSizeXL
                    color: Color.accent
                    visible: AudioService.sink?.id === modelData.id
                }
            }
        }
    }

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
        Layout.fillWidth: true
    }

    // Input Devices
    ColumnLayout {
        spacing: Style.settingsGroupGap
        Layout.fillWidth: true

        NHeader {
            label: I18n.tr("panels.audio.devices-input-device-label")
            description: I18n.tr("panels.audio.devices-input-device-description")
        }

        Repeater {
            model: AudioService.sources
            NDccRow {
                required property PwNode modelData
                Layout.fillWidth: true
                clickable: true
                onClicked: AudioService.setAudioSource(modelData)

                NText {
                    text: modelData.description
                    pointSize: Style.fontSizeM
                    Layout.fillWidth: true
                }

                NIcon {
                    icon: "check"
                    pointSize: Style.fontSizeXL
                    color: Color.accent
                    visible: AudioService.source?.id === modelData.id
                }
            }
        }
    }
}
