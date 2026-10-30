import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services.Power

// Unified shadow system (DESIGN §1.6).
//
// Draws only the shadow, and only outside the source's silhouette — CSS
// box-shadow semantics, which the CDS shadow values assume. Each layer is a
// MultiEffect over a padded texture of the source with an inverted mask of
// that same texture, so the copy of the source the effect renders and the
// part of the shadow under the source are both cut away. The source itself
// stays where it is and is drawn exactly once: a translucent surface keeps
// the alpha of its §1.2 mask instead of being painted twice, and no dark
// block shows through it.
//
// Declare the shadow as a sibling of its source, after it, covering the same
// rect (anchors.fill: source, or the source's x/y/width/height). It must
// never live inside its source: the texture would then sample its own
// output (see _checkSourcePlacement).
Item {
  id: root

  required property var source

  // Shadow descriptor (see Style.shadow*): either two layers
  // {contact: {blur, x, y, color}, key: {blur, x, y, color}} or one layer
  // {blur, x, y, color}. null falls back to the general shadow settings.
  property var shadow: null

  // Kept for call-site compatibility; the padding is always derived from
  // the layers now, so the shadow never clips at the item edge.
  property bool autoPaddingEnabled: false

  readonly property var _legacyLayer: ({
                                         "blur": Style.shadowBlur * Style.shadowBlurMax,
                                         "x": Settings.data.general.shadowOffsetX,
                                         "y": Settings.data.general.shadowOffsetY,
                                         "color": Qt.rgba(0, 0, 0, Style.shadowOpacity)
                                       })
  readonly property var _layers: {
    if (!shadow)
      return [_legacyLayer];
    if (shadow.key)
      return shadow.contact ? [shadow.contact, shadow.key] : [shadow.key];
    return [shadow];
  }
  // Room for the farthest-reaching layer: blur radius plus offset.
  readonly property int _pad: {
    let p = 0;
    for (const l of _layers)
      p = Math.max(p, Math.ceil(l.blur + Math.max(Math.abs(l.x), Math.abs(l.y))) + 2);
    return p;
  }

  // The shadow must never live inside its own source: the texture then
  // samples a subtree that contains its own output, feeds it back a frame
  // later, and the rendered shape drifts or deforms (notification bubbles
  // showed exactly this). The effect is switched off in that case.
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

  // Gate on the internals, not on `visible`: callers bind visible
  // themselves (e.g. DesktopMediaPlayer hides it while scaling).
  readonly property bool _active: Settings.data.general.enableShadows && !PowerProfileService.performanceMode && !_insideSource && !!source

  ShaderEffectSource {
    id: padded
    sourceItem: root._active ? root.source : null
    hideSource: false
    visible: false
    // The texture extends _pad beyond the source on every side (transparent
    // there), so the shadow, the mask and the effect output share one rect.
    sourceRect: Qt.rect(-root._pad, -root._pad, root.width + 2 * root._pad, root.height + 2 * root._pad)
  }

  Repeater {
    model: root._active ? root._layers : []

    MultiEffect {
      required property var modelData

      x: -root._pad
      y: -root._pad
      width: root.width + 2 * root._pad
      height: root.height + 2 * root._pad
      source: padded
      autoPaddingEnabled: false

      shadowEnabled: true
      blurMax: Math.max(1, Math.round(modelData.blur))
      shadowBlur: 1.0
      shadowColor: modelData.color
      shadowOpacity: 1.0
      shadowHorizontalOffset: modelData.x
      shadowVerticalOffset: modelData.y

      maskEnabled: true
      maskInverted: true
      maskSource: padded
    }
  }
}
