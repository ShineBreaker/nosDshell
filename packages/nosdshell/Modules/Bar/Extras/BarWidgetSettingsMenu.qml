import qs.Commons
import qs.Services.UI
import qs.Widgets

// Shared right-click menu for bar widgets: the trailing "widget-settings"
// entry (opens the per-instance settings dialog via BarService) is fixed;
// widget-specific entries are supplied through extraModel and come back via
// extraActionTriggered with the model entry that was activated.
NPopupContextMenu {
  id: root

  // The widget root object; provides widgetId, section, sectionWidgetIndex
  // and the live widgetSettings binding used when opening the settings dialog.
  property var widget: null
  property var extraModel: []

  signal extraActionTriggered(var action, var item)

  model: extraModel.concat([
                             {
                               "label": I18n.tr("actions.widget-settings"),
                               "action": "widget-settings",
                               "icon": "settings"
                             }
                           ])

  onTriggered: (action, item) => {
                 root.close();
                 PanelService.closeContextMenu(root.screen);

                 if (action === "widget-settings") {
                   var w = root.widget;
                   BarService.openWidgetSettings(root.screen, w.section, w.sectionWidgetIndex, w.widgetId, w.widgetSettings);
                 } else {
                   root.extraActionTriggered(action, item);
                 }
               }
}
