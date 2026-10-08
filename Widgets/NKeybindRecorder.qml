import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

NDccRow {
  id: root

  property string label: ""
  property string description: ""
  property var currentKeybinds: []
  property string defaultKeybind: ""
  property bool allowEmpty: false
  property color labelColor: Color.onShell
  property color descriptionColor: Color.onShellTertiary
  property string settingsPath: ""
  // A labelled recorder is a settings row; a bare one is not.
  property bool dccRow: label !== ""

  property int maxKeybinds: 2
  property bool requireModifierForNormalKeys: true
  signal keybindsChanged(var newKeybinds)

  // implicitHeight comes from NDccRow (row minimum + padding).

  // -1 = not recording, >= 0 = re-recording at index, -2 = adding new
  property int recordingIndex: -1
  property bool hasConflict: false

  onRecordingIndexChanged: {
    PanelService.isKeybindRecording = recordingIndex !== -1;
    if (recordingIndex !== -1) {
      hasConflict = false;
    }
  }

  readonly property real _pillHeight: Style.settingsFieldHeight

  function _applyKeybind(keyStr) {
    if (!keyStr)
      return;

    // 1. Internal duplicate check (same action)
    for (let i = 0; i < root.currentKeybinds.length; i++) {
      if (i !== root.recordingIndex && String(root.currentKeybinds[i]).toLowerCase() === keyStr.toLowerCase()) {
        hasConflict = true;
        ToastService.showWarning(I18n.tr("panels.general.keybinds-conflict-title"), I18n.tr("panels.general.keybinds-conflict-description", {
                                                                                              "action": root.label || "This action"
                                                                                            }));
        conflictTimer.restart();
        return;
      }
    }

    // 2. External conflict check (other actions)
    const conflict = Keybinds.getKeybindConflict(keyStr, root.settingsPath, Settings.data);
    if (conflict) {
      hasConflict = true;
      ToastService.showWarning(I18n.tr("panels.general.keybinds-conflict-title"), I18n.tr("panels.general.keybinds-conflict-description", {
                                                                                            "action": conflict
                                                                                          }));
      conflictTimer.restart();
      return;
    }

    var newKeybinds = Array.from(root.currentKeybinds);
    if (recordingIndex >= 0) {
      newKeybinds[recordingIndex] = keyStr;
    }
    // Ensure array is dense and limited to maxKeybinds
    newKeybinds = newKeybinds.filter(k => k !== undefined && k !== "").slice(0, root.maxKeybinds);
    recordingIndex = -1;
    root.keybindsChanged(newKeybinds);
  }

  Timer {
    id: conflictTimer
    interval: 2000
    onTriggered: {
      hasConflict = false;
      recordingIndex = -1;
    }
  }

  plain: !root.dccRow
  spacing: Style.marginL
  // A conflicting keybind gets the SettingsItem error border.
  error: root.hasConflict

  RowLayout {
    id: contentLayout
    Layout.fillWidth: true
    spacing: Style.marginL

    // Label and Description (optional)
    NLabel {
      id: labelContainer
      label: root.label
      description: root.description
      labelColor: root.labelColor
      descriptionColor: root.descriptionColor
      labelWeight: Style.fontWeightRegular
      visible: label !== "" || description !== ""
      Layout.alignment: Qt.AlignVCenter
      // §3.5.4: the title sits in a fixed column, the slots take the rest.
      // preferredWidth (not fillWidth) so the slots row is the only filler:
      // two fillWidth siblings split the row proportionally by preferred
      // width and the pills' preferredWidth of 1 starves them to ~5 px.
      Layout.preferredWidth: root.dccRow ? Style.settingsFieldTitleWidth : -1
    }

    RowLayout {
      id: slotsRow
      spacing: Style.marginS
      Layout.fillWidth: true
      // No Layout.alignment here: setting it makes the layout item size
      // to preferred width (fillWidth is then ignored) and the pills
      // collapse to a few px.

      Repeater {
        model: root.maxKeybinds
        delegate: MouseArea {
          id: slotArea
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: Math.round(root._pillHeight * 2)
          height: root._pillHeight
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          readonly property bool isOccupied: index < root.currentKeybinds.length
          readonly property bool isRecordingThis: root.recordingIndex === index
          readonly property string keybindText: isRecordingThis ? I18n.tr("placeholders.keybind-recording") : (isOccupied ? root.currentKeybinds[index] : I18n.tr("placeholders.add-new-keybind"))

          onClicked: {
            if (isRecordingThis) {
              root.recordingIndex = -1;
            } else {
              root.recordingIndex = index;
              keybindInput.forceActiveFocus();
            }
          }

          Rectangle {
            id: slotBg
            anchors.fill: parent
            radius: Style.radiusItem
            clip: true
            color: root.hasConflict && slotArea.isRecordingThis ? Qt.alpha(Color.alert, 0.15) : (slotArea.isRecordingThis ? Color.overlay("checked") : (slotArea.containsMouse ? Color.overlay("hover") : Color.overlay("field")))
            border.color: root.hasConflict && slotArea.isRecordingThis ? Color.alert : (slotArea.isRecordingThis ? Color.accent : "transparent")
            border.width: Style.borderS

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
              }
            }
            Behavior on border.color {
              ColorAnimation {
                duration: Style.animationFast
              }
            }

            // Empty slots are too narrow for the "add keybind"
            // caption — show just a centred glyph instead of a
            // truncated string.
            NIcon {
              anchors.centerIn: parent
              icon: "keyboard"
              color: Color.onShellTertiary
              opacity: 0.8
              visible: !slotArea.isOccupied && !slotArea.isRecordingThis
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginS
              spacing: Style.marginXS
              visible: slotArea.isOccupied || slotArea.isRecordingThis

              // The icon only marks the recording state; an
              // occupied slot spends its width on the key name.
              NIcon {
                icon: root.hasConflict ? "alert-circle" : "circle-dot"
                color: root.hasConflict ? Color.alert : Color.accent
                opacity: 0.8
                visible: slotArea.isRecordingThis
              }

              NText {
                Layout.fillWidth: true
                text: slotArea.keybindText
                color: Color.onShell
                family: Settings.data.ui.fontFixed
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightMedium
                elide: Text.ElideRight
              }

              Item {
                Layout.preferredWidth: Math.round(root._pillHeight * 0.7)
                Layout.fillHeight: true
                // Reveal on hover: a permanently reserved ×
                // slot starves two-bind pills to ~25 px of
                // text ("Return" elides to "R…").
                visible: (root.currentKeybinds.length > 1 || root.allowEmpty) && slotArea.containsMouse

                NIconButton {
                  anchors.centerIn: parent
                  visible: root.recordingIndex === -1
                  icon: "x"
                  colorBg: "transparent"
                  colorBgHover: Qt.alpha(Color.alert, 0.1)
                  colorFg: Color.onShellTertiary
                  colorFgHover: Color.alert
                  border.width: 0
                  baseSize: Style.baseWidgetSize * 0.7
                  onClicked: {
                    var newKeybinds = Array.from(root.currentKeybinds);
                    newKeybinds.splice(index, 1);
                    root.keybindsChanged(newKeybinds);
                  }
                }
              }
            }
          }
        }
      }
    }

    // Hidden Item to capture keys
    Item {
      id: keybindInput
      width: 0
      height: 0
      focus: true

      Keys.onPressed: event => {
                        if (root.recordingIndex === -1 || root.hasConflict)
                        return;

                        // Handle Escape specifically to ensure it doesn't close the panel
                        if (event.key === Qt.Key_Escape) {
                          event.accepted = true;
                          root._applyKeybind("Esc");
                          return;
                        }

                        // Ignore modifier keys by themselves
                        if (event.key === Qt.Key_Control || event.key === Qt.Key_Shift || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                          event.accepted = true; // Consume modifiers too while listening
                          return;
                        }

                        const keybindStr = Keybinds.getKeybindString(event);
                        if (keybindStr) {
                          // Enforce modifier requirement (Ctrl or Alt) for "normal" keys unless explicitly disabled
                          // Allow Arrows, Nav, Function, and System keys without modifiers
                          const isSpecialKey = (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) || (event.key >= Qt.Key_Left && event.key <= Qt.Key_Down) || (event.key === Qt.Key_Home || event.key === Qt.Key_End || event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) || (event.key === Qt.Key_Insert || event.key === Qt.Key_Delete || event.key
                                                                                                                                                                                                                                                                                            === Qt.Key_Backspace) || (event.key === Qt.Key_Tab || event.key
                                                                                                                                                                                                                                                                                                                      === Qt.Key_Return || event.key === Qt.Key_Enter
                                                                                                                                                                                                                                                                                                                      || event.key === Qt.Key_Escape || event.key
                                                                                                                                                                                                                                                                                                                      === Qt.Key_Space);

                          const hasModifier = (event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.AltModifier);

                          if (root.requireModifierForNormalKeys && !hasModifier && !isSpecialKey) {
                            hasConflict = true;
                            ToastService.showWarning(I18n.tr("panels.general.keybinds-modifier-title"), I18n.tr("panels.general.keybinds-modifier-description"));
                            conflictTimer.restart();
                            return;
                          }

                          root._applyKeybind(keybindStr);
                        }
                        event.accepted = true;
                      }
    }
  }
}
