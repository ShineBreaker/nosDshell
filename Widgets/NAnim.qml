import QtQuick
import qs.Commons

// NumberAnimation on a DESIGN §1.7 curve. `curve` names an entry of
// Style.curves ("out", "swift", "snappy", ...); "linear" is the only other
// choice and is reserved for loops, timers and drag-follow. Components use
// this instead of writing easing.type, so every motion stays on the curve
// table (Scripts/dev/check-motion.py enforces it).
NumberAnimation {
  id: root

  property string curve: "out"

  easing.type: curve === "linear" ? Easing.Linear : Easing.BezierSpline
  easing.bezierCurve: curve === "linear" ? [] : (Style.curves[curve] || Style.curveOut)

  Component.onCompleted: {
    if (curve !== "linear" && !Style.curves[curve])
      Logger.w("NAnim", "unknown curve '" + curve + "', falling back to 'out'");
  }
}
