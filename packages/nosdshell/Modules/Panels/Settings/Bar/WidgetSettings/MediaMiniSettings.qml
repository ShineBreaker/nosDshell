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
    settingsChanged(settings);
    return settings;
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.hide-mode-label")
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
    checked: valueShowAlbumArt
    onToggled: checked => {
      settingsHelper.set("showAlbumArt", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showAlbumArt
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-artist-first-label")
    checked: valueShowArtistFirst
    onToggled: checked => {
      settingsHelper.set("showArtistFirst", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.showArtistFirst
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-visualizer-label")
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
    minimumWidth: Style.settingsPopupFieldWidth
    defaultValue: widgetMetadata.visualizerType
  }

  WidgetNumberInput {
    id: widthInput
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.max-width-label")
    placeholderText: widgetMetadata.maxWidth
    text: String(valueMaxWidth)
    storedValue: valueMaxWidth
    minimum: 1
    maximum: 2000
    onCommitted: value => {
      settingsHelper.set("maxWidth", value);
      saveSettings();
    }
    defaultValue: String(widgetMetadata.maxWidth)
  }

  NToggle {
    label: I18n.tr("bar.media-mini.use-fixed-width-label")
    checked: valueUseFixedWidth
    onToggled: checked => {
      settingsHelper.set("useFixedWidth", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.useFixedWidth
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-progress-ring-label")
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
    minimumWidth: Style.settingsPopupFieldWidth
    defaultValue: widgetMetadata.scrollingMode
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
  }

  NLabel {
    label: I18n.tr("bar.media-mini.panel-section-label")
    labelColor: Colors.accent
  }

  NToggle {
    label: I18n.tr("bar.media-mini.show-album-art-label")
    checked: valuePanelShowAlbumArt
    onToggled: checked => {
      settingsHelper.set("panelShowAlbumArt", checked);
      saveSettings();
    }
    defaultValue: widgetMetadata.panelShowAlbumArt
  }
}
