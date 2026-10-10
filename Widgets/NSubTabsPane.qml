import QtQuick
import qs.Widgets

// Generates the NTabButton strip of a settings sub-tab NTabBar from an
// ordered list of Title entries: each entry's position IS its tab index,
// wired into the generated button's tabIndex/checked — no hand-written
// ordinals left to drift against the NTabView page order.
//
// Declare it inside the NTabBar: the pane itself is invisible filler there,
// while the Repeater re-parents to the pane's parent (the bar's tabRow), so
// the generated buttons land as direct tabRow children and NTabBar's
// children-walking paths (groupMode/_updateGroupMode/groupTitles,
// Widgets/NTabBar.qml:34-60) keep working unchanged.
Item {
  id: root
  visible: false

  // The bar owning the generated buttons; its currentIndex drives `checked`.
  property NTabBar bar: null

  // One Title per sub-tab, in NTabView page order. Titles stay as child
  // declarations (not a JS array) on purpose: the settings search index is
  // built by scanning NTabBar blocks for `text: I18n.tr(...)` lines
  // (Scripts/test/build-settings-search-index.py, parse_subtabs).
  default property alias titles: _holder.children

  component Title: Item {
    property string text: ""
  }

  Item {
    id: _holder
    visible: false
  }

  Repeater {
    id: strip

    parent: root.parent

    delegate: NTabButton {
      required property int index
      required property var modelData

      text: modelData.text
      tabIndex: index
      checked: root.bar && root.bar.currentIndex === index
    }
  }

  // Bindings evaluate before the declarative Titles are appended to the
  // default property, and Item.children carries no change signal — so the
  // model is built exactly once here, when every Title already exists
  // (sub-tab strips are static; nothing rebuilds them afterwards).
  Component.onCompleted: {
    const out = [];
    for (let i = 0; i < _holder.children.length; i++)
      out.push(_holder.children[i]);
    strip.model = out;
  }
}
