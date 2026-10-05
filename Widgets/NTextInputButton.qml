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
  spacing: root.dccRow ? Style.settingsFieldGap : Style.marginS

  // Label and description
  NLabel {
    label: root.label
    description: root.description
    labelWeight: Style.fontWeightRegular
    visible: root.label !== "" || root.description !== ""
    Layout.fillWidth: true
    Layout.maximumWidth: root.dccRow ? Style.settingsFieldTitleWidth : Number.POSITIVE_INFINITY
  }

  // Input field with button
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

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
