import QtQuick
import QtQuick.Layouts
import qs.Commons

/**
* NHeader - a bare section label for NON-ROW content (DESIGN §3.5.4).
*
* 24 px tall with the title inset 20 px from the left and 10 px from the
* right (the SettingsHead insets, settingshead.cpp:78-80); the title is
* DemiBold white — the group heading weight of §1.5 — and an optional
* description sits under it in white x 0.6.
*
* It is NOT a group head: in dcc the head of a titled SettingsGroup is a
* row inside the block (NDccHead / NSettingsGroup.title). NHeader is the
* label for content that has no row chrome — the stacked sub-tab heads in
* NTabView, dialog titles, card-grid sections — and stands marginS off what
* follows (parents put that gap in their spacing).
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
  // ColumnLayout.spacing stacks with Layout.bottomMargin, so a parent that
  // already spaces would turn any margin here into a double gap. Only
  // contribute the 1 px minimum when the parent inserts none of its own.
  // Item parents (the stacked NTabView head layer) are positioned by hand
  // and never read here — instanceof skips them so a missing `spacing` is
  // not touched.
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
