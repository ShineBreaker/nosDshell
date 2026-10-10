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
  property bool valueShowCapsLock: settingsHelper.value("showCapsLock")
  property bool valueShowNumLock: settingsHelper.value("showNumLock")
  property bool valueShowScrollLock: settingsHelper.value("showScrollLock")

  property string capsIcon: settingsHelper.value("capsLockIcon")
  property string numIcon: settingsHelper.value("numLockIcon")
  property string scrollIcon: settingsHelper.value("scrollLockIcon")

  property bool valueHideWhenOff: widgetData.hideWhenOff !== undefined ? widgetData.hideWhenOff : (widgetMetadata.hideWhenOff !== undefined ? widgetMetadata.hideWhenOff : false)

  function saveSettings() {
    var settings = settingsHelper.save();
    settings.hideWhenOff = valueHideWhenOff;
    settingsChanged(settings);
    return settings;
  }

  RowLayout {
    spacing: Style.marginM

    NToggle {
      label: I18n.tr("bar.lock-keys.show-caps-lock-label")
      description: I18n.tr("bar.lock-keys.show-caps-lock-description")
      checked: valueShowCapsLock
      onToggled: checked => {
                   settingsHelper.set("showCapsLock", checked);
                   saveSettings();
                 }
      defaultValue: widgetMetadata.showCapsLock
    }

    NIcon {
      Layout.alignment: Qt.AlignVCenter
      icon: capsIcon
      pointSize: Style.fontSizeXL
      visible: capsIcon !== ""
    }

    NButton {
      text: I18n.tr("common.browse")
      onClicked: capsPicker.open()
      enabled: valueShowCapsLock
    }
  }

  NIconPicker {
    id: capsPicker
    initialIcon: capsIcon
    query: "letter-c"
    onIconSelected: function (iconName) {
      settingsHelper.set("capsLockIcon", iconName);
      saveSettings();
    }
  }

  RowLayout {
    spacing: Style.marginM

    NToggle {
      label: I18n.tr("bar.lock-keys.show-num-lock-label")
      description: I18n.tr("bar.lock-keys.show-num-lock-description")
      checked: valueShowNumLock
      onToggled: checked => {
                   settingsHelper.set("showNumLock", checked);
                   saveSettings();
                 }
      defaultValue: widgetMetadata.showNumLock
    }

    NIcon {
      Layout.alignment: Qt.AlignVCenter
      icon: numIcon
      pointSize: Style.fontSizeXL
      visible: numIcon !== ""
    }

    NButton {
      text: I18n.tr("common.browse")
      onClicked: numPicker.open()
      enabled: valueShowNumLock
    }
  }

  NIconPicker {
    id: numPicker
    initialIcon: numIcon
    query: "letter-n"
    onIconSelected: function (iconName) {
      settingsHelper.set("numLockIcon", iconName);
      saveSettings();
    }
  }

  RowLayout {
    spacing: Style.marginM

    NToggle {
      label: I18n.tr("bar.lock-keys.show-scroll-lock-label")
      description: I18n.tr("bar.lock-keys.show-scroll-lock-description")
      checked: valueShowScrollLock
      onToggled: checked => {
                   settingsHelper.set("showScrollLock", checked);
                   saveSettings();
                 }
      defaultValue: widgetMetadata.showScrollLock
    }

    NIcon {
      Layout.alignment: Qt.AlignVCenter
      icon: scrollIcon
      pointSize: Style.fontSizeXL
      visible: scrollIcon !== ""
    }

    NButton {
      text: I18n.tr("common.browse")
      onClicked: scrollPicker.open()
      enabled: valueShowScrollLock
    }
  }

  NIconPicker {
    id: scrollPicker
    initialIcon: scrollIcon
    query: "letter-s"
    onIconSelected: function (iconName) {
      settingsHelper.set("scrollLockIcon", iconName);
      saveSettings();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.lock-keys.hide-when-off-label")
    description: I18n.tr("bar.lock-keys.hide-when-off-description")
    checked: valueHideWhenOff
    onToggled: checked => {
                 valueHideWhenOff = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideWhenOff
  }
}
