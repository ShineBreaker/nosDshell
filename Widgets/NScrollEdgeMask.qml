import QtQuick
import QtQuick.Effects
import qs.Commons

// Non-linear scroll edge fade (DESIGN §1.11; open-claude-ui
// cds-theme.css:196,820-821). Content still above or below the viewport
// dissolves over Style.scrollFadeSize px along 7 stops (.05/.15/.30/.50/.70/
// .85/1 opacity at 15/30/45/60/75/87/100 % of the zone); a side with nothing
// more to scroll gets no fade, and the zone grows with the scroll distance
// so the first pixels of a scroll do not jump. It is an alpha mask, so it
// works over translucent glass, unlike a strip painted in a guessed colour.
//
// Usage: the mask covers the masked item exactly and is NOT inside it (a
// layer whose mask is its own descendant samples itself and freezes).
//   NScrollEdgeMask { id: edge; anchors.fill: list; flickable: list; active: root.edgeFade }
//   ListView { id: list; layer.enabled: edge.needed; layer.effect: edge.effect }
Item {
  id: root

  property var flickable: null
  property bool active: true
  // Keep an edge solid, e.g. while a keyboard-selected row sits there.
  property bool holdTop: false
  property bool holdBottom: false

  readonly property real _scrolled: flickable ? flickable.contentY - flickable.originY : 0
  readonly property real _remaining: flickable ? flickable.contentHeight - flickable.height - _scrolled : 0
  readonly property real topFade: (active && !holdTop) ? Math.max(0, Math.min(Style.scrollFadeSize, _scrolled)) : 0
  readonly property real bottomFade: (active && !holdBottom) ? Math.max(0, Math.min(Style.scrollFadeSize, _remaining)) : 0
  readonly property real _topFrac: topFade / Math.max(1, height)
  readonly property real _bottomFrac: bottomFade / Math.max(1, height)
  // Only layer the content while some edge actually fades.
  readonly property bool needed: topFade > 0.5 || bottomFade > 0.5

  // MultiEffect maps mask alpha through a smoothstep (threshold 0.5, spread
  // 1, which is what makes partial alpha fade at all; the default thresholds
  // pass everything). The stop alphas are the inverse smoothstep of the CDS
  // values, so the rendered opacity follows the CDS curve.
  readonly property Component effect: Component {
    MultiEffect {
      maskEnabled: true
      maskSource: maskTexture
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }
  }

  Rectangle {
    id: maskShape
    anchors.fill: parent
    gradient: Gradient {
      GradientStop {
        position: root._topFrac * 0
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.0) : "white"
      }
      GradientStop {
        position: root._topFrac * 0.15
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.1354) : "white"
      }
      GradientStop {
        position: root._topFrac * 0.3
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.2444) : "white"
      }
      GradientStop {
        position: root._topFrac * 0.45
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.3633) : "white"
      }
      GradientStop {
        position: root._topFrac * 0.6
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.5) : "white"
      }
      GradientStop {
        position: root._topFrac * 0.75
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.6367) : "white"
      }
      GradientStop {
        position: root._topFrac * 0.87
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 0.7556) : "white"
      }
      GradientStop {
        position: root._topFrac * 1
        color: root.topFade > 0.5 ? Qt.rgba(1, 1, 1, 1.0) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 1
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 1.0) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0.87
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.7556) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0.75
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.6367) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0.6
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.5) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0.45
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.3633) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0.3
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.2444) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0.15
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.1354) : "white"
      }
      GradientStop {
        position: 1 - root._bottomFrac * 0
        color: root.bottomFade > 0.5 ? Qt.rgba(1, 1, 1, 0.0) : "white"
      }
    }
  }

  ShaderEffectSource {
    id: maskTexture
    anchors.fill: parent
    sourceItem: maskShape
    hideSource: true
    visible: false
  }
}
