import QtQuick
import qs.Widgets

// Numeric widget-settings field: commits only on finished editing (focus
// loss or return), bounds to [minimum, maximum] and rolls the text back to
// the last stored value on invalid input. Generalizes the inline
// onEditingFinished + guard + rollback pattern of
// DesktopWidgets/WidgetSettings/AudioVisualizerSettings.qml, replacing the
// per-keystroke `onTextChanged: saveSettings()` +
// `parseInt(text) || default` writes that silently reset a stored
// customization the moment the field was cleared mid-edit.
NTextInput {
  id: root

  // Inclusive guardrail bounds (px/ms-sized settings; callers narrow them to
  // the field's actual range). Out-of-range input rolls back instead of
  // clamping so a stray keystroke can never silently rewrite the setting.
  property int minimum: 1
  property int maximum: 9999

  // Last stored value — bind to settingsHelper.value(key, metadataDefault).
  // The text the field falls back to when the entered input is empty, NaN or
  // out of range, and the baseline that skips no-op commits.
  property int storedValue: minimum

  inputMethodHints: Qt.ImhDigitsOnly

  signal committed(int value)

  onEditingFinished: {
    const parsed = parseInt(text);
    if (!isNaN(parsed) && parsed >= minimum && parsed <= maximum) {
      if (parsed !== storedValue)
        committed(parsed);
    } else {
      text = String(storedValue);
    }
  }
}
