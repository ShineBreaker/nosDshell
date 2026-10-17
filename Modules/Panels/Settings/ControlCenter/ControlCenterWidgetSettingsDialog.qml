import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Widget Settings Dialog Component
Popup {
  id: root
  enter: NPopupEnter {}
  exit: NPopupExit {}

  property int widgetIndex: -1
  property var widgetData: null
  property string widgetId: ""
  property string sectionId: ""
  property var screen: null
  property var settingsCache: ({})

  signal updateWidgetSettings(string section, int index, var settings)

  readonly property real maxHeight: (screen ? screen.height : (parent ? parent.height : 800)) * 0.8
  readonly property real defaultContentWidth: Math.round(600 * Style.uiScaleRatio)
  readonly property real settingsContentWidth: {
    if (settingsLoader.item && settingsLoader.item.implicitWidth > 0) {
      return settingsLoader.item.implicitWidth;
    }
    return defaultContentWidth;
  }

  readonly property real dialogPadding: Style.marginXL
  width: Math.max(settingsContentWidth + dialogPadding * 2, 500)
  height: Math.min(content.implicitHeight + dialogPadding * 2, maxHeight)
  padding: 0
  modal: true
  closePolicy: Popup.NoAutoClose
  anchors.centerIn: parent

  onOpened: {
    if (widgetData && widgetId) {
      loadWidgetSettings();
    }
  }

  background: Rectangle {
    color: Color.maskShell
    radius: Style.radiusWindow
    border.color: Color.borderShell
    border.width: Style.borderM
  }

  contentItem: ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: dialogPadding
    spacing: Style.marginM

    // Title
    RowLayout {
      id: titleRow
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight

      NText {
        text: I18n.tr("system.widget-settings-title", {
                        "widget": root.widgetId
                      })
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
        color: Color.onShell
        Layout.fillWidth: true
      }

      NIconButton {
        icon: "close"
        tooltipText: I18n.tr("common.close")
        onClicked: saveAndClose()
      }
    }

    // Separator
    Rectangle {
      id: separator
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      color: Color.overlay("hover")
    }

    // Scrollable settings area
    NScrollView {
      id: scrollView
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 100
      gradientColor: Color.maskShell
      reserveScrollbarSpace: false

      ColumnLayout {
        width: scrollView.availableWidth
        spacing: Style.marginM

        Loader {
          id: settingsLoader
          Layout.fillWidth: true
          onItemChanged: {
            if (item) {
              // Force width recalculation when content loads
              Qt.callLater(() => {
                             root.width = Math.max(root.settingsContentWidth + root.dialogPadding * 2, 500);
                           });
            }
          }
        }
      }
    }

    // Button bar separator (DDialog shape, same as NPluginSettingsPopup)
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      color: Color.overlay("hover")
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginM
      spacing: Style.marginM

      NButton {
        objectName: "widgetSettingsReset"
        text: I18n.tr("common.reset-to-default")
        icon: "restore"
        outlined: true
        onClicked: root.resetToDefaults()
      }

      Item {
        Layout.fillWidth: true
      }

      NButton {
        objectName: "widgetSettingsClose"
        text: I18n.tr("common.close")
        outlined: true
        onClicked: root.saveAndClose()
      }
    }
  }

  Timer {
    id: saveTimer
    running: false
    interval: 150
    onTriggered: {
      root.updateWidgetSettings(root.sectionId, root.widgetIndex, root.settingsCache);
    }
  }

  Connections {
    target: settingsLoader.item
    ignoreUnknownSignals: true
    function onSettingsChanged(newSettings) {
      if (newSettings) {
        root.settingsCache = newSettings;
        saveTimer.start();
      }
    }
  }

  function saveAndClose() {
    if (settingsLoader.item && typeof settingsLoader.item.saveSettings === 'function') {
      var newSettings = settingsLoader.item.saveSettings();
      if (newSettings) {
        root.updateWidgetSettings(root.sectionId, root.widgetIndex, newSettings);
      }
    }
    root.close();
  }

  // Back to registry defaults: the entry becomes exactly what a fresh add
  // writes ({id} + widgetMetadata). _updateWidgetSettingsInSection replaces
  // the entry, so stale saved keys drop out; then reload the page — settings
  // pages capture values into local state on load.
  function resetToDefaults() {
    if (!widgetId || widgetIndex < 0)
      return;
    var metadata = ControlCenterWidgetRegistry.widgetMetadata[widgetId] || {};
    var entry = {
      "id": widgetId
    };
    Object.keys(metadata).forEach(function (key) {
      entry[key] = metadata[key];
    });
    saveTimer.stop();
    root.settingsCache = ({});
    root.updateWidgetSettings(root.sectionId, root.widgetIndex, entry);
    loadWidgetSettings();
    ToastService.showNotice(I18n.tr("system.widget-settings-title", {
                                    "widget": root.widgetId
                                  }), I18n.tr("common.settings-reset"));
  }

  function loadWidgetSettings() {
    // Blank first: setSource() on the same URL only re-instantiates reliably
    // after the previous item is dropped.
    settingsLoader.source = "";
    // Re-read the stored entry so a reload after reset shows defaults, not
    // the widgetData snapshot this dialog was created with.
    var currentWidgetData = widgetData;
    if (sectionId && widgetIndex >= 0) {
      var stored = Settings.data.controlCenter.shortcuts[sectionId] || [];
      if (widgetIndex < stored.length) {
        currentWidgetData = stored[widgetIndex];
      }
    }
    const widgetSettingsMap = {
      "CustomButton": "WidgetSettings/CustomButtonSettings.qml"
    };

    const source = widgetSettingsMap[widgetId];
    if (source) {
      settingsLoader.setSource(source, {
                                 "widgetData": currentWidgetData,
                                 "widgetMetadata": ControlCenterWidgetRegistry.widgetMetadata[widgetId]
                               });
    }
  }
}
