import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property string label: ""
  property string description: ""
  property string icon: ""
  property color labelColor: Color.onShell
  property color descriptionColor: Color.onShellTertiary
  property color iconColor: Color.onShell
  property bool showIndicator: false
  property string indicatorTooltip: ""
  property real labelSize: Style.fontSizeL
  // dcc rows use Regular(400) titles (DESIGN §3.5.4); everything else keeps
  // the SemiBold default.
  property int labelWeight: Style.fontWeightSemiBold

  // The label does not dim itself: its text/icon children each dim once
  // (blanket opacity here would multiply with NText's own factor). A
  // composite that dims the whole row can opt the children out via autoDim.
  property bool autoDim: true

  spacing: Style.marginXXS
  visible: root.label != "" || root.description != ""

  // Single-line width of the label row (icon + text). Rows that reserve a
  // title column use this as their minimumWidth so a squeezed field can
  // never wrap the label itself (descriptions may still wrap/elide).
  readonly property real labelImplicitWidth: labelRow.implicitWidth

  Layout.fillWidth: true

  RowLayout {
    id: labelRow
    spacing: Style.marginXS
    Layout.fillWidth: true
    visible: root.label !== ""

    NIcon {
      visible: root.icon !== ""
      icon: root.icon
      pointSize: Style.fontSizeXXL
      color: root.iconColor
      opacity: (enabled || !root.autoDim) ? 1.0 : 0.6
      Layout.rightMargin: Style.marginS
    }

    NText {
      id: labelText
      Layout.fillWidth: true
      text: root.label
      pointSize: root.labelSize
      font.weight: root.labelWeight
      color: labelColor
      wrapMode: Text.WordWrap
      autoDim: root.autoDim

      // Settings indicator dot positioned right after the text content
      Loader {
        active: root.showIndicator
        x: labelText.contentWidth + Style.marginXS
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: NSettingsIndicator {
          show: true
          tooltipText: root.indicatorTooltip || ""
        }
      }
    }
  }

  NText {
    visible: root.description !== ""
    Layout.fillWidth: true
    text: root.description
    pointSize: Style.fontSizeS
    color: root.descriptionColor
    autoDim: root.autoDim
    // DDE rows keep a uniform rhythm: at 352 px a 3-line description makes
    // every row a different height. Cap at two lines, eliding the tail.
    wrapMode: Text.WordWrap
    maximumLineCount: 2
    elide: Text.ElideRight
    textFormat: Text.StyledText
  }
}
