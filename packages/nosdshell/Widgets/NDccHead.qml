import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NDccHead - the DDE SettingsHead / SettingsHeaderItem row (DESIGN §3.5.4).
*
* A group's title is a 24 px row INSIDE the block — in dcc the header item is
* a SettingsItem inserted into the group layout (settingsgroup.cpp:67-72), so
* it shares the block's fill and takes the head corners. The title is a
* NormalLabel at weight 550, inset 20 px left / 10 px right
* (settingshead.cpp:78-80, settingsheaderitem.cpp:32-52).
*
* `note` is the small dim text at the row's right edge — the stand-in for
* SettingsHeaderItem::setRightWidget when the head needs live status (e.g.
* "扫描中…"). It is not interactive: DDE head rows never hover.
*/
NDccRow {
  id: root

  property string label: ""
  property string note: ""

  interactive: false
  minRowHeight: Style.settingsHeadHeight
  paddingRight: Style.settingsHeadPaddingRight
  paddingV: 0

  NText {
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
    text: root.label
    pointSize: Style.fontSizeBody
    font.weight: Style.settingsHeadTitleWeight
    color: Colors.onShell
    elide: Text.ElideRight
  }

  NText {
    visible: root.note !== ""
    Layout.alignment: Qt.AlignVCenter
    text: root.note
    pointSize: Style.fontSizeBody
    color: Colors.onShellTertiary
    elide: Text.ElideRight
  }
}
