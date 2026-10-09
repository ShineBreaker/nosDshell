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
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NSubTabsPane {
      bar: subTabBar
      NSubTabsPane.Title {
        text: I18n.tr("settings.taskbar.general")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.appearance")
      }
      NSubTabsPane.Title {
        text: I18n.tr("panels.bar.title")
      }
      NSubTabsPane.Title {
        text: I18n.tr("settings.taskbar.monitors")
      }
      NSubTabsPane.Title {
        text: I18n.tr("settings.taskbar.plugins")
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

    GeneralSubTab {}
    AppearanceSubTab {}
    BarSubTab {}
    MonitorsSubTab {}
    PluginsSubTab {}
  }
}
