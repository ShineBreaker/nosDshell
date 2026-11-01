import QtQuick
import QtQuick.Layouts
import qs.Commons

/**
* NHeader - the DDE SettingsHead (DESIGN §3.5.4).
*
* 24 px tall with the title inset 20 px from the left and 10 px from the
* right (settingshead.cpp:78-80); the title is DemiBold white — the group
* heading weight of §1.5 — and an optional description sits under it in white
* x 0.6. The head is not a SettingsItem, so it carries no fill of its own; it
* is the label for the group that follows, separated by the same 1 px seam the
* rows use (settingsgroup.cpp:46).
*/
ColumnLayout {
  id: root

  property string label: ""
  property string description: ""
  property bool enableDescriptionRichText: false

  // No blanket opacity: the NText children dim themselves once when disabled.
  spacing: Style.marginXXS
  visible: root.label !== "" || root.description !== ""

  Layout.fillWidth: true
  Layout.minimumHeight: Style.settingsHeadHeight
  // The 1 px head-to-group seam (DESIGN §3.5.4). ColumnLayout.spacing stacks
  // with Layout.bottomMargin, so a parent that already spaces would turn
  // this into a 2 px gap (or 10 px where the column used marginM). Only
  // contribute the seam when the parent inserts none of its own. Item
  // parents (the stacked NTabView head layer) are positioned by hand and
  // never read here — instanceof skips them so a missing `spacing` is not
  // touched.
  readonly property bool _parentAddsSpacing: (parent instanceof ColumnLayout || parent instanceof RowLayout) && parent.spacing > 0
  Layout.bottomMargin: _parentAddsSpacing ? 0 : Style.settingsGroupGap

  NText {
    text: root.label
    pointSize: Style.fontSizeTitle
    font.weight: Style.fontWeightSemiBold
    color: Colors.onShell
    visible: root.label !== ""
    Layout.fillWidth: true
    Layout.leftMargin: Style.settingsHeadPaddingH
    Layout.rightMargin: Style.settingsHeadPaddingRight
  }

  NText {
    text: root.description
    pointSize: Style.fontSizeM
    color: Colors.onShellTertiary
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    Layout.leftMargin: Style.settingsHeadPaddingH
    Layout.rightMargin: Style.settingsHeadPaddingRight
    visible: root.description !== ""
    richTextEnabled: root.enableDescriptionRichText
  }
}
