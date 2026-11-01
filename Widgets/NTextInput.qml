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
  property color labelColor: Colors.onShell
  property color descriptionColor: Colors.onShellTertiary
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
  property alias text: input.text
  property alias placeholderText: input.placeholderText
  property alias inputMethodHints: input.inputMethodHints
  property alias horizontalAlignment: input.horizontalAlignment
  property alias inputItem: input

  signal editingFinished
  signal accepted

  opacity: enabled ? 1.0 : 0.3
  plain: !root.dccRow
  spacing: root.dccRow ? Style.marginM : Style.marginS

  readonly property bool isValueChanged: (defaultValue !== undefined) && (text !== defaultValue)
  readonly property string indicatorTooltip: defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {
                                                                                    "value": defaultValue === "" ? "(empty)" : String(defaultValue)
                                                                                  }) : ""

  NLabel {
    id: titleLabel

    label: root.label
    description: root.description
    labelColor: root.labelColor
    descriptionColor: root.descriptionColor
    labelWeight: Style.fontWeightRegular
    // The row's own opacity already dims the whole subtree.
    autoDim: false
    visible: root.label !== "" || root.description !== ""
    Layout.fillWidth: true
    // §3.5.4: wrap past the title budget; the field keeps settingsFieldWidth.
    Layout.minimumWidth: root.dccRow ? Math.min(titleLabel.labelImplicitWidth, Style.settingsFieldTitleMaxWidth) : 0
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  // An active control that blocks input, to avoid events leakage and dragging stuff in the background.
  Control {
    id: frameControl

    Layout.fillWidth: true
    // A settings row pins the control column (DESIGN §3.5.4 控件列宽) so the
    // fields of neighbouring rows line up; a bare input (the settings search
    // box, popups, the launcher) still fills the width it is given.
    Layout.minimumWidth: root.dccRow ? Style.settingsFieldWidth : root.minimumInputWidth
    Layout.preferredWidth: root.dccRow ? Style.settingsFieldWidth : -1
    Layout.maximumWidth: root.dccRow ? Style.settingsFieldWidth : Number.POSITIVE_INFINITY
    // Same 1 px margin as NComboBox and NSpinBox. Dropping it (to chase a
    // 2 px button-group offset) moved every labelled field to 1724–1893
    // while those controls stayed at 1723–1892. A bare field inside a
    // button group must not add a second margin on top of the group.
    Layout.margins: root.dccRow ? Style.borderS : 0
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    implicitHeight: Style.settingsFieldHeight

    // This is important - makes the control accept focus
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    background: Rectangle {
      id: frame

      radius: root.radius
      color: Colors.overlay("field")
      border.color: input.activeFocus ? Colors.accent : "transparent"
      border.width: Style.borderS

      Behavior on border.color {
        enabled: !Colors.isTransitioning
        NColorAnim {
          duration: Style.motionSwitch
          curve: "swift"
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
                       var textPos = inputPos.x - Style.marginL;
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
        anchors.leftMargin: Style.marginL
        anchors.rightMargin: Style.marginL
        // Clip only while editing. Idle clip cut the scrolled tail through
        // the middle of a glyph (the system-monitor command).
        clip: input.activeFocus
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

          Item {
            id: textSlot
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextField {
              id: input
              anchors.fill: parent

              verticalAlignment: TextInput.AlignVCenter

              echoMode: TextInput.Normal
              readOnly: root.readOnly
              placeholderTextColor: Colors.onShellTertiary
              // While idle, the elided overlay draws the value so a long
              // path does not scroll under the clip or into the clear glyph.
              color: input.activeFocus ? (enabled ? Colors.onShell : Qt.alpha(Colors.onShell, 0.4)) : "transparent"

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

          // Idle display. ElideLeft keeps the tail (paths, commands) and
          // stops on a glyph boundary, with the same left inset the field
          // already applies outside this slot.
          NText {
            anchors.fill: textSlot
            visible: !input.activeFocus && input.text.length > 0
            text: input.text
            elide: Text.ElideLeft
            verticalAlignment: Text.AlignVCenter
            color: enabled ? Colors.onShell : Qt.alpha(Colors.onShell, 0.4)
            font.family: root.fontFamily
            font.pointSize: root.fontSize * Style.uiScaleRatio
            font.weight: root.fontWeight
          }
        }
          // Glyph-sized clear control. The gap in front of it is marginL,
          // the same inset the text has from the left edge of the field.
          // A 0 spacing let the wallpaper path run to ~2 px from the glyph.
          Item {
            id: clearButton
            visible: root.showClearButton && input.text.length > 0 && !root.readOnly
            implicitWidth: clearGlyph.implicitWidth
            implicitHeight: clearGlyph.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: visible ? Style.marginL : 0

            NIcon {
              id: clearGlyph
              icon: "x"
              pointSize: Style.fontSizeM
              color: clearMouse.containsMouse ? Colors.alert : Colors.onShellSecondary
            }

            MouseArea {
              id: clearMouse
              anchors.fill: parent
              anchors.margins: -Style.marginXS
              hoverEnabled: true
              enabled: clearButton.visible && root.enabled
              cursorShape: Qt.PointingHandCursor
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
}
