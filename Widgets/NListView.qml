import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Templates as T
import qs.Commons

Item {
  id: root

  property color handleColor: Colors.overlay("checked")
  property color handleHoverColor: handleColor
  property color handlePressedColor: handleColor
  property color trackColor: "transparent"
  property real handleWidth: Math.round(4 * Style.uiScaleRatio)
  property real handleRadius: Style.radiusXXXS
  property int verticalPolicy: ScrollBar.AsNeeded
  property int horizontalPolicy: ScrollBar.AlwaysOff
  readonly property bool verticalScrollBarActive: {
    if (listView.ScrollBar.vertical.policy === ScrollBar.AlwaysOff)
      return false;
    return listView.contentHeight > listView.height;
  }
  readonly property bool contentOverflows: listView.contentHeight > listView.height
  // Horizontal lists overflow along X; the vertical-only name is kept for the
  // gradient/scrollbar logic which is a vertical-axis concern.
  readonly property bool horizontalOverflows: listView.orientation === ListView.Horizontal && listView.contentWidth > listView.width
  // Wheel should scroll whichever axis the list lays out on; when nothing can
  // move the event is swallowed below so it never falls through to a parent
  // scroller.
  readonly property bool wheelScrollable: horizontalOverflows || contentOverflows

  property bool showGradientMasks: true
  property color gradientColor: Colors.mSurfaceVariant
  // A fully transparent gradientColor switches the edge hint from "paint
  // surface color over the rows" to "fade the rows themselves out" — the only
  // fade that can end in nothing on a translucent surface.
  readonly property bool _fadeToTransparent: gradientColor.a === 0
  property int gradientHeight: 16
  property bool reserveScrollbarSpace: true

  // Keep scrollbars visible whenever overflow exists (without forcing visibility when not scrollable)
  property bool showScrollbarWhenScrollable: Settings.data.ui.scrollbarAlwaysVisible

  // Available width for content (excludes scrollbar space when reserveScrollbarSpace is true)
  readonly property real availableWidth: width - (reserveScrollbarSpace ? handleWidth + Style.marginXS : 0)

  // Forward ListView properties
  property alias model: listView.model
  property alias delegate: listView.delegate
  property alias spacing: listView.spacing
  property alias orientation: listView.orientation
  property alias currentIndex: listView.currentIndex
  property alias count: listView.count
  property alias contentHeight: listView.contentHeight
  property alias contentWidth: listView.contentWidth
  property alias contentY: listView.contentY
  property alias contentX: listView.contentX
  property alias currentItem: listView.currentItem
  property alias highlightItem: listView.highlightItem
  property alias headerItem: listView.headerItem
  property alias footerItem: listView.footerItem
  property alias section: listView.section
  property alias highlightFollowsCurrentItem: listView.highlightFollowsCurrentItem
  property alias highlightMoveDuration: listView.highlightMoveDuration
  property alias highlightMoveVelocity: listView.highlightMoveVelocity
  property alias preferredHighlightBegin: listView.preferredHighlightBegin
  property alias preferredHighlightEnd: listView.preferredHighlightEnd
  property alias highlightRangeMode: listView.highlightRangeMode
  property alias snapMode: listView.snapMode
  property alias keyNavigationWraps: listView.keyNavigationWraps
  property alias cacheBuffer: listView.cacheBuffer
  property alias displayMarginBeginning: listView.displayMarginBeginning
  property alias displayMarginEnd: listView.displayMarginEnd
  property alias layoutDirection: listView.layoutDirection
  property alias effectiveLayoutDirection: listView.effectiveLayoutDirection
  property alias verticalLayoutDirection: listView.verticalLayoutDirection
  property alias boundsBehavior: listView.boundsBehavior
  property alias flickableDirection: listView.flickableDirection
  property alias interactive: listView.interactive
  property alias moving: listView.moving
  property alias flicking: listView.flicking
  property alias dragging: listView.dragging
  property alias horizontalVelocity: listView.horizontalVelocity
  property alias verticalVelocity: listView.verticalVelocity
  property alias reuseItems: listView.reuseItems

  // Scroll speed multiplier for mouse wheel (1.0 = default, higher = faster)
  property real wheelScrollMultiplier: 2.0
  property int smoothWheelAnimationDuration: Style.animationNormal
  property real _wheelTargetY: 0
  property real _wheelTargetX: 0

  function clampScrollY(value) {
    return Math.max(0, Math.min(value, listView.contentHeight - listView.height));
  }

  function clampScrollX(value) {
    return Math.max(0, Math.min(value, listView.contentWidth - listView.width));
  }

  function applyWheelScroll(delta) {
    if (root.horizontalOverflows) {
      const step = delta * root.wheelScrollMultiplier;

      if (!Settings.data.general.smoothScrollEnabled || Style.reduceMotion) {
        listView.contentX = root.clampScrollX(listView.contentX - step);
        root._wheelTargetX = listView.contentX;
        return;
      }

      if (!wheelScrollAnimationX.running)
        root._wheelTargetX = listView.contentX;

      root._wheelTargetX = root.clampScrollX(root._wheelTargetX - step);
      wheelScrollAnimationX.to = root._wheelTargetX;
      wheelScrollAnimationX.duration = Style.motionScrollWheel;
      wheelScrollAnimationX.curve = "swift";
      wheelScrollAnimationX.restart();
      return;
    }
    if (!root.contentOverflows)
      return;

    const step = delta * root.wheelScrollMultiplier;

    if (!Settings.data.general.smoothScrollEnabled || Style.reduceMotion) {
      listView.contentY = root.clampScrollY(listView.contentY - step);
      root._wheelTargetY = listView.contentY;
      return;
    }

    if (!wheelScrollAnimation.running)
      root._wheelTargetY = listView.contentY;

    root._wheelTargetY = root.clampScrollY(root._wheelTargetY - step);
    wheelScrollAnimation.to = root._wheelTargetY;
    wheelScrollAnimation.duration = Style.motionScrollWheel;
    wheelScrollAnimation.curve = "swift";
    wheelScrollAnimation.restart();
  }

  function animateToContentY(targetY) {
    const clampedY = root.clampScrollY(targetY);

    if (!Settings.data.general.smoothScrollEnabled || Style.reduceMotion || listView.dragging || listView.flicking) {
      listView.contentY = clampedY;
      root._wheelTargetY = clampedY;
      return;
    }

    root._wheelTargetY = clampedY;
    wheelScrollAnimation.to = clampedY;
    wheelScrollAnimation.duration = Style.motionProgramScroll;
    wheelScrollAnimation.curve = "out";
    wheelScrollAnimation.restart();
  }

  // Forward ListView methods
  function positionViewAtIndex(index, mode) {
    const shouldAnimate = mode === ListView.Contain;
    if (!shouldAnimate) {
      listView.positionViewAtIndex(index, mode);
      root._wheelTargetY = listView.contentY;
      root._wheelTargetX = listView.contentX;
      return;
    }

    if (listView.orientation === ListView.Horizontal) {
      const previousX = listView.contentX;
      listView.positionViewAtIndex(index, mode);
      const targetX = root.clampScrollX(listView.contentX);

      if (Math.abs(targetX - previousX) < 0.5) {
        root._wheelTargetX = targetX;
        return;
      }

      listView.contentX = previousX;
      root._wheelTargetX = previousX;
      root.animateToContentX(targetX);
      return;
    }

    const previousY = listView.contentY;
    listView.positionViewAtIndex(index, mode);
    const targetY = root.clampScrollY(listView.contentY);

    if (Math.abs(targetY - previousY) < 0.5) {
      root._wheelTargetY = targetY;
      return;
    }

    listView.contentY = previousY;
    root._wheelTargetY = previousY;
    root.animateToContentY(targetY);
  }

  function animateToContentX(targetX) {
    const clampedX = root.clampScrollX(targetX);

    if (!Settings.data.general.smoothScrollEnabled || Style.reduceMotion || listView.dragging || listView.flicking) {
      listView.contentX = clampedX;
      root._wheelTargetX = clampedX;
      return;
    }

    root._wheelTargetX = clampedX;
    wheelScrollAnimationX.to = clampedX;
    wheelScrollAnimationX.duration = Style.motionProgramScroll;
    wheelScrollAnimationX.curve = "out";
    wheelScrollAnimationX.restart();
  }

  function positionViewAtBeginning() {
    listView.positionViewAtBeginning();
  }

  function positionViewAtEnd() {
    listView.positionViewAtEnd();
  }

  function forceLayout() {
    listView.forceLayout();
  }

  function cancelFlick() {
    listView.cancelFlick();
  }

  function flick(xVelocity, yVelocity) {
    listView.flick(xVelocity, yVelocity);
  }

  function incrementCurrentIndex() {
    listView.incrementCurrentIndex();
  }

  function decrementCurrentIndex() {
    listView.decrementCurrentIndex();
  }

  function indexAt(x, y) {
    return listView.indexAt(x, y);
  }

  function itemAt(x, y) {
    return listView.itemAt(x, y);
  }

  function itemAtIndex(index) {
    return listView.itemAtIndex(index);
  }

  // Set reasonable implicit sizes for Layout usage
  implicitWidth: 200
  implicitHeight: 200

  Component.onCompleted: {
    _wheelTargetY = listView.contentY;
    _wheelTargetX = listView.contentX;
    createGradients();
  }

  // Dynamically create gradient overlays
  function createGradients() {
    if (!showGradientMasks || root._fadeToTransparent)
      return;

    Qt.createQmlObject(`
      import QtQuick
      import qs.Commons
      Rectangle {
        x: 0
        y: 0
        width: root.availableWidth
        height: root.gradientHeight
        z: 1
        visible: root.showGradientMasks && root.contentOverflows
        opacity: {
          if (listView.contentY <= 1) return 0;
          if (listView.currentItem && listView.currentItem.y - listView.contentY < root.gradientHeight) return 0;
          return 1;
        }
        Behavior on opacity {
          NAnim { duration: Style.motionPointer; curve: "swift" }
        }
        gradient: Gradient {
          GradientStop { position: 0.0; color: root.gradientColor }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }
    `, root, "topGradient");

    Qt.createQmlObject(`
      import QtQuick
      import qs.Commons
      Rectangle {
        x: 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1
        width: root.availableWidth
        height: root.gradientHeight + 1
        z: 1
        visible: root.showGradientMasks && root.contentOverflows
        opacity: {
          if (listView.contentY + listView.height >= listView.contentHeight - 1) return 0;
          if (listView.currentItem && listView.currentItem.y + listView.currentItem.height > listView.contentY + listView.height - root.gradientHeight) return 0;
          return 1;
        }
        Behavior on opacity {
          NAnim { duration: Style.motionPointer; curve: "swift" }
        }
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 1.0; color: root.gradientColor }
        }
      }
    `, root, "bottomGradient");
  }

  // Fade-out mask used when gradientColor is transparent: a full-size opaque
  // field whose edge zones turn transparent under the same show/hide rules as
  // the overlay gradients, so rows dissolve instead of being painted over.
  Item {
    id: fadeMask
    opacity: 0
    layer.enabled: true
    layer.smooth: true
    width: listView.width
    height: listView.height

    readonly property bool topFade: {
      if (!root.contentOverflows)
        return false;
      if (listView.contentY <= 1)
        return false;
      if (listView.currentItem && listView.currentItem.y - listView.contentY < root.gradientHeight)
        return false;
      return true;
    }
    readonly property bool bottomFade: {
      if (!root.contentOverflows)
        return false;
      if (listView.contentY + listView.height >= listView.contentHeight - 1)
        return false;
      if (listView.currentItem && listView.currentItem.y + listView.currentItem.height > listView.contentY + listView.height - root.gradientHeight)
        return false;
      return true;
    }
    readonly property real fadeFrac: Math.min(0.4, (root.gradientHeight + 1) / Math.max(1, height))

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: fadeMask.topFade ? "transparent" : "white"
        }
        GradientStop {
          position: fadeMask.fadeFrac
          color: "white"
        }
        GradientStop {
          position: 1.0 - fadeMask.fadeFrac
          color: "white"
        }
        GradientStop {
          position: 1.0
          color: fadeMask.bottomFade ? "transparent" : "white"
        }
      }
    }
  }

  Component {
    id: fadeEffect
    MultiEffect {
      maskEnabled: true
      maskSource: fadeMask
    }
  }

  ListView {
    id: listView
    anchors.fill: parent
    anchors.rightMargin: root.reserveScrollbarSpace ? root.handleWidth + Style.marginXS : 0

    layer.enabled: root.showGradientMasks && root._fadeToTransparent
    layer.effect: root._fadeToTransparent ? fadeEffect : null

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    NAnim {
      id: wheelScrollAnimation
      target: listView
      property: "contentY"
      duration: root.smoothWheelAnimationDuration
      curve: "out"
    }

    NAnim {
      id: wheelScrollAnimationX
      target: listView
      property: "contentX"
      duration: root.smoothWheelAnimationDuration
      curve: "out"
    }

    onDraggingChanged: {
      if (dragging) {
        wheelScrollAnimation.stop();
        wheelScrollAnimationX.stop();
        root._wheelTargetY = contentY;
        root._wheelTargetX = contentX;
      }
    }

    onFlickingChanged: {
      if (flicking) {
        wheelScrollAnimation.stop();
        wheelScrollAnimationX.stop();
        root._wheelTargetY = contentY;
        root._wheelTargetX = contentX;
      }
    }

    onContentHeightChanged: root._wheelTargetY = root.clampScrollY(root._wheelTargetY)
    onHeightChanged: root._wheelTargetY = root.clampScrollY(root._wheelTargetY)
    onContentWidthChanged: root._wheelTargetX = root.clampScrollX(root._wheelTargetX)
    onWidthChanged: root._wheelTargetX = root.clampScrollX(root._wheelTargetX)

    ScrollBar.vertical: ScrollBar {
      parent: root
      x: root.mirrored ? 0 : root.width - width
      y: 0
      height: root.height
      policy: root.verticalPolicy
      visible: policy === ScrollBar.AlwaysOn || root.verticalScrollBarActive

      contentItem: Rectangle {
        implicitWidth: root.handleWidth
        implicitHeight: 100
        radius: root.handleRadius
        color: parent.pressed ? root.handlePressedColor : parent.hovered ? root.handleHoverColor : root.handleColor
        opacity: parent.policy === ScrollBar.AlwaysOn ? 1.0 : root.verticalScrollBarActive ? ((root.showScrollbarWhenScrollable || parent.active || parent.hovered) ? 1.0 : 0.0) : 0.0

        Behavior on opacity {
          NAnim {
            duration: Style.motionPointer
            curve: "swift"
          }
        }
      }

      background: Rectangle {
        implicitWidth: root.handleWidth
        implicitHeight: 100
        color: root.trackColor
        opacity: parent.policy === ScrollBar.AlwaysOn ? 0.3 : root.verticalScrollBarActive ? ((root.showScrollbarWhenScrollable || parent.active || parent.hovered) ? 0.3 : 0.0) : 0.0
        radius: root.handleRadius / 2

        Behavior on opacity {
          NAnim {
            duration: Style.motionPointer
            curve: "swift"
          }
        }
      }
    }
  }

  // Wheel scrolling goes through an item wheelEvent (MouseArea.onWheel), not
  // WheelHandler: PointerHandler wheel delivery never reaches handlers hosted
  // on the nosdshell-background layer surface under niri — the event enters
  // the window but wantsPointerEvent drops it before onWheel (verified via
  // qt.quick.pointer tracing). MouseArea.onWheel rides the same delivery path
  // as QQuickFlickable's own wheel handling, which works on every surface.
  // Parented to the root (not the content item) so it covers the viewport even
  // when content is smaller; NoButton keeps clicks/drags/hover flowing through
  // to the delegates. When nothing can scroll the event is swallowed so it
  // never falls through to a parent scroller.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: event => {
               if (!root.wheelScrollable) {
                 event.accepted = true;
                 return;
               }
               // Primary axis first; a horizontal list also accepts a vertical
               // wheel since that is what a plain mouse produces.
               const delta = listView.orientation === ListView.Horizontal ? (event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y !== 0 ? event.pixelDelta.y : (event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y) / 2) : (event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2);
               root.applyWheelScroll(delta);
               event.accepted = true;
             }
  }
}
