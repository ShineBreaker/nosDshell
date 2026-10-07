import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  Layout.preferredWidth: Math.round(600 * Style.uiScaleRatio)
  implicitWidth: Layout.preferredWidth

  property var widgetData: null
  property var widgetMetadata: null
  property var rootSettings: null

  signal settingsChanged(var settings)

  QtObject {
    id: _settings

    property string icon: widgetData.icon !== undefined ? widgetData.icon : widgetMetadata.icon
    property string onClicked: widgetData.onClicked !== undefined ? widgetData.onClicked : widgetMetadata.onClicked
    property string onRightClicked: widgetData.onRightClicked !== undefined ? widgetData.onRightClicked : widgetMetadata.onRightClicked
    property string onMiddleClicked: widgetData.onMiddleClicked !== undefined ? widgetData.onMiddleClicked : widgetMetadata.onMiddleClicked
    property ListModel _stateChecksListModel: ListModel {}
    property string stateChecksJson: "[]"
    property string generalTooltipText: widgetData.generalTooltipText !== undefined ? widgetData.generalTooltipText : widgetMetadata.generalTooltipText
    property bool enableOnStateLogic: widgetData.enableOnStateLogic !== undefined ? widgetData.enableOnStateLogic : widgetMetadata.enableOnStateLogic
    property bool showExecTooltip: widgetData.showExecTooltip !== undefined ? widgetData.showExecTooltip : widgetMetadata.showExecTooltip

    function populateStateChecks() {
      try {
        var initialChecks = JSON.parse(stateChecksJson);
        if (initialChecks && Array.isArray(initialChecks)) {
          for (var i = 0; i < initialChecks.length; i++) {
            var item = initialChecks[i];
            if (item && typeof item === "object") {
              _settings._stateChecksListModel.append({
                                                       "command": item.command || "",
                                                       "icon": item.icon || ""
                                                     });
            } else {
              Logger.w("CustomButtonSettings", "Invalid stateChecks entry at index " + i + ":", item);
            }
          }
        }
      } catch (e) {
        Logger.e("CustomButtonSettings", "Failed to parse stateChecksJson:", e.message);
      }
    }

    Component.onCompleted: {
      root.rootSettings = _settings;
      stateChecksJson = (widgetData && widgetData.stateChecksJson !== undefined) ? widgetData.stateChecksJson : (widgetMetadata && widgetMetadata.stateChecksJson ? widgetMetadata.stateChecksJson : "[]");
      Qt.callLater(populateStateChecks);
    }

    function saveSettings() {
      var savedStateChecksArray = [];
      for (var i = 0; i < _settings._stateChecksListModel.count; i++) {
        savedStateChecksArray.push(_settings._stateChecksListModel.get(i));
      }
      _settings.stateChecksJson = JSON.stringify(savedStateChecksArray);

      return {
        "id": widgetData.id,
        "icon": _settings.icon,
        "onClicked": _settings.onClicked,
        "onRightClicked": _settings.onRightClicked,
        "onMiddleClicked": _settings.onMiddleClicked,
        "stateChecksJson": _settings.stateChecksJson,
        "generalTooltipText": _settings.generalTooltipText,
        "enableOnStateLogic": _settings.enableOnStateLogic,
        "showExecTooltip": _settings.showExecTooltip
      };
    }
  }

  function saveSettings() {
    var settings = _settings.saveSettings();
    settingsChanged(settings);
    return settings;
  }

  function updateStateCheck(index, command, icon) {
    _settings._stateChecksListModel.set(index, {
                                          "command": command,
                                          "icon": icon
                                        });
    saveSettings();
  }

  function removeStateCheck(index) {
    _settings._stateChecksListModel.remove(index);
    saveSettings();
  }

  function addStateCheck() {
    _settings._stateChecksListModel.append({
                                             "command": "",
                                             "icon": ""
                                           });
    saveSettings();
  }

  RowLayout {
    spacing: Style.marginM

    NLabel {
      label: I18n.tr("common.icon")
      description: I18n.tr("panels.control-center.shortcuts-custom-button-icon-description")
    }

    NIcon {
      Layout.alignment: Qt.AlignVCenter
      icon: _settings.icon || (widgetMetadata && widgetMetadata.icon ? widgetMetadata.icon : "")
      pointSize: Style.fontSizeXL
      visible: (_settings.icon || (widgetMetadata && widgetMetadata.icon ? widgetMetadata.icon : "")) !== ""
    }

    NButton {
      text: I18n.tr("common.browse")
      onClicked: iconPicker.open()
    }
  }

  NIconPicker {
    id: iconPicker
    initialIcon: _settings.icon
    onIconSelected: function (iconName) {
      _settings.icon = iconName;
      saveSettings();
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: I18n.tr("bar.custom-button.general-tooltip-text-label")
    description: I18n.tr("bar.custom-button.general-tooltip-text-description")
    placeholderText: I18n.tr("placeholders.enter-tooltip")
    text: _settings.generalTooltipText
    onTextChanged: {
      _settings.generalTooltipText = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.generalTooltipText
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.custom-button.show-exec-tooltip-label")
    description: I18n.tr("bar.custom-button.show-exec-tooltip-description")
    checked: _settings.showExecTooltip
    onToggled: checked => {
                 _settings.showExecTooltip = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showExecTooltip
  }

  NTextInput {
    Layout.fillWidth: true
    label: I18n.tr("bar.custom-button.left-click-label")
    description: I18n.tr("bar.custom-button.left-click-description")
    placeholderText: I18n.tr("placeholders.enter-command")
    text: _settings.onClicked
    onTextChanged: {
      _settings.onClicked = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.onClicked
  }

  NTextInput {
    Layout.fillWidth: true
    label: I18n.tr("bar.custom-button.right-click-label")
    description: I18n.tr("bar.custom-button.right-click-description")
    placeholderText: I18n.tr("placeholders.enter-command")
    text: _settings.onRightClicked
    onTextChanged: {
      _settings.onRightClicked = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.onRightClicked
  }

  NTextInput {
    Layout.fillWidth: true
    label: I18n.tr("bar.custom-button.middle-click-label")
    description: I18n.tr("bar.custom-button.middle-click-description")
    placeholderText: I18n.tr("placeholders.enter-command")
    text: _settings.onMiddleClicked
    onTextChanged: {
      _settings.onMiddleClicked = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.onMiddleClicked
  }

  NDivider {}

  NToggle {
    id: enableOnStateLogicToggle
    Layout.fillWidth: true
    label: I18n.tr("panels.control-center.shortcuts-custom-button-enable-on-state-logic-label")
    description: I18n.tr("panels.control-center.shortcuts-custom-button-enable-on-state-logic-description")
    checked: _settings.enableOnStateLogic
    onToggled: checked => {
                 _settings.enableOnStateLogic = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.enableOnStateLogic
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.rootSettings && root.rootSettings.enableOnStateLogic
    spacing: Style.marginM

    NLabel {
      label: I18n.tr("panels.control-center.shortcuts-custom-button-state-checks-label")
    }

    Repeater {
      model: root.rootSettings ? root.rootSettings._stateChecksListModel : null
      delegate: Item {
        property int currentIndex: index

        implicitHeight: contentRow.implicitHeight
        Layout.fillWidth: true

        RowLayout {
          id: contentRow
          anchors.fill: parent
          spacing: Style.marginM

          NTextInput {
            Layout.fillWidth: true
            placeholderText: I18n.tr("panels.control-center.shortcuts-custom-button-state-checks-command")
            text: model.command
            onTextChanged: {
              updateStateCheck(currentIndex, text, model.icon);
            }
          }

          RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.marginS

            NIcon {
              icon: model.icon
              pointSize: Style.fontSizeL
              visible: model.icon !== undefined && model.icon !== ""
            }

            NIconButton {
              icon: "folder"
              tooltipText: I18n.tr("common.browse")
              baseSize: Style.baseWidgetSize * 0.75
              onClicked: iconPickerDelegate.open()
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("panels.control-center.shortcuts-custom-button-state-checks-remove")
              baseSize: Style.baseWidgetSize * 0.75
              colorBorder: Qt.alpha(Color.mOutline, Style.opacityLight)
              colorBg: Color.mError
              colorFg: Color.mOnError
              colorBgHover: Qt.alpha(Color.mError, Style.opacityMedium)
              colorFgHover: Color.mOnError
              onClicked: {
                removeStateCheck(currentIndex);
              }
            }
          }
        }

        NIconPicker {
          id: iconPickerDelegate
          initialIcon: model.icon
          onIconSelected: function (iconName) {
            updateStateCheck(currentIndex, model.command, iconName);
          }
        }
      }
    }

    Item {
      Layout.fillWidth: true
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        text: I18n.tr("panels.control-center.shortcuts-custom-button-state-checks-add")
        onClicked: addStateCheck()
      }
    }
  }
}
