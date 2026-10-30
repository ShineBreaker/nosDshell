import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import qs.Commons

ScrollView {
  id: root

  property color handleColor: Colors.overlay("checked")
  property color handleHoverColor: handleColor
  property color handlePressedColor: handleColor
  property color trackColor: "transparent"
  property real handleWidth: Math.round(4 * Style.uiScaleRatio)
  property real handleRadius: Style.radiusXXXS
  property int verticalPolicy: ScrollBar.AsNeeded
  property int horizontalPolicy: ScrollBar.AsNeeded
  property bool preventHorizontalScroll: horizontalPolicy === ScrollBar.AlwaysOff
  property int boundsBehavior: Flickable.StopAtBounds
  readonly property bool verticalScrollable: (contentItem.contentHeight > contentItem.height) || (verticalPolicy == ScrollBar.AlwaysOn)
  readonly property bool horizontalScrollable: (contentItem.contentWidth > contentItem.width) || (horizontalPolicy == ScrollBar.AlwaysOn)
  // Non-linear edge fade where more content scrolls (DESIGN §1.11)
  property bool edgeFade: true
  property bool reserveScrollbarSpace: true
  property real userRightPadding: 0
  // Keep scrollbars visible whenever overflow exists (without forcing visibility when not scrollable)
  property bool showScrollbarWhenScrollable: Settings.data.ui.scrollbarAlwaysVisible

  // When false the internal Flickable never grabs presses for a drag: a real
  // mouse jitters a few pixels during a click, and an interactive flickable
  // reads that as a drag start and eats the click. Wheel scrolling is
  // unaffected (WheelHandler scrolls imperatively).
  property bool flickableInteractive: true

  // Scroll speed multiplier for mouse wheel (1.0 = default, higher = faster)
  property real wheelScrollMultiplier: 2.0
  property int smoothWheelAnimationDuration: Style.animationNormal
  property real _wheelTargetY: 0

  function clampScrollY(value) {
    if (!root._internalFlickable)
      return 0;
    const flickable = root._internalFlickable;
    return Math.max(0, Math.min(value, flickable.contentHeight - flickable.height));
  }

  function applyWheelScroll(delta) {
    if (!root._internalFlickable)
      return;

    const flickable = root._internalFlickable;
    const step = delta * root.wheelScrollMultiplier;

    if (!Settings.data.general.smoothScrollEnabled || Style.reduceMotion) {
      flickable.contentY = root.clampScrollY(flickable.contentY - step);
      root._wheelTargetY = flickable.contentY;
      return;
    }

    if (!wheelScrollAnimation.running)
      root._wheelTargetY = flickable.contentY;

    root._wheelTargetY = root.clampScrollY(root._wheelTargetY - step);
    wheelScrollAnimation.to = root._wheelTargetY;
    wheelScrollAnimation.duration = Style.motionScrollWheel;
    wheelScrollAnimation.curve = "swift";
    wheelScrollAnimation.restart();
  }

  rightPadding: userRightPadding + (reserveScrollbarSpace && verticalScrollable ? handleWidth + Style.marginXS : 0)

  implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth + leftPadding + rightPadding)
  implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

  // The edge-fade mask rides in the background slot (a plain child of a
  // ScrollView would become scroll content) and lines up with the flickable.
  // The layer goes on the flickable, not on the ScrollView: the mask texture
  // must not be a descendant of the layered item, or the layer samples itself
  // and stops repainting after the first frame.
  background: Item {
    NScrollEdgeMask {
      id: edgeMask
      x: root.contentItem.x - parent.x
      y: root.contentItem.y - parent.y
      width: root.contentItem.width
      height: root.contentItem.height
      flickable: root.contentItem
      active: root.edgeFade
    }
  }
  Binding {
    target: root.contentItem.layer
    property: "enabled"
    value: edgeMask.needed
  }
  Binding {
    target: root.contentItem.layer
    property: "effect"
    value: edgeMask.effect
  }

  // Configure the internal flickable when it becomes available
  Component.onCompleted: {
    configureFlickable();
  }

  // Reference to the internal Flickable for wheel handling
  property Flickable _internalFlickable: null

  NAnim {
    id: wheelScrollAnimation
    target: root._internalFlickable
    property: "contentY"
    duration: root.smoothWheelAnimationDuration
    curve: "out"
  }

  Connections {
    target: root._internalFlickable

    function onDraggingChanged() {
      if (!root._internalFlickable || !root._internalFlickable.dragging)
        return;
      wheelScrollAnimation.stop();
      root._wheelTargetY = root._internalFlickable.contentY;
    }

    function onFlickingChanged() {
      if (!root._internalFlickable || !root._internalFlickable.flicking)
        return;
      wheelScrollAnimation.stop();
      root._wheelTargetY = root._internalFlickable.contentY;
    }

    function onContentHeightChanged() {
      root._wheelTargetY = root.clampScrollY(root._wheelTargetY);
    }

    function onHeightChanged() {
      root._wheelTargetY = root.clampScrollY(root._wheelTargetY);
    }
  }

  // Function to configure the underlying Flickable
  function configureFlickable() {
    // Find the internal Flickable (it's usually the first child)
    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      if (child.toString().indexOf("Flickable") !== -1) {
        // Configure the flickable to prevent horizontal scrolling
        child.boundsBehavior = root.boundsBehavior;
        child.interactive = root.flickableInteractive;
        root._internalFlickable = child;

        // ScrollView keeps the internal flickable in automatic content-size
        // mode: contentWidth/contentHeight stay -1 while its native bounds
        // are derived from the content item's children, so every JS reader
        // (clampScrollY, the scrollable checks, the masks) saw an empty view.
        // Bind both to that same extent.
        child.contentHeight = Qt.binding(() => child.contentItem.childrenRect.height);

        if (root.preventHorizontalScroll) {
          child.flickableDirection = Flickable.VerticalFlick;
          child.contentWidth = Qt.binding(() => child.width);
        } else {
          child.contentWidth = Qt.binding(() => child.contentItem.childrenRect.width);
        }

        root._wheelTargetY = child.contentY;
        break;
      }
    }
  }

  // Item-level wheelEvent, not WheelHandler: PointerHandler wheel delivery is
  // dead on the nosdshell-background layer surface under niri (see NListView).
  // Declined events propagate to the content, so the flickable still handles
  // the wheel natively whenever this area lets it through. Declared children
  // land inside the flickable's content item, which scrolls with the content —
  // track the viewport rect so the overlay keeps covering it at any offset.
  // Stays below the declared content, so interactive rows keep first dibs on
  // the wheel and only dead areas route through applyWheelScroll.
  MouseArea {
    x: root._internalFlickable ? root._internalFlickable.contentX : 0
    y: root._internalFlickable ? root._internalFlickable.contentY : 0
    width: root._internalFlickable ? root._internalFlickable.width : parent.width
    height: root._internalFlickable ? root._internalFlickable.height : parent.height
    acceptedButtons: Qt.NoButton
    onWheel: event => {
               if (root.wheelScrollMultiplier === 1.0 || !root._internalFlickable) {
                 event.accepted = false;
                 return;
               }
               const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2;
               root.applyWheelScroll(delta);
               event.accepted = true;
             }
  }

  // Watch for changes in horizontalPolicy
  onHorizontalPolicyChanged: {
    preventHorizontalScroll = (horizontalPolicy === ScrollBar.AlwaysOff);
    configureFlickable();
  }

  ScrollBar.vertical: ScrollBar {
    parent: root
    x: root.mirrored ? 0 : root.width - width
    y: root.topPadding
    height: root.availableHeight
    policy: root.verticalPolicy
    interactive: root.verticalScrollable

    contentItem: Rectangle {
      implicitWidth: root.handleWidth
      implicitHeight: 100
      radius: root.handleRadius
      color: parent.pressed ? root.handlePressedColor : parent.hovered ? root.handleHoverColor : root.handleColor
      opacity: parent.policy === ScrollBar.AlwaysOn ? 1.0 : root.verticalScrollable ? ((root.showScrollbarWhenScrollable || parent.active || parent.hovered) ? 1.0 : 0.0) : 0.0

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
      opacity: parent.policy === ScrollBar.AlwaysOn ? 0.3 : root.verticalScrollable ? ((root.showScrollbarWhenScrollable || parent.active || parent.hovered) ? 0.3 : 0.0) : 0.0
      radius: root.handleRadius / 2

      Behavior on opacity {
        NAnim {
          duration: Style.motionPointer
          curve: "swift"
        }
      }
    }
  }

  ScrollBar.horizontal: ScrollBar {
    parent: root
    x: root.leftPadding
    y: root.height - height
    width: root.availableWidth
    policy: root.horizontalPolicy
    interactive: root.horizontalScrollable

    contentItem: Rectangle {
      implicitWidth: 100
      implicitHeight: root.handleWidth
      radius: root.handleRadius
      color: parent.pressed ? root.handlePressedColor : parent.hovered ? root.handleHoverColor : root.handleColor
      opacity: parent.policy === ScrollBar.AlwaysOn ? 1.0 : root.horizontalScrollable ? ((root.showScrollbarWhenScrollable || parent.active || parent.hovered) ? 1.0 : 0.0) : 0.0

      Behavior on opacity {
        NAnim {
          duration: Style.motionPointer
          curve: "swift"
        }
      }
    }

    background: Rectangle {
      implicitWidth: 100
      implicitHeight: root.handleWidth
      color: root.trackColor
      opacity: parent.policy === ScrollBar.AlwaysOn ? 0.3 : root.horizontalScrollable ? ((root.showScrollbarWhenScrollable || parent.active || parent.hovered) ? 0.3 : 0.0) : 0.0
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
