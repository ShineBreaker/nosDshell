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

  readonly property bool isVerticalBar: Settings.getBarPositionForScreen(screen?.name) === "left" || Settings.getBarPositionForScreen(screen?.name) === "right"

  // Local state
  property string valueHideMode: settingsHelper.value("hideMode")
  property bool valueOnlyActiveWorkspaces: settingsHelper.value("onlyActiveWorkspaces")
  property bool valueOnlySameOutput: settingsHelper.value("onlySameOutput")
  property bool valueColorizeIcons: settingsHelper.value("colorizeIcons")
  property bool valueShowTitle: settingsHelper.value("showTitle")
  property bool valueSmartWidth: settingsHelper.value("smartWidth")
  property int valueMaxTaskbarWidth: settingsHelper.value("maxTaskbarWidth")
  property int valueTitleWidth: settingsHelper.value("titleWidth")
  property bool valueShowPinnedApps: settingsHelper.value("showPinnedApps")
  property real valueIconScale: settingsHelper.value("iconScale")

  function saveSettings() {
    var settings = settingsHelper.save();
    if (!isVerticalBar) {}
    settings.titleWidth = parseInt(titleWidthInput.text) || widgetMetadata.titleWidth;
    settingsChanged(settings);
    return settings;
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.hide-mode-label")
    description: I18n.tr("bar.taskbar.hide-mode-description")
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
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.only-same-monitor-label")
    description: I18n.tr("bar.taskbar.only-same-monitor-description")
    checked: root.valueOnlySameOutput
    onToggled: checked => {
                 settingsHelper.set("onlySameOutput", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.onlySameOutput
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.only-active-workspaces-label")
    description: I18n.tr("bar.taskbar.only-active-workspaces-description")
    checked: root.valueOnlyActiveWorkspaces
    onToggled: checked => {
                 settingsHelper.set("onlyActiveWorkspaces", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.onlyActiveWorkspaces
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.tray.colorize-icons-label")
    description: I18n.tr("bar.taskbar.colorize-icons-description")
    checked: root.valueColorizeIcons
    onToggled: checked => {
                 settingsHelper.set("colorizeIcons", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.colorizeIcons
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.show-pinned-apps-label")
    description: I18n.tr("bar.taskbar.show-pinned-apps-description")
    checked: root.valueShowPinnedApps
    onToggled: checked => {
                 settingsHelper.set("showPinnedApps", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showPinnedApps
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.icon-scale-label")
    description: I18n.tr("bar.taskbar.icon-scale-description")
    from: 0.5
    to: 1
    stepSize: 0.01
    showReset: true
    value: root.valueIconScale
    defaultValue: widgetMetadata.iconScale
    onMoved: value => {
               settingsHelper.set("iconScale", value);
               saveSettings();
             }
    text: Math.round(root.valueIconScale * 100) + "%"
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.show-title-label")
    description: isVerticalBar ? I18n.tr("bar.taskbar.show-title-description-disabled") : I18n.tr("bar.taskbar.show-title-description")
    checked: root.valueShowTitle
    onToggled: checked => {
                 settingsHelper.set("showTitle", checked);
                 saveSettings();
               }
    enabled: !isVerticalBar
    defaultValue: widgetMetadata.showTitle
  }

  NTextInput {
    id: titleWidthInput
    visible: root.valueShowTitle && !isVerticalBar
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.title-width-label")
    description: I18n.tr("bar.taskbar.title-width-description")
    text: String(settingsHelper.value("titleWidth", ""))
    placeholderText: I18n.tr("placeholders.enter-width-pixels")
    onTextChanged: saveSettings()
    defaultValue: String(widgetMetadata.titleWidth)
  }

  NToggle {
    Layout.fillWidth: true
    visible: !isVerticalBar && root.valueShowTitle
    label: I18n.tr("bar.taskbar.smart-width-label")
    description: I18n.tr("bar.taskbar.smart-width-description")
    checked: root.valueSmartWidth
    onToggled: checked => {
                 settingsHelper.set("smartWidth", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.smartWidth
  }

  NValueSlider {
    visible: root.valueSmartWidth && !isVerticalBar
    Layout.fillWidth: true
    label: I18n.tr("bar.taskbar.max-width-label")
    description: I18n.tr("bar.taskbar.max-width-description")
    from: 10
    to: 100
    stepSize: 5
    showReset: true
    value: root.valueMaxTaskbarWidth
    defaultValue: widgetMetadata.maxTaskbarWidth
    onMoved: value => {
               settingsHelper.set("maxTaskbarWidth", Math.round(value));
               saveSettings();
             }
    text: Math.round(root.valueMaxTaskbarWidth) + "%"
  }
}
