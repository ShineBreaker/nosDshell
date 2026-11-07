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
* `title` draws the optional SettingsHead inside the group (same 1 px seam
* to the first row). For the head of a whole stacked sub-tab the NTabView
* draws the title itself; `title` is for extra sections inside a page.
*
* Between two groups put NDccGap (the 15 px group spacing).
*/
ColumnLayout {
  id: root

  property string title: ""

  spacing: Style.settingsGroupGap
  Layout.fillWidth: true

  NHeader {
    label: root.title
    visible: root.title !== ""
    Layout.fillWidth: true
  }
}
