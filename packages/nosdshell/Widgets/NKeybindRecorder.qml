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
  property color labelColor: Colors.onShell
  property color descriptionColor: Colors.onShellTertiary
  property string settingsPath: ""
  // A labelled recorder is a settings row; a bare one is not.
  property bool dccRow: label !== ""

  property int maxKeybinds: 2
  property bool requireModifierForNormalKeys: true
  signal keybindsChanged(var newKeybinds)

  // implicitHeight comes from NDccRow (row minimum + padding).

  // -1 = not recording, >= 0 = re-recording at that slot index (an empty
  // slot records like any other).
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
  spacing: root.dccRow ? Style.marginM : Style.marginL
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
      Layout.fillWidth: true
      Layout.minimumWidth: root.dccRow ? Math.min(labelContainer.labelImplicitWidth, Style.settingsFieldTitleMaxWidth) : 0
    }

    // Both pills share the standard control column. A RowLayout around the
    // Repeater gave the first delegate of one row width 0 (first Up, then
    // after that was pinned, Down). Explicit x/width does not depend on
    // the layout pass, so every bound key is a real hit target.
    Item {
      id: slotsBox
      implicitWidth: Style.settingsFieldWidth
      implicitHeight: root._pillHeight
      // Same 1 px margin as NComboBox / NSpinBox. Without it the 170 px
      // pill group sits at 1724–1893 while those controls sit at 1723–1892.
      Layout.margins: root.dccRow ? Style.borderS : 0
      Layout.fillWidth: !root.dccRow
      Layout.minimumWidth: root.dccRow ? Style.settingsFieldWidth : implicitWidth
      Layout.preferredWidth: root.dccRow ? Style.settingsFieldWidth : implicitWidth
      Layout.maximumWidth: root.dccRow ? Style.settingsFieldWidth : implicitWidth
      Layout.alignment: Qt.AlignVCenter

      readonly property int slotCount: Math.max(1, root.maxKeybinds)
      readonly property int slotGap: Style.marginS
      readonly property int slotInner: Math.max(slotCount, Style.settingsFieldWidth - slotGap * (slotCount - 1))
      readonly property int slotBase: Math.floor(slotInner / slotCount)

      Repeater {
        model: root.maxKeybinds
        delegate: MouseArea {
          id: slotArea
          required property int index
          readonly property int slotWidth: index === slotsBox.slotCount - 1 ? (slotsBox.slotInner - slotsBox.slotBase * (slotsBox.slotCount - 1)) : slotsBox.slotBase
          x: index * (slotsBox.slotBase + slotsBox.slotGap)
          y: 0
          width: slotWidth
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
            color: root.hasConflict && slotArea.isRecordingThis ? Qt.alpha(Colors.alert, 0.15) : (slotArea.isRecordingThis ? Colors.overlay("checked") : (slotArea.containsMouse ? Colors.overlay("hover") : Colors.overlay("field")))
            border.color: root.hasConflict && slotArea.isRecordingThis ? Colors.alert : (slotArea.isRecordingThis ? Colors.accent : "transparent")
            border.width: Style.borderS

            // Empty slots are too narrow for the "add keybind"
            // caption — show just a centred glyph instead of a
            // truncated string.
            NIcon {
              anchors.centerIn: parent
              icon: "keyboard"
              color: Colors.onShellTertiary
              opacity: 0.8
              visible: !slotArea.isOccupied && !slotArea.isRecordingThis
            }

            RowLayout {
              anchors.fill: parent
              // Equal insets. The clear glyph is an overlay, so reserving
              // its width here shoved every key name ~15 px left of centre
              // even when the glyph was hidden.
              anchors.leftMargin: Style.marginS
              anchors.rightMargin: Style.marginS
              spacing: Style.marginXS
              visible: slotArea.isOccupied || slotArea.isRecordingThis

              NIcon {
                icon: root.hasConflict ? "alert-circle" : "circle-dot"
                color: root.hasConflict ? Colors.alert : Colors.accent
                opacity: 0.8
                visible: slotArea.isRecordingThis
              }

              // The key name is never elided. The clear glyph is an overlay
              // in the right inset, so it does not steal the text's width.
              NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: slotArea.keybindText
                color: Colors.onShell
                family: Settings.data.ui.fontFixed
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightMedium
                elide: Text.ElideNone
              }
            }

            NIcon {
              id: clearGlyph
              z: 2
              anchors.right: parent.right
              anchors.rightMargin: Style.marginS
              anchors.verticalCenter: parent.verticalCenter
              icon: "x"
              pointSize: Style.fontSizeXS
              color: clearArea.containsMouse ? Colors.alert : Colors.onShellTertiary
              visible: (root.currentKeybinds.length > 1 || root.allowEmpty) && slotArea.containsMouse && root.recordingIndex === -1 && (slotArea.isOccupied || slotArea.isRecordingThis)

              MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -Style.marginXS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
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

  // Key capture must not be a child of the row layout. A 0×0 item there
  // still consumes the layout spacing and shifts the pills off the column.
  Item {
    id: keybindInput
    parent: root
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
