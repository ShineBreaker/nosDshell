import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NSubTabsPane {
      bar: subTabBar
      NSubTabsPane.Title {
        text: I18n.tr("common.location")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.date")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.calendar-panel")
      }
    }
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    LocationSubTab {}
    DateSubTab {}
    ClockPanelSubTab {}
  }
}
