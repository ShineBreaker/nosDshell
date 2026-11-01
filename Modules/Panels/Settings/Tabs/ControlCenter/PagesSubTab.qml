import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  // Quick-control strip page order (DESIGN §3.5.2). Pages are never toggled
  // off here — a page drops out of the strip when its controls are all off
  // on the Cards tab or its service is unavailable — so every row is
  // required (drag-only). Unavailable pages stay listed but greyed out so
  // their stored position survives a transient absence.
  readonly property var _knownPages: ["cards", "basic", "wifi", "bluetooth", "vpn"]
  property list<var> pagesModel: []

  function _pageText(id) {
    switch (id) {
    case "cards":
      return I18n.tr("common.cards");
    case "basic":
      return I18n.tr("panels.general.tab-basics");
    case "wifi":
      return I18n.tr("common.wifi");
    case "bluetooth":
      return I18n.tr("common.bluetooth");
    case "vpn":
      return I18n.tr("widgets.label-vpn");
    }
    return id;
  }

  // Same merge as the strip itself: stored order first (known ids only),
  // then missing canonical pages appended at the end.
  function _orderedIds() {
    const declared = Settings.data.controlCenter.quickPageOrder || [];
    var seq = [];
    declared.forEach(id => {
                       if (root._knownPages.indexOf(id) !== -1 && seq.indexOf(id) === -1)
                         seq.push(id);
                     });
    root._knownPages.forEach(id => {
                               if (seq.indexOf(id) === -1)
                                 seq.push(id);
                             });
    return seq;
  }

  function _rebuildModel() {
    var model = [];
    root._orderedIds().forEach(id => {
                                 model.push({
                                              "id": id,
                                              "text": root._pageText(id),
                                              "enabled": true,
                                              "required": true
                                            });
                               });
    root.pagesModel = model;
  }

  Component.onCompleted: root._rebuildModel()

  // Model entries bake I18n.tr results at append time — rebuild on language
  // change like the cards list does.
  Connections {
    target: I18n
    function onTranslationsLoaded() {
      root._rebuildModel();
    }
  }

  readonly property var unavailableIds: {
    var ids = [];
    if (!BluetoothService.bluetoothAvailable)
      ids.push("bluetooth");
    if (!(VPNService.connections && Object.keys(VPNService.connections).length > 0))
      ids.push("vpn");
    return ids;
  }

  NHeader {
    description: I18n.tr("panels.control-center.pages-desc")
  }

  NReorderCheckboxes {
    Layout.fillWidth: true
    model: root.pagesModel
    disabledIds: root.unavailableIds
    onItemsReordered: function (fromIndex, toIndex) {
      var newModel = root.pagesModel.slice();
      var item = newModel.splice(fromIndex, 1)[0];
      newModel.splice(toIndex, 0, item);
      root.pagesModel = newModel;
      Settings.data.controlCenter.quickPageOrder = newModel.map(entry => entry.id);
    }
  }
}
