import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  // Helper functions to update arrays immutably
  function addMonitor(list, name) {
    const arr = (list || []).slice();
    if (!arr.includes(name))
      arr.push(name);
    return arr;
  }
  function removeMonitor(list, name) {
    return (list || []).filter(function (n) {
      return n !== name;
    });
  }
  function addType(list, type) {
    const arr = (list || []).slice();
    if (!arr.includes(type))
      arr.push(type);
    return arr;
  }
  function removeType(list, type) {
    return (list || []).filter(function (t) {
      return t !== type;
    });
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NSubTabsPane {
      bar: subTabBar
      NSubTabsPane.Title {
        text: I18n.tr("common.general")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.events")
        shown: Settings.data.osd.enabled
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    GeneralSubTab {
      addMonitor: root.addMonitor
      removeMonitor: root.removeMonitor
    }
    EventsSubTab {
      addType: root.addType
      removeType: root.removeType
    }
  }

  // The events page has no switch of its own. When OSD is off, that tab
  // hides (DESIGN §3.5.3) and the view returns to the switch.
  readonly property bool osdOn: Settings.data.osd.enabled
  onOsdOnChanged: {
    if (!osdOn && tabView.currentIndex !== 0)
      tabView.currentIndex = 0;
  }
}
