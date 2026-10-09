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
}
