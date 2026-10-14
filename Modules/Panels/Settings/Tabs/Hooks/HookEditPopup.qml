import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Popup {
  id: root
  modal: true
  closePolicy: Popup.NoAutoClose
  enter: NPopupEnter {}
  exit: NPopupExit {}
  dim: true
  anchors.centerIn: parent

  // Use a reasonable width/height relative to parent or fixed
  width: Math.min(600 * Style.uiScaleRatio, parent.width * 0.9)
  height: Math.min(contentLayout.implicitHeight + padding * 2, parent.height * 0.9)
  padding: Style.marginL

  property string hookLabel: ""
  property string hookDescription: ""
  property string hookPlaceholder: ""
  property string initialValue: ""

  signal saved(string newValue)
  signal test(string value)

  property var _savedSlot: null
  property var _testSlot: null

  background: Rectangle {
    color: Color.maskShell
    radius: Style.radiusWindow
    border.color: Color.borderShell
    border.width: Style.borderS
  }

  onOpened: {
    commandInput.text = initialValue;
    commandInput.forceActiveFocus();
  }

  contentItem: ColumnLayout {
    id: contentLayout
    spacing: Style.marginL

    // Header
    RowLayout {
      Layout.fillWidth: true
      NText {
        text: root.hookLabel
        font.weight: Style.fontWeightSemiBold
        pointSize: Style.fontSizeL
        Layout.fillWidth: true
      }
      NIconButton {
        icon: "close"
        onClicked: root.close()
      }
    }

    // Description/Help
    NText {
      text: root.hookDescription
      color: Color.onShellTertiary
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    // Input Area
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NTextInput {
        id: commandInput
        Layout.fillWidth: true
        placeholderText: root.hookPlaceholder
        // NTextInput wraps a single-line TextField, so hook commands are
        // entered on one line; multi-line scripts stay a known gap.
      }
    }

    // Action Buttons
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        text: I18n.tr("common.test")
        icon: "caret-right"
        onClicked: root.test(commandInput.text)
        // Disable test if empty? Or maybe allow testing defined script.
        enabled: commandInput.text !== ""
      }

      Item {
        Layout.fillWidth: true
      } // Spacer

      NButton {
        text: I18n.tr("common.cancel")
        outlined: true
        onClicked: root.close()
      }

      NButton {
        text: I18n.tr("common.save")
        icon: "check"
        backgroundColor: Color.accent
        textColor: Color.onAccent
        onClicked: {
          root.saved(commandInput.text);
          root.close();
        }
      }
    }
  }
}
