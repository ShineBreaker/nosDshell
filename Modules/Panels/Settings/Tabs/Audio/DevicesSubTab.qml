import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
            // Model is index keys, not the entries: boxing the JS-array model
            // turns the PwNode refs into raw pointers (CODING_STANDARDS
            // "QML 规则"). The delegate resolves the live JS entry itself.
            model: AudioService.sinks.map((_, i) => i)
            NDccRow {
                readonly property var entry: AudioService.sinks[index]
                Layout.fillWidth: true
                clickable: true
                onClicked: {
                    if (entry)
                        AudioService.setAudioSink(entry);
                }

                NText {
                    text: entry?.description || ""
                    pointSize: Style.fontSizeM
                    Layout.fillWidth: true
                }

                NIcon {
                    icon: "check"
                    pointSize: Style.fontSizeXL
                    color: Colors.accent
                    visible: entry ? AudioService.sink?.id === entry.id : false
                }
            }
        }

        NText {
            visible: AudioService.sinks.length === 0
            text: I18n.tr("panels.audio.devices-none")
            color: Colors.onShellTertiary
            Layout.fillWidth: true
            Layout.leftMargin: Style.settingsRowPaddingH
            Layout.rightMargin: Style.settingsRowPaddingH
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
            // Index-key model — see the comment on the sinks Repeater above
            // (CODING_STANDARDS "QML 规则").
            model: AudioService.sources.map((_, i) => i)
            NDccRow {
                readonly property var entry: AudioService.sources[index]
                Layout.fillWidth: true
                clickable: true
                onClicked: {
                    if (entry)
                        AudioService.setAudioSource(entry);
                }

                NText {
                    text: entry?.description || ""
                    pointSize: Style.fontSizeM
                    Layout.fillWidth: true
                }

                NIcon {
                    icon: "check"
                    pointSize: Style.fontSizeXL
                    color: Colors.accent
                    visible: entry ? AudioService.source?.id === entry.id : false
                }
            }
        }

        NText {
            visible: AudioService.sources.length === 0
            text: I18n.tr("panels.audio.devices-none")
            color: Colors.onShellTertiary
            Layout.fillWidth: true
            Layout.leftMargin: Style.settingsRowPaddingH
            Layout.rightMargin: Style.settingsRowPaddingH
        }
    }
}
