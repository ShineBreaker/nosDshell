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
        text: I18n.tr("common.volumes")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.devices")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.media")
      }
      NSubTabsPane.Title {
        text: I18n.tr("common.visualizer")
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

    VolumesSubTab {}
    DevicesSubTab {}
    MediaSubTab {}
    VisualizerSubTab {}
  }
}
