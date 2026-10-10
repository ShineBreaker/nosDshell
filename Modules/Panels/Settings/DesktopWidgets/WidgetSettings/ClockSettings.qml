import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  width: 700

  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  WidgetSettingsHelper {
    id: settingsHelper
    widgetData: root.widgetData
    widgetMetadata: root.widgetMetadata
  }

  property bool valueShowBackground: settingsHelper.value("showBackground")
  property bool valueRoundedCorners: settingsHelper.value("roundedCorners")
  property string valueClockStyle: settingsHelper.value("clockStyle")
  property string valueClockColor: settingsHelper.value("clockColor")
  property bool valueUseCustomFont: settingsHelper.value("useCustomFont")
  property string valueCustomFont: settingsHelper.value("customFont")
  property string valueFormat: settingsHelper.value("format")

  // Track the currently focused input field
  property var focusedInput: null

  readonly property bool isMinimalMode: valueClockStyle === "minimal"
  readonly property var now: Time.now

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  // Function to insert token at cursor position in the focused input
  function insertToken(token) {
    if (!focusedInput || !focusedInput.inputItem) {
      // If no input is focused, default to format input
      if (formatInput.inputItem) {
        formatInput.inputItem.focus = true;
        focusedInput = formatInput;
      }
    }

    if (focusedInput && focusedInput.inputItem) {
      var input = focusedInput.inputItem;
      var cursorPos = input.cursorPosition;
      var currentText = input.text;

      // Insert token at cursor position
      var newText = currentText.substring(0, cursorPos) + token + currentText.substring(cursorPos);
      input.text = newText + " ";

      // Move cursor after the inserted token
      input.cursorPosition = cursorPos + token.length + 1;

      // Ensure the input keeps focus
      input.focus = true;
      saveSettings();
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.clock-style-label")
    description: I18n.tr("panels.desktop-widgets.clock-style-description")
    currentKey: valueClockStyle
    minimumWidth: 260 * Style.uiScaleRatio
    model: [
      {
        "key": "minimal",
        "name": I18n.tr("panels.desktop-widgets.clock-style-minimal")
      },
      {
        "key": "digital",
        "name": I18n.tr("panels.desktop-widgets.clock-style-digital")
      },
      {
        "key": "analog",
        "name": I18n.tr("panels.desktop-widgets.clock-style-analog")
      },
      {
        "key": "binary",
        "name": I18n.tr("panels.desktop-widgets.clock-style-binary")
      }
    ]
    onSelected: key => {
                  settingsHelper.set("clockStyle", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.clockStyle
  }

  NColorChoice {
    label: I18n.tr("common.select-color")
    description: I18n.tr("common.select-color-description")
    currentKey: valueClockColor
    onSelected: key => {
                  settingsHelper.set("clockColor", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.clockColor
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.clock.use-custom-font-label")
    description: I18n.tr("bar.clock.use-custom-font-description")
    checked: valueUseCustomFont
    onToggled: checked => {
                 settingsHelper.set("useCustomFont", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.useCustomFont
  }

  NSearchableComboBox {
    Layout.fillWidth: true
    visible: valueUseCustomFont
    label: I18n.tr("bar.clock.custom-font-label")
    description: I18n.tr("bar.clock.custom-font-description")
    model: FontService.availableFonts
    currentKey: valueCustomFont
    placeholder: I18n.tr("bar.clock.custom-font-placeholder")
    searchPlaceholder: I18n.tr("bar.clock.custom-font-search-placeholder")
    popupHeight: 420
    minimumWidth: 300
    onSelected: function (key) {
      settingsHelper.set("customFont", key);
      saveSettings();
    }
    enabled: valueClockStyle === "minimal"
    defaultValue: Settings.data.ui.fontDefault
  }

  NDivider {
    Layout.fillWidth: true
    visible: isMinimalMode
  }

  NHeader {
    visible: isMinimalMode
    label: I18n.tr("bar.clock.clock-display-label")
    description: I18n.tr("bar.clock.clock-display-description")
  }

  // Format editor - only visible in minimal mode
  RowLayout {
    id: main
    visible: isMinimalMode
    spacing: Style.marginL
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

    ColumnLayout {
      spacing: Style.marginM
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

      NTextInput {
        id: formatInput
        Layout.fillWidth: true
        label: I18n.tr("panels.desktop-widgets.clock-format-label")
        description: I18n.tr("bar.clock.horizontal-bar-description")
        placeholderText: "HH:mm\\nd MMMM yyyy"
        text: valueFormat
        onTextChanged: {
          settingsHelper.set("format", text);
          settingsChanged(saveSettings());
        }
        Component.onCompleted: {
          if (inputItem) {
            inputItem.onActiveFocusChanged.connect(function () {
              if (inputItem.activeFocus) {
                root.focusedInput = formatInput;
              }
            });
          }
        }
        defaultValue: widgetMetadata.format
      }
    }

    // Preview
    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
      Layout.fillWidth: false

      NLabel {
        label: I18n.tr("bar.clock.preview")
        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
      }

      Rectangle {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 160
        color: Color.overlay("field")
        radius: Style.radiusItem
        border.color: Color.accent
        border.width: Style.borderS

        Behavior on border.color {
          ColorAnimation {
            duration: Style.animationFast
          }
        }

        ColumnLayout {
          spacing: Style.marginM
          anchors.centerIn: parent

          ColumnLayout {
            spacing: -2
            Layout.alignment: Qt.AlignHCenter

            Repeater {
              Layout.topMargin: Style.marginM
              model: I18n.locale.toString(now, valueFormat.trim()).split("\\n")
              delegate: NText {
                visible: text !== ""
                text: modelData
                family: valueUseCustomFont && valueCustomFont ? valueCustomFont : Settings.data.ui.fontDefault
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                color: Color.resolveColorKey(valueClockColor)
                wrapMode: Text.WordWrap
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  NDivider {
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
    visible: isMinimalMode
  }

  NDateTimeTokens {
    Layout.fillWidth: true
    height: 200
    visible: isMinimalMode
    onTokenClicked: token => root.insertToken(token)
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.desktop-widgets.clock-show-background-label")
    description: I18n.tr("panels.desktop-widgets.clock-show-background-description")
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
    description: I18n.tr("panels.desktop-widgets.clock-rounded-corners-description")
    checked: valueRoundedCorners
    onToggled: checked => {
                 settingsHelper.set("roundedCorners", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.roundedCorners
  }
}
