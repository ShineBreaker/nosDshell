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

  property string valueLabelMode: settingsHelper.value("labelMode")
  property bool valueHideUnoccupied: settingsHelper.value("hideUnoccupied")
  property bool valueFollowFocusedScreen: settingsHelper.value("followFocusedScreen")
  property int valueCharacterCount: settingsHelper.value("characterCount")

  // Grouped mode settings
  property bool valueShowApplications: settingsHelper.value("showApplications")
  property bool valueShowApplicationsHover: settingsHelper.value("showApplicationsHover")
  property bool valueShowLabelsOnlyWhenOccupied: settingsHelper.value("showLabelsOnlyWhenOccupied")
  property bool valueColorizeIcons: settingsHelper.value("colorizeIcons")
  property real valueUnfocusedIconsOpacity: settingsHelper.value("unfocusedIconsOpacity")
  property real valueGroupedBorderOpacity: settingsHelper.value("groupedBorderOpacity")
  property bool valueEnableScrollWheel: settingsHelper.value("enableScrollWheel")
  property real valueIconScale: settingsHelper.value("iconScale")
  property string valueFocusedColor: settingsHelper.value("focusedColor")
  property string valueOccupiedColor: settingsHelper.value("occupiedColor")
  property string valueEmptyColor: settingsHelper.value("emptyColor")
  property bool valueShowBadge: settingsHelper.value("showBadge")
  property real valuePillSize: settingsHelper.value("pillSize")
  property string valueFontWeight: settingsHelper.value("fontWeight")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NComboBox {
    id: labelModeCombo
    label: I18n.tr("bar.workspace.label-mode-label")
    description: I18n.tr("bar.workspace.label-mode-description")
    model: [
      {
        "key": "none",
        "name": I18n.tr("common.none")
      },
      {
        "key": "index",
        "name": I18n.tr("options.workspace-labels.index")
      },
      {
        "key": "name",
        "name": I18n.tr("options.workspace-labels.name")
      },
      {
        "key": "index+name",
        "name": I18n.tr("options.workspace-labels.index-and-name")
      }
    ]
    currentKey: settingsHelper.value("labelMode")
    onSelected: key => {
                  settingsHelper.set("labelMode", key);
                  saveSettings();
                }
    minimumWidth: 200
  }

  NSpinBox {
    label: I18n.tr("bar.workspace.character-count-label")
    description: I18n.tr("bar.workspace.character-count-description")
    from: 1
    to: 10
    value: valueCharacterCount
    onValueChanged: {
      settingsHelper.set("characterCount", value);
      saveSettings();
    }
    visible: valueLabelMode === "name"
  }

  NValueSlider {
    label: I18n.tr("bar.workspace.pill-size-label")
    description: I18n.tr("bar.workspace.pill-size-description")
    from: 0.4
    to: 1.0
    stepSize: 0.01
    value: valuePillSize
    defaultValue: widgetMetadata.pillSize
    showReset: true
    onMoved: value => {
               settingsHelper.set("pillSize", value);
               saveSettings();
             }
    text: Math.round(valuePillSize * 100) + "%"
    visible: !valueShowApplications
  }

  NComboBox {
    id: fontWeightCombo
    label: I18n.tr("bar.workspace.font-weight-label")
    description: I18n.tr("bar.workspace.font-weight-description")
    model: [
      {
        "key": "regular",
        "name": I18n.tr("common.font-weight-regular")
      },
      {
        "key": "medium",
        "name": I18n.tr("common.font-weight-medium")
      },
      {
        "key": "semibold",
        "name": I18n.tr("common.font-weight-semibold")
      },
      {
        "key": "bold",
        "name": I18n.tr("common.font-weight-bold")
      },
    ]
    currentKey: settingsHelper.value("fontWeight")
    onSelected: key => {
                  settingsHelper.set("fontWeight", key);
                  saveSettings();
                }
    minimumWidth: 200
  }

  NToggle {
    label: I18n.tr("bar.workspace.hide-unoccupied-label")
    description: I18n.tr("bar.workspace.hide-unoccupied-description")
    checked: valueHideUnoccupied
    onToggled: checked => {
                 settingsHelper.set("hideUnoccupied", checked);
                 saveSettings();
               }
  }

  NToggle {
    label: I18n.tr("bar.workspace.show-labels-only-when-occupied-label")
    description: I18n.tr("bar.workspace.show-labels-only-when-occupied-description")
    checked: valueShowLabelsOnlyWhenOccupied
    onToggled: checked => {
                 settingsHelper.set("showLabelsOnlyWhenOccupied", checked);
                 saveSettings();
               }
  }

  NToggle {
    label: I18n.tr("bar.workspace.follow-focused-screen-label")
    description: I18n.tr("bar.workspace.follow-focused-screen-description")
    checked: valueFollowFocusedScreen
    onToggled: checked => {
                 settingsHelper.set("followFocusedScreen", checked);
                 saveSettings();
               }
  }

  NToggle {
    label: I18n.tr("bar.workspace.enable-scrollwheel-label")
    description: I18n.tr("bar.workspace.enable-scrollwheel-description")
    checked: valueEnableScrollWheel
    onToggled: checked => {
                 settingsHelper.set("enableScrollWheel", checked);
                 saveSettings();
               }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: I18n.tr("bar.workspace.show-applications-label")
    description: I18n.tr("bar.workspace.show-applications-description")
    checked: valueShowApplications
    onToggled: checked => {
                 settingsHelper.set("showApplications", checked);
                 saveSettings();
               }
  }

  NToggle {
    label: I18n.tr("bar.workspace.show-applications-hover-label")
    description: I18n.tr("bar.workspace.show-applications-hover-description")
    checked: valueShowApplicationsHover
    onToggled: checked => {
                 settingsHelper.set("showApplicationsHover", checked);
                 saveSettings();
               }
    visible: valueShowApplications
  }

  NToggle {
    label: I18n.tr("bar.workspace.show-badge-label")
    description: I18n.tr("bar.workspace.show-badge-description")
    checked: valueShowBadge
    onToggled: checked => {
                 settingsHelper.set("showBadge", checked);
                 saveSettings();
               }
    visible: valueShowApplications
  }

  NToggle {
    label: I18n.tr("bar.tray.colorize-icons-label")
    description: I18n.tr("bar.active-window.colorize-icons-description")
    checked: valueColorizeIcons
    onToggled: checked => {
                 settingsHelper.set("colorizeIcons", checked);
                 saveSettings();
               }
    visible: valueShowApplications
  }

  NValueSlider {
    label: I18n.tr("bar.workspace.unfocused-icons-opacity-label")
    description: I18n.tr("bar.workspace.unfocused-icons-opacity-description")
    from: 0
    to: 1
    stepSize: 0.01
    showReset: true
    value: valueUnfocusedIconsOpacity
    defaultValue: widgetMetadata.unfocusedIconsOpacity
    onMoved: value => {
               settingsHelper.set("unfocusedIconsOpacity", value);
               saveSettings();
             }
    text: Math.floor(valueUnfocusedIconsOpacity * 100) + "%"
    visible: valueShowApplications
  }

  NValueSlider {
    label: I18n.tr("bar.workspace.grouped-border-opacity-label")
    description: I18n.tr("bar.workspace.grouped-border-opacity-description")
    from: 0
    to: 1
    stepSize: 0.01
    showReset: true
    value: valueGroupedBorderOpacity
    defaultValue: widgetMetadata.groupedBorderOpacity
    onMoved: value => {
               settingsHelper.set("groupedBorderOpacity", value);
               saveSettings();
             }
    text: Math.floor(valueGroupedBorderOpacity * 100) + "%"
    visible: valueShowApplications
  }

  NValueSlider {
    label: I18n.tr("bar.taskbar.icon-scale-label")
    description: I18n.tr("bar.taskbar.icon-scale-description")
    from: 0.5
    to: 1
    stepSize: 0.01
    showReset: true
    value: valueIconScale
    defaultValue: widgetMetadata.iconScale
    onMoved: value => {
               settingsHelper.set("iconScale", value);
               saveSettings();
             }
    text: Math.round(valueIconScale * 100) + "%"
    visible: valueShowApplications
  }

  NDivider {
    Layout.fillWidth: true
  }

  NColorChoice {
    label: I18n.tr("bar.workspace.focused-color-label")
    description: I18n.tr("bar.workspace.focused-color-description")
    currentKey: valueFocusedColor
    onSelected: key => {
                  settingsHelper.set("focusedColor", key);
                  saveSettings();
                }
  }

  NColorChoice {
    label: I18n.tr("bar.workspace.occupied-color-label")
    description: I18n.tr("bar.workspace.occupied-color-description")
    currentKey: valueOccupiedColor
    onSelected: key => {
                  settingsHelper.set("occupiedColor", key);
                  saveSettings();
                }
  }

  NColorChoice {
    label: I18n.tr("bar.workspace.empty-color-label")
    description: I18n.tr("bar.workspace.empty-color-description")
    currentKey: valueEmptyColor
    onSelected: key => {
                  settingsHelper.set("emptyColor", key);
                  saveSettings();
                }
  }
}
