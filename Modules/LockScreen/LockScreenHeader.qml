import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Widgets

// DDE lock screen bottom band clock column (DESIGN §3.9, dde-lock timewidget.cpp):
// HH:mm at 48 px from the left edge, Light at Style.fontSizeLockClock, with the
// date underneath. The band and the right-hand control row are owned by
// LockScreenPanel so all of them share one geometry.
Item {
  id: root

  // Use timer-driven properties instead of Time.now to avoid per-frame repaints.
  // Time.now updates every frame (~60+ Hz); these update only when needed.
  property date currentTime: new Date()
  property date currentDate: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentTime = new Date()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.currentDate = new Date()
  }

  implicitWidth: Math.max(timeLabel.implicitWidth, dateLabel.implicitWidth)
  implicitHeight: timeLabel.implicitHeight + dateLabel.implicitHeight + Style.marginXS

  // HH:mm — "Noto Sans" Light (Maven Pro is not bundled on this machine).
  NText {
    id: timeLabel
    text: I18n.locale.toString(root.currentTime, "HH:mm")
    pointSize: Style.fontSizeLockClock
    font.weight: Font.Light
    font.family: "Noto Sans"
    color: "white"
  }

  // Date below the clock (DESIGN §3.9: yyyy-MM-dd dddd, 16 px).
  NText {
    id: dateLabel
    anchors.top: timeLabel.bottom
    anchors.topMargin: Style.marginXS
    text: I18n.locale.toString(root.currentDate, "yyyy-MM-dd dddd")
    pointSize: 16
    font.family: "Noto Sans"
    color: "white"
  }
}
