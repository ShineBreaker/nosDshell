import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.Plugins
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterHeader - 140 px home header (DESIGN §3.5.2).
*
* gxde layout (mainwidget.cpp:120-147): margins (40,0,0,10), spacing 30 —
* 60x60 avatar top-left (10 px top margin, click opens the accounts module),
* HH:mm clock + long date vertically centred, and a right-side button row
* (settings, session, the 32x32 notifications toggle) centred with 20 px
* trailing. The toggle uses the original four-state artwork.
*/
Item {
  id: root

  property var screen: null
  property bool notificationPage: false

  signal avatarRequested
  signal settingsRequested
  signal sessionRequested
  signal notificationToggled

  implicitHeight: Style.controlCenterHeaderHeight

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.controlCenterHeaderMarginLeft
    anchors.rightMargin: Style.controlCenterHeaderMarginRight
    anchors.bottomMargin: Style.controlCenterHeaderMarginTop
    spacing: Style.controlCenterHeaderSpacing

    // 60x60 circular avatar. gxde pins it 10 px from the top
    // (avatarwidget.h:34) because their widget also draws the username below
    // the circle; we render the circle alone, so centring keeps it on the
    // same visual line as the clock and the button row.
    NImageRounded {
      Layout.preferredWidth: Style.controlCenterAvatarSize
      Layout.preferredHeight: Style.controlCenterAvatarSize
      Layout.alignment: Qt.AlignVCenter
      radius: Layout.preferredWidth / 2
      imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
      fallbackImagePath: Settings.ddeDefaultAvatar
      fallbackIcon: "person"
      borderColor: "transparent"
      borderWidth: 0

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.avatarRequested()
      }
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
        // Long-format date including the weekday; shrinks to fit so the
        // weekday is never elided mid-word (locale formats vary in length,
        // and a plain split(" ") drops or keeps the weekday unpredictably).
        text: Qt.locale().toString(Time.now, Locale.LongFormat)
        pointSize: Style.fontSizeM
        fontSizeMode: Text.HorizontalFit
        minimumPointSize: Style.fontSizeXS
        color: Color.onShell
        elide: Text.ElideRight
      }
    }

    // Right-side buttons: ProfileCard's settings/session actions stay flat;
    // the bell is the original four-state notifications toggle.
    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: Style.marginS

      NIconButton {
        icon: "settings"
        baseSize: 32
        applyUiScale: false
        colorFg: Color.onShell
        colorBg: "transparent"
        colorBgHover: Color.overlay("hover")
        tooltipText: I18n.tr("actions.open-settings")
        onClicked: root.settingsRequested()
      }

      NIconButton {
        icon: "power"
        baseSize: 32
        applyUiScale: false
        colorFg: Color.onShell
        colorBg: "transparent"
        colorBgHover: Color.overlay("hover")
        tooltipText: I18n.tr("tooltips.session-menu")
        onClicked: root.sessionRequested()
      }

      Item {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32

        Image {
          anchors.centerIn: parent
          width: 32
          height: 32
          sourceSize.width: 64
          sourceSize.height: 64
          smooth: true
          source: {
            const on = root.notificationPage || bellArea.pressed;
            const name = on ? (bellArea.containsMouse ? "checkedhover" : "checked") : (bellArea.containsMouse ? "hover" : "normal");
            return Quickshell.shellDir + "/Assets/DDE/gxde-control-center/src/frame/themes/dark/icons/notifications_toggle_" + name + ".svg";
          }
        }

        MouseArea {
          id: bellArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.notificationToggled()
        }
      }
    }
  }
}
