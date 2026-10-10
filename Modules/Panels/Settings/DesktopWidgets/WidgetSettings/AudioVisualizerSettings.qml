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

  property int valueWidth: settingsHelper.value("width")
  property int valueHeight: settingsHelper.value("height")
  property string valueVisualizerType: settingsHelper.value("visualizerType")
  property string valueColorName: settingsHelper.value("colorName")
  property bool valueHideWhenIdle: settingsHelper.value("hideWhenIdle")
  property bool valueShowBackground: settingsHelper.value("showBackground")
  property bool valueRoundedCorners: settingsHelper.value("roundedCorners")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NTextInput {
    id: widthInput
    Layout.fillWidth: true
    label: I18n.tr("common.width")
    description: I18n.tr("bar.audio-visualizer.width-description")
    text: String(valueWidth)
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    inputMethodHints: Qt.ImhDigitsOnly
    onEditingFinished: {
      const parsed = parseInt(text);
      if (!isNaN(parsed) && parsed > 0) {
        settingsHelper.set("width", parsed);
        saveSettings();
      } else {
        text = String(valueWidth);
      }
    }
    defaultValue: String(widgetMetadata.width)
  }

  NTextInput {
    id: heightInput
    Layout.fillWidth: true
    label: I18n.tr("common.height")
    description: I18n.tr("bar.audio-visualizer.height-description")
    text: String(valueHeight)
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    inputMethodHints: Qt.ImhDigitsOnly
    onEditingFinished: {
      const parsed = parseInt(text);
      if (!isNaN(parsed) && parsed > 0) {
        settingsHelper.set("height", parsed);
        saveSettings();
      } else {
        text = String(valueHeight);
      }
    }
    defaultValue: String(widgetMetadata.height)
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.audio.visualizer-type-label")
    description: I18n.tr("panels.desktop-widgets.media-player-visualizer-type-description")
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
    defaultValue: widgetMetadata.visualizerType
  }

  NColorChoice {
    Layout.fillWidth: true
    label: I18n.tr("bar.audio-visualizer.color-name-label")
    description: I18n.tr("bar.audio-visualizer.color-name-description")
    currentKey: valueColorName
    onSelected: key => {
                  settingsHelper.set("colorName", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.colorName
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.audio-visualizer.hide-when-idle-label")
    description: I18n.tr("bar.audio-visualizer.hide-when-idle-description")
    checked: valueHideWhenIdle
    onToggled: checked => {
                 settingsHelper.set("hideWhenIdle", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideWhenIdle
  }

  NDivider {
    Layout.fillWidth: true
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
    visible: valueShowBackground
    label: I18n.tr("panels.desktop-widgets.clock-rounded-corners-label")
    description: I18n.tr("panels.desktop-widgets.media-player-rounded-corners-description")
    checked: valueRoundedCorners
    onToggled: checked => {
                 settingsHelper.set("roundedCorners", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.roundedCorners
  }
}
