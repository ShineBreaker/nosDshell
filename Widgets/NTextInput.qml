import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NDccRow {
  id: root

  property string label: ""
  property string description: ""
  property string inputIconName: ""
  property bool readOnly: false
  property color labelColor: Color.onShell
  property color descriptionColor: Color.onShellTertiary
  property string fontFamily: Settings.data.ui.fontDefault
  property real fontSize: Style.fontSizeS
  property int fontWeight: Style.fontWeightRegular
  property var defaultValue: undefined
  property string settingsPath: ""
  property real radius: Style.settingsFieldRadius
  property real minimumInputWidth: 80 * Style.uiScaleRatio
  property bool showClearButton: true
  // A labelled input is a settings row; a bare one is not.
  property bool dccRow: label !== "" || description !== ""
  // LineEditWidget puts the title in a fixed 140 px column (lineeditwidget.cpp:83).
  property real titleWidth: Style.settingsFieldTitleWidth

  property alias text: input.text
  property alias placeholderText: input.placeholderText
  property alias inputMethodHints: input.inputMethodHints
  property alias horizontalAlignment: input.horizontalAlignment
  property alias inputItem: input

  signal editingFinished
  signal accepted

  opacity: enabled ? 1.0 : 0.3
  plain: !root.dccRow
  spacing: root.dccRow ? Style.settingsFieldGap : Style.marginS

  readonly property bool isValueChanged: (defaultValue !== undefined) && (text !== defaultValue)
  readonly property string indicatorTooltip: defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {
                                                                                    "value": defaultValue === "" ? "(empty)" : String(defaultValue)
                                                                                  }) : ""

  NLabel {
    label: root.label
    description: root.description
    labelColor: root.labelColor
    descriptionColor: root.descriptionColor
    labelWeight: Style.fontWeightRegular
    visible: root.label !== "" || root.description !== ""
    Layout.fillWidth: true
    // §3.5.4: the title sits in a fixed column, the field takes the rest.
    Layout.maximumWidth: root.dccRow ? root.titleWidth : Number.POSITIVE_INFINITY
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  // An active control that blocks input, to avoid events leakage and dragging stuff in the background.
  Control {
    id: frameControl

    Layout.fillWidth: true
    Layout.minimumWidth: root.minimumInputWidth
    Layout.margins: Style.borderS
    implicitHeight: Style.settingsFieldHeight

    // This is important - makes the control accept focus
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    background: Rectangle {
      id: frame

      radius: root.radius
      color: Color.overlay("field")
      border.color: input.activeFocus ? Color.accent : "transparent"
      border.width: Style.borderS

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
        }
      }
    }

    contentItem: Item {
      // Invisible background that captures ALL mouse events
      MouseArea {
        id: backgroundCapture
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false

        onPressed: mouse => {
                     mouse.accepted = true;
                     // Focus the input and position cursor
                     input.forceActiveFocus();
                     var inputPos = mapToItem(inputContainer, mouse.x, mouse.y);
                     if (inputPos.x >= 0 && inputPos.x <= inputContainer.width) {
                       var textPos = inputPos.x - Style.marginM;
                       if (textPos >= 0 && textPos <= input.width) {
                         input.cursorPosition = input.positionAt(textPos, input.height / 2);
                       }
                     }
                   }

        onReleased: mouse => {
                      mouse.accepted = true;
                    }
        onDoubleClicked: mouse => {
                           mouse.accepted = true;
                           input.selectAll();
                         }
        onPositionChanged: mouse => {
                             mouse.accepted = true;
                           }
        onWheel: wheel => {
                   wheel.accepted = false;
                 }
      }

      // Container for the actual text field
      Item {
        id: inputContainer
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: 0
        clip: true
        z: 1

        RowLayout {
          anchors.fill: parent
          spacing: 0

          NIcon {
            id: inputIcon
            icon: root.inputIconName

            visible: root.inputIconName !== ""
            enabled: false

            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: visible ? Style.marginS : 0
          }

          TextField {
            id: input

            Layout.fillWidth: true
            Layout.fillHeight: true

            verticalAlignment: TextInput.AlignVCenter

            echoMode: TextInput.Normal
            readOnly: root.readOnly
            placeholderTextColor: Color.onShellTertiary
            color: enabled ? Color.onShell : Qt.alpha(Color.onShell, 0.4)

            selectByMouse: true

            topPadding: 0
            bottomPadding: 0
            leftPadding: 0
            rightPadding: 0

            background: null

            font.family: root.fontFamily
            font.pointSize: root.fontSize * Style.uiScaleRatio
            font.weight: root.fontWeight

            onEditingFinished: root.editingFinished()
            onAccepted: root.accepted()

            // Override mouse handling to prevent propagation
            MouseArea {
              id: textFieldMouse
              anchors.fill: parent
              acceptedButtons: Qt.AllButtons
              preventStealing: true
              propagateComposedEvents: false
              cursorShape: Qt.IBeamCursor

              property int selectionStart: 0

              onPressed: mouse => {
                           mouse.accepted = true;
                           input.forceActiveFocus();
                           var pos = input.positionAt(mouse.x, mouse.y);
                           input.cursorPosition = pos;
                           selectionStart = pos;
                         }

              onPositionChanged: mouse => {
                                   if (mouse.buttons & Qt.LeftButton) {
                                     mouse.accepted = true;
                                     var pos = input.positionAt(mouse.x, mouse.y);
                                     input.select(selectionStart, pos);
                                   }
                                 }

              onDoubleClicked: mouse => {
                                 mouse.accepted = true;
                                 input.selectAll();
                               }

              onReleased: mouse => {
                            mouse.accepted = true;
                          }
              onWheel: wheel => {
                         wheel.accepted = false;
                       }
            }
          }
          NIconButton {
            id: clearButton
            icon: "x"
            tooltipText: (input.text.length > 0 && !root.readOnly && root.enabled) ? I18n.tr("common.clear") : ""

            Layout.alignment: Qt.AlignVCenter
            border.width: 0

            colorBg: "transparent"
            colorBgHover: "transparent"
            colorFg: Color.onShellSecondary
            colorFgHover: Color.alert

            visible: root.showClearButton && input.text.length > 0 && !root.readOnly
            enabled: input.text.length > 0 && !root.readOnly && root.enabled

            onClicked: {
              input.clear();
              input.forceActiveFocus();
            }
          }
        }
      }
    }
  }
}
