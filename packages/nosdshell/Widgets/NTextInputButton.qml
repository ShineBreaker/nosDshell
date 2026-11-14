import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NTextInputButton - a text field row with a trailing action button.
*
* With a label it is one DDE settings row (DESIGN §3.5.4): title on the left,
* field plus button on the right. The inner NTextInput is forced into plain
* mode so it does not paint a second row of its own.
*/
NDccRow {
  id: root

  property alias text: input.text
  property alias placeholderText: input.placeholderText
  property alias inputReadOnly: input.readOnly
  property string label: ""
  property string description: ""
  property string inputIconName: ""
  property alias buttonIcon: button.icon
  property alias buttonTooltip: button.tooltipText
  property alias buttonEnabled: button.enabled
  property real maximumWidth: 0
  // A labelled field is a settings row; a bare one is not.
  property bool dccRow: label !== "" || description !== ""

  signal buttonClicked
  signal inputTextChanged(string text)
  signal inputEditingFinished

  plain: !root.dccRow
  spacing: root.dccRow ? Style.marginM : Style.marginS

  // Label and description
  NLabel {
    id: titleLabel

    label: root.label
    description: root.description
    labelWeight: Style.fontWeightRegular
    visible: root.label !== "" || root.description !== ""
    Layout.fillWidth: true
    Layout.minimumWidth: root.dccRow ? Math.min(titleLabel.labelImplicitWidth, Style.settingsFieldTitleMaxWidth) : 0
  }

  // Field plus its trailing button share the one control column. The button
  // used to sit outside settingsFieldWidth and overlap the field or the
  // row padding (avatar picker, folder button, excluded-player "+").
  RowLayout {
    spacing: Style.marginXS
    // The inner field is plain (no margin of its own). This margin is the
    // one labelled combos and spin boxes use, so the field starts on the
    // column (1723) instead of 1 px to the right.
    Layout.margins: root.dccRow ? Style.borderS : 0
    Layout.fillWidth: !root.dccRow
    Layout.minimumWidth: root.dccRow ? Style.settingsFieldWidth : 0
    Layout.preferredWidth: root.dccRow ? Style.settingsFieldWidth : -1
    Layout.maximumWidth: root.dccRow ? Style.settingsFieldWidth : Number.POSITIVE_INFINITY

    NTextInput {
      id: input
      inputIconName: root.inputIconName
      dccRow: false
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      enabled: root.enabled
      onTextChanged: root.inputTextChanged(text)
      onEditingFinished: root.inputEditingFinished()
    }

    // Button
    NIconButton {
      id: button
      baseSize: Style.baseWidgetSize
      onClicked: root.buttonClicked()
    }
  }
}
