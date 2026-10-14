import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../../Helpers/QtObj2JS.js" as QtObj2JS
import "General"
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    // The sub-tab strip is the SettingsGroup header row of the page now
    // (DESIGN §3.5.3), not a pill strip.
    groupMode: true
    currentIndex: tabView.currentIndex

    NSubTabsPane {
      bar: subTabBar
      NSubTabsPane.Title {
        text: I18n.tr("panels.general.tab-basics")
      }
      NSubTabsPane.Title {
        text: I18n.tr("panels.general.tab-keybinds")
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
    BasicsSubTab {}
    KeybindsSubTab {}
  }
}
