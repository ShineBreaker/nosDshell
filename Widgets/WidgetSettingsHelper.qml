import QtQml

// Per-widget-settings-page read/write helper. value() collapses the
// widgetData -> widgetMetadata fallback ternaries and save() collapses the
// Object.assign-base + per-field assignments that every settings page used to
// duplicate. The widgets themselves read settings with the same metadata
// fallback, so fields the user never touched can stay out of the saved JSON.
QtObject {
  id: root

  // Saved settings of the widget instance and the registry metadata that
  // provides defaults for every field. Both may be null on a fresh page.
  property var widgetData: null
  property var widgetMetadata: null

  // Fields changed in this editing session (key -> new value). set() replaces
  // the whole object so bindings through value() refresh.
  property var edits: ({})

  // Fallback read: edited value -> saved value -> metadata default -> fallback.
  function value(key, fallback) {
    if (edits[key] !== undefined)
      return edits[key];
    if (widgetData && widgetData[key] !== undefined)
      return widgetData[key];
    if (widgetMetadata && widgetMetadata[key] !== undefined)
      return widgetMetadata[key];
    return fallback;
  }

  // Record one field change (marks it dirty for save()).
  function set(key, v) {
    var next = {};
    Object.assign(next, edits);
    next[key] = v;
    edits = next;
  }

  // Save: copy the widgetData base (keeps fields this page does not manage,
  // e.g. the widget id) and overwrite only the changed fields.
  function save() {
    var settings = {};
    Object.assign(settings, widgetData || {});
    Object.assign(settings, edits);
    return settings;
  }
}
