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

  opacity: enabled ? 1.0 : 0.6
  spacing: Style.marginXXS
  visible: root.label !== "" || root.description !== ""

  Layout.fillWidth: true
  Layout.minimumHeight: Style.settingsHeadHeight
  Layout.bottomMargin: Style.settingsGroupGap

  NText {
    text: root.label
    pointSize: Style.fontSizeTitle
    font.weight: Style.fontWeightSemiBold
    color: Color.onShell
    visible: root.label !== ""
    Layout.fillWidth: true
    Layout.leftMargin: Style.settingsHeadPaddingH
    Layout.rightMargin: Style.settingsHeadPaddingRight
  }

  NText {
    text: root.description
    pointSize: Style.fontSizeM
    color: Color.onShellTertiary
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    Layout.leftMargin: Style.settingsHeadPaddingH
    Layout.rightMargin: Style.settingsHeadPaddingRight
    visible: root.description !== ""
    richTextEnabled: root.enableDescriptionRichText
  }
}
