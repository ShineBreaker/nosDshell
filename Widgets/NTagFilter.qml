import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Tag filter chips: optional header (label + description) over a Flow of
// toggle chips. Always flat — settings surfaces never fold group content
// behind a chevron row (DESIGN §3.5.4).
ColumnLayout {
  id: root

  // Public API
  property var tags: []  // Array of tag strings
  property string selectedTag: ""
  property string label: ""
  property string description: ""

  // Formatting function for tag display (optional override)
  property var formatTag: function (tag) {
    if (tag === "")
      return I18n.tr("launcher.categories.all");
    // Default: capitalize first letter
    return tag.charAt(0).toUpperCase() + tag.slice(1);
  }

  Layout.fillWidth: true
  spacing: Style.marginXS

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginXS
    spacing: Style.marginL
    visible: root.label !== "" || root.description !== ""

    NText {
      text: root.label
      pointSize: Style.fontSizeL
      font.weight: Style.fontWeightSemiBold
      color: Colors.onShell
      wrapMode: Text.WordWrap
      // Same inset as NHeader, so the filter title lines up with the
      // section head above it (it was ~13 px to the left).
      Layout.leftMargin: Style.settingsHeadPaddingH
      Layout.rightMargin: Style.settingsHeadPaddingRight
    }

    NText {
      text: root.description
      pointSize: Style.fontSizeS
      font.weight: Style.fontWeightRegular
      color: Colors.onShellTertiary
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      visible: root.description !== ""
    }
  }

  Flow {
    Layout.fillWidth: true
    spacing: Style.marginXS
    flow: Flow.LeftToRight

    Repeater {
      model: [""].concat(root.tags)

      delegate: NButton {
        text: root.formatTag(modelData)
        backgroundColor: root.selectedTag === modelData ? Colors.overlay("checked") : Colors.overlay("field")
        textColor: root.selectedTag === modelData ? Colors.accent : Colors.onShellSecondary
        hoverColor: Colors.overlay("strong")
        textHoverColor: Colors.onShell
        onClicked: root.selectedTag = modelData
        fontSize: Style.fontSizeS
        iconSize: Style.fontSizeS
        fontWeight: Style.fontWeightRegular
        buttonRadius: Style.radiusItem
      }
    }
  }
}
