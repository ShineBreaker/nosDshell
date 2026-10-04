import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.Noctalia
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterHeader - 140 px home header (DESIGN §3.5.2).
*
* Avatar top-left, HH:mm clock at Style.fontSizeClockCC Light, long-format date
* below, 32x32 bell toggle on the right that flips the middle area between the
* module page and the notification page. ProfileCard's useful actions (settings,
* lock/power) survive as flat icon buttons in the top-right row.
*/
Item {
  id: root

  property var screen: null
  property bool notificationPage: false

  signal settingsRequested()
  signal sessionRequested()
  signal notificationToggled()

  implicitHeight: Style.controlCenterHeaderHeight

  // 32x32 bell toggle (gxde-control-center mainwidget.cpp:107-109)
  Rectangle {
    id: bellButton
    anchors.right: parent.right
    anchors.rightMargin: Style.marginL
    anchors.verticalCenter: parent.verticalCenter
    width: 32
    height: 32
    radius: Style.radiusRow
    color: bellArea.containsMouse ? Color.overlay("hover") : (root.notificationPage ? Color.overlay("idle") : "transparent")

    NIcon {
      anchors.centerIn: parent
      icon: root.notificationPage ? "bell" : "bell-off"
      pointSize: Style.fontSizeXL
      color: root.notificationPage ? Color.onShell : Color.onShellSecondary
    }

    MouseArea {
      id: bellArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.notificationToggled()
    }

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
      }
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.controlCenterHeaderMarginLeft
    anchors.rightMargin: Style.margin2XL
    anchors.topMargin: Style.marginS
    anchors.bottomMargin: Style.controlCenterHeaderMarginTop
    spacing: Style.marginL

    // Avatar (circular, Settings avatar — same source as ProfileCard)
    NImageRounded {
      Layout.preferredWidth: Math.round(Style.baseWidgetSize * 1.25 * Style.uiScaleRatio)
      Layout.preferredHeight: Math.round(Style.baseWidgetSize * 1.25 * Style.uiScaleRatio)
      Layout.alignment: Qt.AlignTop
      radius: Layout.preferredWidth / 2
      imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
      fallbackIcon: "person"
      borderColor: "transparent"
      borderWidth: 0
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: Style.marginXXS

      NText {
        Layout.fillWidth: true
        text: {
          const d = Time.now;
          const hh = ("0" + d.getHours()).slice(-2);
          const mm = ("0" + d.getMinutes()).slice(-2);
          return hh + ":" + mm;
        }
        font.pointSize: Math.max(1, Style.fontSizeClockCC * (Settings.data.ui.fontDefaultScale ?? 1.0) * Style.uiScaleRatio)
        font.weight: Style.fontWeightLight
        color: Color.onShell
        elide: Text.ElideRight
        Layout.minimumWidth: 0
      }

      NText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        // Date with weekday, long format minus the timezone tail
        text: Qt.locale().toString(Time.now, Locale.LongFormat).split(" ")[0]
        pointSize: Style.fontSizeM
        color: Color.onShell
        elide: Text.ElideRight
      }
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignTop
      spacing: Style.marginXXS

      NIconButton {
        icon: "settings"
        baseSize: Style.baseWidgetSize * 0.8
        applyUiScale: false
        colorFg: Color.onShellSecondary
        colorBg: "transparent"
        colorBgHover: Color.overlay("hover")
        colorFgHover: Color.onShell
        tooltipText: I18n.tr("actions.open-settings")
        onClicked: root.settingsRequested()
      }

      NIconButton {
        icon: "power"
        baseSize: Style.baseWidgetSize * 0.8
        applyUiScale: false
        colorFg: Color.onShellSecondary
        colorBg: "transparent"
        colorBgHover: Color.overlay("hover")
        colorFgHover: Color.onShell
        tooltipText: I18n.tr("tooltips.session-menu")
        onClicked: root.sessionRequested()
      }
    }
  }
}
