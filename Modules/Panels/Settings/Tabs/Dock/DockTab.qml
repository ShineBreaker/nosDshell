import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Stacked 任务栏 module page (DESIGN §3.5.3): the dock's own page (常规) holds
// its feature switch plus every dock setting; the 状态栏 page owns the optional
// status bar and the shared bar chrome. Sub-tabs whose feature is off hide
// entirely — a feature switch hides its settings, including the tab strip.
ColumnLayout {
  id: root
  spacing: 0

  readonly property bool dockEnabled: Settings.data.dock.enabled
  readonly property bool fashionMode: Settings.data.dock.mode === "fashion"
  // The status-bar tab is alive whenever a bar can exist: fashion (optional
  // status bar over the dock) or efficient-with-dock (the bar IS the taskbar).
  readonly property bool barTabVisible: fashionMode || dockEnabled

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
        text: I18n.tr("panels.bar.title")
        shown: root.barTabVisible
      }
      NSubTabsPane.Title {
        text: I18n.tr("settings.taskbar.monitors")
        shown: root.dockEnabled
      }
      NSubTabsPane.Title {
        text: I18n.tr("settings.taskbar.plugins")
        shown: root.dockEnabled
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
    BarSubTab {}
    MonitorsSubTab {}
    PluginsSubTab {}
  }

  // When the page the user is looking at hides (dock switched off, or the
  // status-bar tab dies with efficient+disabled), land on the switch page.
  function _clampCurrentTab() {
    const vis = [true, barTabVisible, dockEnabled, dockEnabled];
    if (tabView.currentIndex >= 0 && tabView.currentIndex < vis.length && !vis[tabView.currentIndex])
      tabView.currentIndex = 0;
  }
  onDockEnabledChanged: _clampCurrentTab()
  onFashionModeChanged: _clampCurrentTab()
}
