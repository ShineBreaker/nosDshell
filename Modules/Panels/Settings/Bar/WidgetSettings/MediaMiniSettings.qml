import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  // Local state
  property string valueHideMode: settingsHelper.value("hideMode")
  // Deprecated: hideWhenIdle now folded into hideMode = "idle"
  property bool valueHideWhenIdle: settingsHelper.value("hideWhenIdle")
  property bool valueShowAlbumArt: settingsHelper.value("showAlbumArt")
  property bool valuePanelShowAlbumArt: settingsHelper.value("panelShowAlbumArt")
  property bool valueShowArtistFirst: settingsHelper.value("showArtistFirst")
  property bool valueShowVisualizer: settingsHelper.value("showVisualizer")
  property string valueVisualizerType: settingsHelper.value("visualizerType")
  property string valueScrollingMode: settingsHelper.value("scrollingMode")
  property int valueMaxWidth: settingsHelper.value("maxWidth")
  property bool valueUseFixedWidth: settingsHelper.value("useFixedWidth")
  property bool valueShowProgressRing: settingsHelper.value("showProgressRing")
  property string valueTextColor: settingsHelper.value("textColor")

  function saveSettings() {
    var settings = settingsHelper.save();
    // No longer store hideWhenIdle separately; kept for backward compatibility only
    settings.maxWidth = parseInt(widthInput.text) || widgetMetadata.maxWidth;
    settingsChanged(settings);
    return settings;
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.hide-mode-label")
    description: I18n.tr("bar.media-mini.hide-mode-description")
    model: [
      {
        "key": "visible",
        "name": I18n.tr("hide-modes.visible")
      },
      {
        "key": "hidden",
        "name": I18n.tr("hide-modes.hidden")
      },
      {
        "key": "transparent",
        "name": I18n.tr("hide-modes.transparent")
      },
      {
        "key": "idle",
        "name": I18n.tr("hide-modes.idle")
      }
    ]
    currentKey: root.valueHideMode
    onSelected: key => {
                  settingsHelper.set("hideMode", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.hideMode
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-album-art-label")
    description: I18n.tr("bar.media-mini.show-album-art-description")
    checked: valueShowAlbumArt
    onToggled: checked => {
                 settingsHelper.set("showAlbumArt", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showAlbumArt
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-artist-first-label")
    description: I18n.tr("bar.media-mini.show-artist-first-description")
    checked: valueShowArtistFirst
    onToggled: checked => {
                 settingsHelper.set("showArtistFirst", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showArtistFirst
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-visualizer-label")
    description: I18n.tr("bar.media-mini.show-visualizer-description")
    checked: valueShowVisualizer
    onToggled: checked => {
                 settingsHelper.set("showVisualizer", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showVisualizer
  }

  NComboBox {
    visible: valueShowVisualizer
    label: I18n.tr("bar.media-mini.visualizer-type-label")
    description: I18n.tr("bar.media-mini.visualizer-type-description")
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
                  settingsHelper.set("visualizerType", key);
                  saveSettings();
                }
    minimumWidth: 200
    defaultValue: widgetMetadata.visualizerType
  }

  NTextInput {
    id: widthInput
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.max-width-label")
    description: I18n.tr("bar.media-mini.max-width-description")
    placeholderText: widgetMetadata.maxWidth
    text: valueMaxWidth
    onTextChanged: saveSettings()
    defaultValue: String(widgetMetadata.maxWidth)
  }

  NToggle {
    label: I18n.tr("bar.media-mini.use-fixed-width-label")
    description: I18n.tr("bar.media-mini.use-fixed-width-description")
    checked: valueUseFixedWidth
    onToggled: checked => {
                 settingsHelper.set("useFixedWidth", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.useFixedWidth
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-progress-ring-label")
    description: I18n.tr("bar.media-mini.show-progress-ring-description")
    checked: valueShowProgressRing
    onToggled: checked => {
                 settingsHelper.set("showProgressRing", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showProgressRing
  }

  NColorChoice {
    label: I18n.tr("common.select-text-color")
    currentKey: valueTextColor
    onSelected: key => {
                  settingsHelper.set("textColor", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.textColor
  }

  NComboBox {
    label: I18n.tr("bar.media-mini.scrolling-mode-label")
    description: I18n.tr("bar.media-mini.scrolling-mode-description")
    model: [
      {
        "key": "always",
        "name": I18n.tr("options.scrolling-modes.always")
      },
      {
        "key": "hover",
        "name": I18n.tr("options.scrolling-modes.hover")
      },
      {
        "key": "never",
        "name": I18n.tr("options.scrolling-modes.never")
      }
    ]
    currentKey: valueScrollingMode
    onSelected: key => {
                  settingsHelper.set("scrollingMode", key);
                  saveSettings();
                }
    minimumWidth: 200
    defaultValue: widgetMetadata.scrollingMode
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
  }

  NLabel {
    label: I18n.tr("bar.media-mini.panel-section-label")
    description: I18n.tr("bar.media-mini.panel-section-description")
    labelColor: Color.accent
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-album-art-label")
    description: I18n.tr("bar.media-mini.show-album-art-description")
    checked: valuePanelShowAlbumArt
    onToggled: checked => {
                 settingsHelper.set("panelShowAlbumArt", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.panelShowAlbumArt
  }
}
