import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NNextPageRow - the "下一页" settings row (DESIGN §3.5.3/§3.5.4): title on the
* left, optional value (onShell x 0.8) and a › on the right. Clicking pushes
* `page` onto the enclosing SettingsModuleView's sub-page stack — heavy
* editors live on their own page, not folded behind the row.
*
* `page` is a Component created in the caller's scope; `pageProperties` is the
* dict passed to createObject (e.g. {screen: …} for a per-monitor editor).
*/
NDccRow {
  id: root

  property string label: ""
  property string description: ""
  property string value: ""
  property Component page: null
  property var pageProperties: ({})
  // Header title of the pushed page; defaults to the row label.
  property string pageTitle: label

  clickable: true

  // The page stack lives on the ancestor SettingsModuleView; walk parents
  // instead of a singleton so a row always reaches the view it renders in.
  function _settingsView() {
    var p = root.parent;
    while (p) {
      if (typeof p.pushPage === "function")
        return p;
      p = p.parent;
    }
    return null;
  }

  onClicked: {
    var view = _settingsView();
    if (!view || !root.page) {
      Logger.w("NNextPageRow", "cannot push: no SettingsModuleView ancestor or no page set");
      return;
    }
    view.pushPage(root.pageTitle, root.page, root.pageProperties);
  }

  NLabel {
    label: root.label
    description: root.description
    labelWeight: Style.fontWeightRegular
    Layout.fillWidth: true
    visible: root.label !== "" || root.description !== ""
  }

  NText {
    visible: root.value !== ""
    text: root.value
    pointSize: Style.fontSizeS
    color: Qt.alpha(Color.onShell, 0.8)
  }

  NIcon {
    icon: "chevron-right"
    pointSize: Style.fontSizeL
    color: Color.onShellTertiary
    Layout.alignment: Qt.AlignVCenter
  }
}
