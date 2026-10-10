import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Media
import qs.Services.UI
import qs.Widgets
import qs.Widgets.AudioSpectrum

SmartPanel {
  id: root

  dimsBackground: false

  preferredWidth: Math.round(300 * Style.uiScaleRatio)

  property var mediaMiniSettings: {
    const widget = BarService.lookupWidget("MediaMini", screen?.name);
    return widget ? widget.widgetSettings : null;
  }

  function refreshMediaMiniSettings() {
    const widget = BarService.lookupWidget("MediaMini", screen?.name);
    root.mediaMiniSettings = widget ? widget.widgetSettings : null;
  }

  Connections {
    target: BarService
    function onActiveWidgetsChanged() {
      root.refreshMediaMiniSettings();
    }
  }

  Connections {
    target: Settings
    function onSettingsSaved() {
      root.refreshMediaMiniSettings();
    }
  }

  readonly property string visualizerType: (mediaMiniSettings && mediaMiniSettings.visualizerType !== undefined) ? mediaMiniSettings.visualizerType : "linear"
  readonly property bool showArtistFirst: !!(mediaMiniSettings && mediaMiniSettings.showArtistFirst !== undefined ? mediaMiniSettings.showArtistFirst : true)
  readonly property bool showAlbumArt: !!(mediaMiniSettings && mediaMiniSettings.panelShowAlbumArt !== undefined ? mediaMiniSettings.panelShowAlbumArt : true)
  readonly property bool showVisualizer: !!(mediaMiniSettings && mediaMiniSettings.showVisualizer !== undefined ? mediaMiniSettings.showVisualizer : true)
  readonly property string scrollingMode: (mediaMiniSettings && mediaMiniSettings.scrollingMode !== undefined) ? mediaMiniSettings.scrollingMode : "hover"

  readonly property bool needsSpectrum: root.showVisualizer && root.visualizerType !== "" && root.visualizerType !== "none" && root.isPanelOpen

  onNeedsSpectrumChanged: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("mediaplayerpanel");
    } else {
      SpectrumService.unregisterComponent("mediaplayerpanel");
    }
  }

  Component.onCompleted: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("mediaplayerpanel");
    }
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent("mediaplayerpanel");
  }

  panelContent: Item {
    id: playerContent
    anchors.fill: parent

    property real contentPreferredHeight: Math.min(mainLayout.implicitHeight + Style.margin2M, (root.screen?.height ?? 1080) * 0.7)

    property Component visualizerSource: {
      switch (root.visualizerType) {
      case "linear":
        return linearComponent;
      case "mirrored":
        return mirroredComponent;
      case "wave":
        return waveComponent;
      default:
        return null;
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

        // Player selector (only when more than one player)
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          Layout.topMargin: Style.marginS
          visible: MediaService.getAvailablePlayers().length > 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginXS

            NText {
              Layout.fillWidth: true
              text: MediaService.currentPlayer ? MediaService.currentPlayer.identity : I18n.tr("common.media-player")
              pointSize: Style.fontSizeS
              color: Color.onShellSecondary
              elide: Text.ElideRight
            }

            NIcon {
              icon: "chevron-down"
              pointSize: Style.fontSizeS
              color: Color.onShellSecondary
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: playerContextMenu.open()
          }

          Popup {
            id: playerContextMenu
            x: 0
            y: parent.height
            width: 180
            padding: Style.marginS

            background: Rectangle {
              color: Color.popupShell
              border.color: Color.borderShell
              border.width: Style.borderS
              radius: Style.radiusPopup
            }

            contentItem: ColumnLayout {
              spacing: 0
              Repeater {
                model: MediaService.getAvailablePlayers()
                delegate: Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 30
                  color: itemMouse.containsMouse ? Color.overlay("hover") : "transparent"
                  radius: Style.radiusRow

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginS
                    anchors.rightMargin: Style.marginS
                    spacing: Style.marginS

                    NText {
                      text: modelData.identity
                      pointSize: Style.fontSizeS
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                    }

                    NIcon {
                      visible: MediaService.currentPlayer && MediaService.currentPlayer.identity === modelData.identity
                      icon: "check"
                      color: Color.accent
                      pointSize: Style.fontSizeS
                    }
                  }

                  MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      MediaService.currentPlayer = modelData;
                      playerContextMenu.close();
                    }
                  }
                }
              }
            }
          }
        }

        // Track row: 64 px art + title/artist
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 64
          Layout.topMargin: Style.marginS

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginM

            NImageRounded {
              Layout.preferredWidth: 64
              Layout.preferredHeight: 64
              radius: Style.radiusItem
              imagePath: MediaService.trackArtUrl
              imageFillMode: Image.PreserveAspectCrop
              fallbackIcon: "disc"
              fallbackIconSize: Style.fontSizeXXXL
              borderWidth: 0
              visible: root.showAlbumArt
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXS

              NScrollText {
                Layout.fillWidth: true
                maxWidth: parent.width
                text: {
                  if (root.showArtistFirst) {
                    return MediaService.trackArtist || (MediaService.trackAlbum || "Unknown Artist");
                  } else {
                    return MediaService.trackTitle || "No Media";
                  }
                }
                scrollMode: {
                  if (root.scrollingMode === "always")
                    return NScrollText.ScrollMode.Always;
                  if (root.scrollingMode === "hover")
                    return NScrollText.ScrollMode.Hover;
                  return NScrollText.ScrollMode.Never;
                }
                fadeExtent: 0.01
                delegate: NText {
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.onShell
                  elide: Text.ElideNone
                  wrapMode: Text.NoWrap
                }
              }

              NScrollText {
                Layout.fillWidth: true
                maxWidth: parent.width
                text: {
                  if (root.showArtistFirst) {
                    return MediaService.trackTitle || "No Media";
                  } else {
                    return MediaService.trackArtist || (MediaService.trackAlbum || "Unknown Artist");
                  }
                }
                scrollMode: {
                  if (root.scrollingMode === "always")
                    return NScrollText.ScrollMode.Always;
                  if (root.scrollingMode === "hover")
                    return NScrollText.ScrollMode.Hover;
                  return NScrollText.ScrollMode.Never;
                }
                fadeExtent: 0.01
                delegate: NText {
                  pointSize: Style.fontSizeS
                  color: Color.onShellSecondary
                  elide: Text.ElideNone
                  wrapMode: Text.NoWrap
                }
              }
            }
          }
        }

        // Progress: 2 px groove + time labels
        Item {
          id: progressWrapper
          visible: (MediaService.currentPlayer && MediaService.trackLength > 0)
          Layout.fillWidth: true
          Layout.preferredHeight: progressColumn.implicitHeight + Style.marginS

          property real localSeekRatio: -1
          property real lastSentSeekRatio: -1
          property real seekEpsilon: 0.01
          property real progressRatio: {
            if (!MediaService.currentPlayer || MediaService.trackLength <= 0)
              return 0;
            const r = MediaService.currentPosition / MediaService.trackLength;
            if (isNaN(r) || !isFinite(r))
              return 0;
            return Math.max(0, Math.min(1, r));
          }

          Timer {
            id: seekDebounce
            interval: 75
            repeat: false
            onTriggered: {
              if (MediaService.isSeeking && progressWrapper.localSeekRatio >= 0) {
                const next = Math.max(0, Math.min(1, progressWrapper.localSeekRatio));
                if (progressWrapper.lastSentSeekRatio < 0 || Math.abs(next - progressWrapper.lastSentSeekRatio) >= progressWrapper.seekEpsilon) {
                  MediaService.seekByRatio(next);
                  progressWrapper.lastSentSeekRatio = next;
                }
              }
            }
          }

          ColumnLayout {
            id: progressColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: 2

            NSlider {
              id: progressSlider
              Layout.fillWidth: true
              Layout.preferredHeight: 22
              from: 0
              to: 1
              stepSize: 0
              snapAlways: false
              enabled: MediaService.trackLength > 0 && MediaService.canSeek
              heightRatio: 0.4

              value: (!MediaService.isSeeking) ? progressWrapper.progressRatio : (progressWrapper.localSeekRatio >= 0 ? progressWrapper.localSeekRatio : 0)

              onMoved: {
                progressWrapper.localSeekRatio = value;
                seekDebounce.restart();
              }
              onPressedChanged: {
                if (pressed) {
                  MediaService.isSeeking = true;
                  progressWrapper.localSeekRatio = value;
                  MediaService.seekByRatio(value);
                  progressWrapper.lastSentSeekRatio = value;
                } else {
                  seekDebounce.stop();
                  MediaService.seekByRatio(value);
                  MediaService.isSeeking = false;
                  progressWrapper.localSeekRatio = -1;
                  progressWrapper.lastSentSeekRatio = -1;
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 0

              NText {
                text: MediaService.positionString || "0:00"
                pointSize: Style.fontSizeXS
                color: Color.onShellSecondary
              }

              Item {
                Layout.fillWidth: true
              }

              NText {
                text: MediaService.lengthString || "0:00"
                pointSize: Style.fontSizeXS
                color: Color.onShellSecondary
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }

        // Controls row: flat icon buttons
        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          spacing: Style.marginL

          NIconButton {
            icon: "media-prev"
            colorFg: Color.onShell
            onClicked: MediaService.previous()
          }

          NIconButton {
            icon: MediaService.isPlaying ? "media-pause" : "media-play"
            colorFg: Color.onShell
            baseSize: Style.baseWidgetSize
            onClicked: MediaService.playPause()
          }

          NIconButton {
            icon: "media-next"
            colorFg: Color.onShell
            onClicked: MediaService.next()
          }
        }

        // Optional visualizer strip
        Loader {
          Layout.fillWidth: true
          Layout.preferredHeight: 24
          active: !!root.needsSpectrum
          sourceComponent: playerContent.visualizerSource
        }

        Item {
          Layout.preferredHeight: Style.marginS
        }
      }
    }
  }

  // Visualizer Components
  Component {
    id: linearComponent
    NLinearSpectrum {
      width: parent.width - Style.marginS
      height: 20
      values: SpectrumService.values
      fillColor: Color.accent
      opacity: 0.4
      barPosition: Settings.getBarPositionForScreen(root.screen?.name)
    }
  }

  Component {
    id: mirroredComponent
    NMirroredSpectrum {
      width: parent.width - Style.marginS
      height: 20
      values: SpectrumService.values
      fillColor: Color.accent
      opacity: 0.4
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: waveComponent
    NWaveSpectrum {
      width: parent.width - Style.marginS
      height: 20
      values: SpectrumService.values
      fillColor: Color.accent
      opacity: 0.4
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }
}
