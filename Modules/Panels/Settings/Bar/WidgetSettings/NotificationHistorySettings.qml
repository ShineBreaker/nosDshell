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
  property bool valueShowUnreadBadge: settingsHelper.value("showUnreadBadge")
  property bool valueHideWhenZero: settingsHelper.value("hideWhenZero")
  property bool valueHideWhenZeroUnread: settingsHelper.value("hideWhenZeroUnread")
  property string valueUnreadBadgeColor: settingsHelper.value("unreadBadgeColor")
  property string valueIconColor: settingsHelper.value("iconColor")

  function saveSettings() {
    var settings = settingsHelper.save();
    settingsChanged(settings);
    return settings;
  }

  NToggle {
    label: I18n.tr("bar.notification-history.show-unread-badge-label")
    description: I18n.tr("bar.notification-history.show-unread-badge-description")
    checked: valueShowUnreadBadge
    onToggled: checked => {
                 settingsHelper.set("showUnreadBadge", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.showUnreadBadge
  }

  NColorChoice {
    label: I18n.tr("common.select-icon-color")
    currentKey: valueIconColor
    onSelected: key => {
                  settingsHelper.set("iconColor", key);
                  saveSettings();
                }
    defaultValue: widgetMetadata.iconColor
  }

  NColorChoice {
    label: I18n.tr("bar.notification-history.unread-badge-color-label")
    description: I18n.tr("bar.notification-history.unread-badge-color-description")
    currentKey: valueUnreadBadgeColor
    onSelected: key => {
                  settingsHelper.set("unreadBadgeColor", key);
                  saveSettings();
                }
    visible: valueShowUnreadBadge
    defaultValue: widgetMetadata.unreadBadgeColor
  }

  NToggle {
    label: I18n.tr("bar.notification-history.hide-widget-when-zero-label")
    description: I18n.tr("bar.notification-history.hide-widget-when-zero-description")
    checked: valueHideWhenZero
    onToggled: checked => {
                 settingsHelper.set("hideWhenZero", checked);
                 saveSettings();
               }
    enabled: !valueHideWhenZeroUnread
    defaultValue: widgetMetadata.hideWhenZero
  }

  NToggle {
    label: I18n.tr("bar.notification-history.hide-widget-when-zero-unread-label")
    description: I18n.tr("bar.notification-history.hide-widget-when-zero-unread-description")
    checked: valueHideWhenZeroUnread
    onToggled: checked => {
                 settingsHelper.set("hideWhenZeroUnread", checked);
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideWhenZeroUnread
  }
}
