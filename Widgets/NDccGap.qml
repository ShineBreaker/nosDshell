import QtQuick
import qs.Commons

/**
* NDccGap - vertical space between two SettingsGroups (DESIGN §3.5.4).
*
* Transparent and deliberately NOT a dcc row (`isDccRow: false`): a gap ends the
* run of rows above it, so the group before it gets its bottom corners back and
* the group after it starts a fresh pair.
*/
Item {
  id: root

  readonly property bool isDccRow: false

  implicitHeight: Style.settingsGroupSpacing
  implicitWidth: 0
}
