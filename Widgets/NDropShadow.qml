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

  layer.enabled: Settings.data.general.enableShadows && !PowerProfileService.noctaliaPerformanceMode
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
