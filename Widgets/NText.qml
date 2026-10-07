import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Text {
  id: root

  property bool richTextEnabled: false
  property bool markdownTextEnabled: false
  property string family: Settings.data.ui.fontDefault
  property real pointSize: Style.fontSizeM
  property bool applyUiScale: true
  property real fontScale: {
    const fontScale = (root.family === Settings.data.ui.fontDefault ? Settings.data.ui.fontDefaultScale : Settings.data.ui.fontFixedScale);
    if (applyUiScale) {
      return fontScale * Style.uiScaleRatio;
    }
    return fontScale;
  }
  property var features: ({})

  // Leaf dim contract: text dims itself when disabled unless an ancestor
  // composite already dims its whole subtree (autoDim: false) — without the
  // opt-out the two factors multiply and the text ends up near 0.36.
  property bool autoDim: true

  opacity: (enabled || !autoDim) ? 1.0 : 0.6
  font.family: root.family
  font.weight: Style.fontWeightMedium
  font.pointSize: Math.max(1, root.pointSize * fontScale)
  font.features: root.features
  color: Color.onShell
  elide: Text.ElideRight
  wrapMode: Text.NoWrap
  verticalAlignment: Text.AlignVCenter

  textFormat: {
    if (root.richTextEnabled) {
      return Text.RichText;
    } else if (root.markdownTextEnabled) {
      return Text.MarkdownText;
    }
    return Text.PlainText;
  }
}
