import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings.Tabs.Bar as BarTabs
import qs.Widgets

// Advanced overflow page (DESIGN §2 "DDE 中没有" row, §3.5.3 高级模块):
// every key here still has a runtime consumer but no place in the DDE
// five-item taskbar page. Split into sub-tabs like every other settings tab —
// as a single 2500 px column its later groups scrolled past what the module
// view could comfortably show and had no inner navigation at all.
// Zero-consumer keys (dock.displayMode/floatingRatio/…, bar.position/
// displayMode/barType, bar.rightClick*, sessionMenu layout keys) have no
// control; their schema fields are retained (DESIGN §6).
ColumnLayout {
  id: root
  spacing: 0

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: I18n.tr("control-center.module.taskbar")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: I18n.tr("panels.bar.title")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    NTabButton {
      text: I18n.tr("common.monitors")
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
    }
    NTabButton {
      text: I18n.tr("settings.advanced.panels-corners")
      tabIndex: 3
      checked: subTabBar.currentIndex === 3
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    DockSubTab {}
    BarSubTab {}
    BarTabs.ScreenOverridesSubTab {}
    PanelsSubTab {}
  }
}
