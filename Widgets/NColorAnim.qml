import QtQuick
import qs.Commons

// ColorAnimation on a DESIGN §1.7 curve; see NAnim for `curve`. Colour
// transitions default to "swift", the CDS curve for hover and state colours.
ColorAnimation {
  id: root

  property string curve: "swift"

  easing.type: curve === "linear" ? Easing.Linear : Easing.BezierSpline
  easing.bezierCurve: curve === "linear" ? [] : (Style.curves[curve] || Style.curveSwift)

  Component.onCompleted: {
    if (curve !== "linear" && !Style.curves[curve])
      Logger.w("NColorAnim", "unknown curve '" + curve + "', falling back to 'swift'");
  }
}
