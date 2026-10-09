import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

// DDE OptionItem: whole row clickable, checked = accent check glyph on the
// right, unchecked = nothing; the row itself carries the SettingsItem
// background (DESIGN §3.5.4).
NDccRow {
  id: root

  // Public API
  property string label: ""
  property string description: ""
  property bool checked: false
  property bool hovering: false
  property color activeColor: Color.accent
  property color activeOnColor: Color.onAccent
  property int baseSize: root.defaultSize
  property real labelSize: Style.fontSizeTitle
  // A labelled option is a settings row; a bare one is not.
  property bool dccRow: label !== ""

  readonly property int defaultSize: Style.baseWidgetSize * 0.7

  signal toggled(bool checked)
  signal entered
  signal exited

  clickable: true
  plain: !root.dccRow
  spacing: Style.marginM

  NLabel {
    label: root.label
    labelSize: root.labelSize
    description: root.description
    labelWeight: Style.fontWeightRegular
    visible: root.label !== "" || root.description !== ""
    Layout.fillWidth: true
  }

  // DDE draws a 16 px select.svg on the right (optionitem.cpp:64-72)
  NIcon {
    visible: root.checked
    icon: "check"
    color: root.activeColor
    pointSize: Style.settingsNextChevronSize
    opacity: enabled ? 1.0 : 0.6
    Layout.alignment: Qt.AlignVCenter
  }

  onEntered: {
    hovering = true;
    root.entered();
  }
  onExited: {
    hovering = false;
    root.exited();
  }
  onClicked: root.toggled(!root.checked)
}
