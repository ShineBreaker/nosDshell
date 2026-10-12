import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Cards
import qs.Modules.Panels.ControlCenter
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterNotificationPage - the control center home page (DESIGN §3.5.2).
*
* DND switch row on top, then the reusable history list, then the enabled
* content cards from controlCenter.cards pinned below it — weather, media,
* system monitor — each as a block with overlay("idle") and radiusItem
* (〔演进〕 notification-first home: the cards are the default widgets under
* the list; the module grid moved to the all-settings page).
*
* `closeOnAction` is invoked after a notification action succeeds so the
* control center closes like the original panel did.
*/
Item {
  id: root

  property var screen: null
  property var closeOnAction: null

  readonly property var cards: Settings.data.controlCenter.cards

  implicitHeight: content.implicitHeight

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: Style.marginS

    // DND switch row (DSwitchButton: 40x22 capsule, DESIGN §3.5.4)
    Item {
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.preferredHeight: Style.detailRowHeight

      RowLayout {
        anchors.fill: parent
        spacing: Style.marginS

        NIcon {
          icon: (Settings.data.notifications.doNotDisturb) ? "bell-off" : "bell"
          pointSize: Style.fontSizeXL
          color: (Settings.data.notifications.doNotDisturb) ? Color.accent : Color.onShellSecondary
        }

        NText {
          Layout.fillWidth: true
          text: (Settings.data.notifications.doNotDisturb) ? I18n.tr("actions.disable-dnd") : I18n.tr("actions.enable-dnd")
          pointSize: Style.fontSizeM
          elide: Text.ElideRight
        }

        NToggle {
          label: ""
          checked: Settings.data.notifications.doNotDisturb
          onToggled: checked => Settings.data.notifications.doNotDisturb = checked
        }
      }
    }

    NotificationHistoryList {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginS
      screen: root.screen
      closeOnAction: root.closeOnAction
    }

    // ---------------- content cards ----------------
    // Pinned under the list — the home page's default widgets.
    Repeater {
      model: root.cards

      delegate: Loader {
        required property var modelData
        active: modelData.enabled && (modelData.id !== "weather-card" || Settings.data.location.weatherEnabled)
        visible: active
        Layout.fillWidth: true

        sourceComponent: {
          switch (modelData.id) {
          case "weather-card":
            return cardWeather;
          case "media-sysmon-card":
            return cardMediaSysmon;
          }
        }
      }
    }
  }

  Component {
    id: cardWeather
    WeatherCard {}
  }

  Component {
    id: cardMediaSysmon
    RowLayout {
      spacing: Style.marginS

      MediaCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(200 * Style.uiScaleRatio)
      }

      SystemMonitorCard {
        Layout.preferredWidth: Math.round(Style.baseWidgetSize * 2.625)
        Layout.fillHeight: true
      }
    }
  }
}
