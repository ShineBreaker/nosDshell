import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NDccNextPage - the DDE NextPageWidget row (DESIGN §3.5.4).
*
* Title on the left, the current value (white x 0.8) on the right, then a
* chevron. The whole row is clickable and emits `clicked`, which is what opens
* the second-level page. Geometry follows nextpagewidget.cpp:49-52 — 5 px
* between value and button, 10 px trailing margin, fixed height 36.
*/
NDccRow {
  id: root

  property string title: ""
  property string value: ""
  property string icon: ""

  Layout.fillWidth: true

  NText {
    Layout.alignment: Qt.AlignVCenter
    Layout.fillWidth: true
    text: root.title
    pointSize: Style.fontSizeTitle
    font.weight: Style.fontWeightRegular
    color: Color.onShell
    elide: Text.ElideRight
  }

  NIcon {
    visible: root.icon !== ""
    Layout.alignment: Qt.AlignVCenter
    Layout.rightMargin: Style.settingsNextGap
    icon: root.icon
    pointSize: Style.fontSizeL
    color: Color.onShellSecondary
  }

  NText {
    visible: root.value !== ""
    Layout.alignment: Qt.AlignVCenter
    text: root.value
    pointSize: Style.fontSizeBody
    color: Color.onShellSecondary
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    // Half the content width at most, so a long value can never squeeze the
    // title out of the row.
    Layout.maximumWidth: Math.max(0, (root.width - Style.settingsRowPaddingH * 2) * 0.5)
  }

  NIcon {
    Layout.alignment: Qt.AlignVCenter
    icon: "chevron-right"
    pointSize: Style.settingsNextChevronSize
    color: Color.onShellTertiary
  }
}
