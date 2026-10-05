import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Hardware
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(300 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    property real localOutputVolume: AudioService.volume
    property bool localOutputMuted: AudioService.muted
    property real localInputVolume: AudioService.inputVolume
    property bool localInputMuted: AudioService.inputMuted
    property real stepSize: Settings.data.audio.volumeStep / 100.0

    property real contentPreferredHeight: Math.min(mainLayout.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    // The service stays the source of truth: default device changes and
    // external volume changes are reflected here (the local properties would
    // otherwise go stale).
    Connections {
      target: AudioService
      function onSinkChanged() {
        panelContent.syncFromService();
      }
      function onSourceChanged() {
        panelContent.syncFromService();
      }
      function onVolumeChanged() {
        panelContent.localOutputVolume = AudioService.volume;
      }
      function onInputVolumeChanged() {
        panelContent.localInputVolume = AudioService.inputVolume;
      }
      function onMutedChanged() {
        panelContent.localOutputMuted = AudioService.muted;
      }
      function onInputMutedChanged() {
        panelContent.localInputMuted = AudioService.inputMuted;
      }
    }

    Component.onCompleted: {
      syncFromService();
    }

    function syncFromService() {
      panelContent.localOutputVolume = AudioService.volume;
      panelContent.localInputVolume = AudioService.inputVolume;
      panelContent.localOutputMuted = AudioService.muted;
      panelContent.localInputMuted = AudioService.inputMuted;
    }

    readonly property string outputIcon: {
      if (localOutputMuted || localOutputVolume <= Number.EPSILON) {
        return "volume-off";
      }
      return localOutputVolume <= 0.5 ? "volume-2" : "volume";
    }

    readonly property string inputIcon: {
      if (localInputMuted || localInputVolume <= Number.EPSILON) {
        return "microphone-off";
      }
      return localInputVolume <= 0.5 ? "microphone-2" : "microphone";
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

        // ---- Output ----
        NPanelSection {
          text: I18n.tr("panels.audio.section-output")
          Layout.fillWidth: true
          Layout.topMargin: Style.marginM
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginS
            spacing: Style.marginXS
            NText {
              Layout.fillWidth: true
              text: AudioService.sink?.description || I18n.tr("panels.audio.fallback-output-device-name")
              pointSize: Style.fontSizeM
              elide: Text.ElideRight
            }
            NIconButton {
              icon: panelContent.outputIcon
              colorFg: Color.onShell
              tooltipText: I18n.tr("tooltips.mute-output")
              onClicked: AudioService.setOutputMuted(!panelContent.localOutputMuted)
            }
          }
        }

        NValueSlider {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          Layout.preferredHeight: 22
          from: 0
          to: Settings.data.audio.volumeOverdrive ? 1.5 : 1
          stepSize: panelContent.stepSize
          value: panelContent.localOutputVolume
          enabled: AudioService.sink !== null
          onPressedChanged: playVolumeSound()
          onMoved: {
            if (!panelContent.localOutputMuted) {
              AudioService.setVolume(value);
            }
          }
          text: Math.round(panelContent.localOutputVolume * 100) + "%"
        }

        // ---- Input ----
        NPanelSection {
          text: I18n.tr("panels.audio.section-input")
          Layout.fillWidth: true
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginS
            spacing: Style.marginXS
            NText {
              Layout.fillWidth: true
              text: AudioService.source?.description || I18n.tr("panels.audio.fallback-input-device-name")
              pointSize: Style.fontSizeM
              elide: Text.ElideRight
            }
            NIconButton {
              icon: panelContent.inputIcon
              colorFg: Color.onShell
              tooltipText: I18n.tr("tooltips.mute-input")
              onClicked: AudioService.setInputMuted(!panelContent.localInputMuted)
            }
          }
        }

        NValueSlider {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          Layout.preferredHeight: 22
          from: 0
          to: 1
          stepSize: panelContent.stepSize
          value: panelContent.localInputVolume
          enabled: AudioService.source !== null
          onMoved: {
            if (!panelContent.localInputMuted) {
              AudioService.setInputVolume(value);
            }
          }
          text: Math.round(panelContent.localInputVolume * 100) + "%"
        }

        // ---- Applications ----
        NPanelSection {
          text: I18n.tr("panels.audio.section-applications")
          Layout.fillWidth: true
          visible: AudioService.appStreams.length > 0
        }

        Repeater {
          model: AudioService.appStreams
          delegate: ColumnLayout {
            id: appBox
            Layout.fillWidth: true
            spacing: 0

            // Track individual node to ensure properties are bound
            PwObjectTracker {
              objects: modelData ? [modelData] : []
            }

            property PwNodeAudio nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
            property real appVolume: (nodeAudio && nodeAudio.volume !== undefined) ? nodeAudio.volume : 0.0
            property bool appMuted: (nodeAudio && nodeAudio.muted !== undefined) ? nodeAudio.muted : false

            readonly property bool isCaptureStream: {
              if (!modelData || !modelData.properties)
                return false;
              const props = modelData.properties;
              if (props["stream.capture.sink"] !== undefined)
                return true;
              const mediaClass = props["media.class"] || "";
              return mediaClass.includes("Capture") || mediaClass === "Stream/Input" || mediaClass === "Stream/Input/Audio";
            }

            visible: !isCaptureStream

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 36
              visible: !appBox.isCaptureStream
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginS
                spacing: Style.marginS

                IconImage {
                  implicitSize: Style.baseWidgetSize * 0.6
                  source: {
                    let icon = modelData.properties["application.icon-name"];
                    return ThemeIcons.iconFromName(icon, "audio-x-generic");
                  }
                }

                NText {
                  Layout.fillWidth: true
                  text: {
                    let appName = modelData.properties["application.name"] || "";
                    if (modelData.isFirefox) {
                      appName = modelData.properties["media.name"] || appName;
                    }
                    return appName || modelData.name;
                  }
                  pointSize: Style.fontSizeM
                  elide: Text.ElideRight
                }

                NIconButton {
                  icon: appBox.appMuted ? "volume-off" : "volume-2"
                  colorFg: Color.onShell
                  enabled: !!(appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true)
                  tooltipText: appBox.appMuted ? I18n.tr("tooltips.unmute-stream") : I18n.tr("tooltips.mute-stream")
                  onClicked: {
                    if (appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true) {
                      var newMuted = !appBox.appMuted;
                      appBox.nodeAudio.muted = newMuted;
                      AudioService.setPanelAppStreamMuted(appBox.modelData, newMuted);
                    }
                  }
                }
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginM
              Layout.rightMargin: Style.marginM
              Layout.preferredHeight: 22
              visible: !appBox.isCaptureStream
              enabled: !!(appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true)
              from: 0
              to: 1
              value: appBox.appVolume
              stepSize: panelContent.stepSize
              onMoved: {
                if (appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true) {
                  appBox.nodeAudio.volume = value;
                  AudioService.setPanelAppStreamVolume(appBox.modelData, value);
                }
              }
              text: Math.round(appBox.appVolume * 100) + "%"
            }
          }
        }

        // ---- Devices ----
        NPanelSection {
          text: I18n.tr("panels.audio.section-devices")
          Layout.fillWidth: true
        }

        Repeater {
          model: AudioService.sinks
          delegate: NRadioButton {
            Layout.fillWidth: true
            implicitHeight: 36
            contentHorizontalPadding: Style.marginM
            checked: modelData.id === AudioService.sink?.id
            text: modelData.description || modelData.name
            pointSize: Style.fontSizeS
            ButtonGroup.group: sinksRadioGroup
            onClicked: AudioService.setAudioSink(modelData)
          }
        }

        NText {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginM
          Layout.topMargin: Style.marginXS
          text: I18n.tr("panels.audio.section-input")
          pointSize: Style.fontSizeS
          color: Color.onShellTertiary
          visible: AudioService.sources.length > 0
        }

        Repeater {
          model: AudioService.sources
          delegate: NRadioButton {
            Layout.fillWidth: true
            implicitHeight: 36
            contentHorizontalPadding: Style.marginM
            checked: modelData.id === AudioService.source?.id
            text: modelData.description || modelData.name
            pointSize: Style.fontSizeS
            ButtonGroup.group: sourcesRadioGroup
            onClicked: AudioService.setAudioSource(modelData)
          }
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }

    ButtonGroup {
      id: sourcesRadioGroup
      exclusive: true
    }

    ButtonGroup {
      id: sinksRadioGroup
      exclusive: true
    }

    function playVolumeSound() {
      if (Settings.data.audio.volumeFeedback) {
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga", "--volume", "0.5"]);
      }
    }
  }
}
