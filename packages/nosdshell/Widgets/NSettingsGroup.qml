import QtQuick
import QtQuick.Layouts
import qs.Commons

/**
* NSettingsGroup - the DDE SettingsGroup container (DESIGN §3.5.4).
*
* The only way to lay out a settings group: rows stack as direct children
* with the 1 px seam (settingsgroup.cpp:46) and the rows' own head/tail scan
* rounds the outer corners (NDccRow). Do not wrap rows in extra columns —
* a wrapper that re-spaces its children breaks the seam.
*
* `title` draws the group's head as a 24 px row INSIDE the block — in dcc the
* SettingsHeaderItem/SettingsHead is a SettingsItem inserted into the group
* layout (settingsgroup.cpp:67-72, settingshead.cpp), so it shares the fill
* and takes the head corners. `titleNote` is the dim right-edge text of that
* head row. A section label for non-row content stays an NHeader.
*
* Between two groups put NDccGap (the 15 px group spacing).
*/
ColumnLayout {
  id: root

  property string title: ""
  property string titleNote: ""

  spacing: Style.settingsGroupGap
  Layout.fillWidth: true

  NDccHead {
    label: root.title
    note: root.titleNote
    visible: root.title !== ""
    Layout.fillWidth: true
  }
}
