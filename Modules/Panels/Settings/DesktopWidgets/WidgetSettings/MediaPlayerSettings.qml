import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  property bool valueShowBackground: settingsHelper.value("showBackground")
  property string valueVisualizerType: widgetData.visualizerType ? widgetData.visualizerType : widgetMetadata.visualizerType
  property string valueHideMode: settingsHelper.value("hideMode")
  property bool valueShowButtons: settingsHelper.value("showButtons")
  property bool valueShowAlbumArt: settingsHelper.value("showAlbumArt")
  property bool valueShowVisualizer: settingsHelper.value("showVisualizer")
  property bool valueRoundedCorners: settingsHelper.value("roundedCorners")

  function saveSettings() {
    var settings = settingsHelper.save();
    settings.visualizerType = valueVisualizerType;
    settingsChanged(settings);
    return settings;
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.clock-show-background-label")
    description: I18n.tr("panels.desktop-widgets.media-player-show-background-description")
    checked: valueShowBackground
    onToggled: checked => {
                 settingsHelper.set("showBackground", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showBackground
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.clock-rounded-corners-label")
    description: I18n.tr("panels.desktop-widgets.media-player-rounded-corners-description")
    checked: valueRoundedCorners
    onToggled: checked => {
                 settingsHelper.set("roundedCorners", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.roundedCorners
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.media-player-show-album-art-label")
    description: I18n.tr("panels.desktop-widgets.media-player-show-album-art-description")
    checked: valueShowAlbumArt
    onToggled: checked => {
                 settingsHelper.set("showAlbumArt", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showAlbumArt
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.media-mini.show-visualizer-label")
    description: I18n.tr("panels.desktop-widgets.media-player-show-visualizer-description")
    checked: valueShowVisualizer
    onToggled: checked => {
                 settingsHelper.set("showVisualizer", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showVisualizer
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.media-player-show-buttons-label")
    description: I18n.tr("panels.desktop-widgets.media-player-show-buttons-description")
    checked: valueShowButtons
    onToggled: checked => {
                 settingsHelper.set("showButtons", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showButtons
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.audio.visualizer-type-label")
    description: I18n.tr("panels.desktop-widgets.media-player-visualizer-type-description")
    enabled: valueShowVisualizer
    model: [
      {
        "key": "linear",
        "name": I18n.tr("options.visualizer-types.linear")
      },
      {
        "key": "mirrored",
        "name": I18n.tr("options.visualizer-types.mirrored")
      },
      {
        "key": "wave",
        "name": I18n.tr("options.visualizer-types.wave")
      }
    ]
    currentKey: valueVisualizerType
    onSelected: key => {
                  valueVisualizerType = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.visualizerType
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.hide-mode-label")
    description: I18n.tr("bar.media-mini.hide-mode-description")
    model: [
      {
        "key": "hidden",
        "name": I18n.tr("hide-modes.hidden")
      },
      {
        "key": "idle",
        "name": I18n.tr("hide-modes.idle")
      },
      {
        "key": "visible",
        "name": I18n.tr("hide-modes.visible")
      }
    ]
    currentKey: valueHideMode
    onSelected: key => {
                  settingsHelper.set("hideMode", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.hideMode
  }
}
