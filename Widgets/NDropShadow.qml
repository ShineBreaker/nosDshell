import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services.Power

// Unified shadow system
Item {
  id: root

  required property var source

  // Optional per-instance shadow descriptor {blur, x, y, color} (see Style.shadow*)
  property var shadow: null

  property bool autoPaddingEnabled: false
  property real shadowHorizontalOffset: shadow ? shadow.x : Settings.data.general.shadowOffsetX
  property real shadowVerticalOffset: shadow ? shadow.y : Settings.data.general.shadowOffsetY
  property real shadowOpacity: shadow ? 1.0 : Style.shadowOpacity
  property color shadowColor: shadow ? shadow.color : "black"
  property real shadowBlur: shadow ? Math.min(1.0, shadow.blur / _blurMax) : Style.shadowBlur
  property real _blurMax: shadow ? Math.max(Style.shadowBlurMax, shadow.blur) : Style.shadowBlurMax

  // The shadow must never live inside its own source: the layer then samples
  // a subtree that contains its own output, feeds it back a frame later, and
  // the rendered shape drifts or deforms (notification bubbles showed exactly
  // this). Declare it as a sibling of the source, after it (see Toast.qml).
  // The layer is switched off in that case so the feedback cannot happen.
  property bool _insideSource: false

  function _checkSourcePlacement() {
    var bad = false;
    for (var p = root.parent; p; p = p.parent) {
      if (p === root.source) {
        bad = true;
        break;
      }
    }
    if (bad && !_insideSource) {
      Logger.e("NDropShadow", "shadow must not be inside its source; declare it as a sibling after the source (see Toast.qml)");
    }
    _insideSource = bad;
  }

  onSourceChanged: _checkSourcePlacement()
  Component.onCompleted: _checkSourcePlacement()

  layer.enabled: Settings.data.general.enableShadows && !PowerProfileService.performanceMode && !_insideSource
  layer.effect: MultiEffect {
    source: root.source
    shadowEnabled: true
    blurMax: root._blurMax
    shadowBlur: root.shadowBlur
    shadowOpacity: root.shadowOpacity
    shadowColor: root.shadowColor
    shadowHorizontalOffset: root.shadowHorizontalOffset
    shadowVerticalOffset: root.shadowVerticalOffset
    autoPaddingEnabled: root.autoPaddingEnabled
  }
}
