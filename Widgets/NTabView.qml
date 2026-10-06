import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
  id: root
  objectName: "NTabView"

  property int currentIndex: 0

  // DDE settings mode (DESIGN §3.5.3): every sub-tab is visible at once as its
  // own SettingsGroup, stacked vertically on one scrollable page. Switching to
  // a hidden sub-tab scrolls it into view instead of playing a slide transition.
  property bool stacked: false

  // Titles of the stacked groups, read from the sibling NTabBar in group mode.
  // The bar collapses itself in that mode, so it is the only place the labels
  // still live; NTabBar has no other way to reach a sibling view.
  property var stackTitles: []

  // Private
  property int previousIndex: 0
  property bool initialized: false
  property bool animating: false
  property real animatingHeight: 0
  property real transitionGap: Style.marginXL
  property real transitionTime: Style.animationNormal
  property list<Item> contentItems: []

  default property alias content: container.data

  clip: true
  Layout.fillWidth: true

  // A head is only drawn when the bar can name every page one-to-one.
  readonly property bool stackHeads: stacked && stackTitles.length === contentItems.length && contentItems.length > 0
  readonly property real stackHeadHeight: stackHeads ? Style.settingsHeadHeight + Style.settingsGroupSpacing : 0

  // During animation, use max height to prevent clipping. Otherwise use current item height.
  implicitHeight: {
    if (animating)
      return animatingHeight;
    if (!stacked)
      return contentItems[currentIndex] ? contentItems[currentIndex].implicitHeight : 0;
    let h = 0;
    for (let i = 0; i < contentItems.length; i++)
      h += contentItems[i].implicitHeight + root.stackHeadHeight;
    return h;
  }

  Item {
    id: container
    anchors.fill: parent
  }

  // One SettingsHead per stacked page, offset the same way the pages are. It
  // lives outside `container` so the page list stays exactly the children the
  // default property put there.
  Item {
    id: headLayer
    anchors.fill: parent

    Repeater {
      model: root.stackTitles

      delegate: NHeader {
        required property int index
        required property string modelData

        x: 0
        y: root._stackedOffset(index)
        width: root.width
        label: modelData
        visible: root.stackHeads
      }
    }
  }

  // Set the visible tab to idx without triggering a slide animation.
  // Call this BEFORE the bound currentIndex changes so that
  // onCurrentIndexChanged sees previousIndex === currentIndex and skips.
  function setIndexWithoutAnimation(idx) {
    fromXAnim.stop();
    fromOpacityAnim.stop();
    toXAnim.stop();
    toOpacityAnim.stop();
    animating = false;
    previousIndex = idx;
    for (let i = 0; i < contentItems.length; i++) {
      if (stacked || i === idx) {
        contentItems[i].x = 0;
        contentItems[i].visible = true;
        contentItems[i].opacity = 1.0;
      } else {
        contentItems[i].x = root.width;
        contentItems[i].visible = false;
        contentItems[i].opacity = 1.0;
      }
    }
  }

  // Deferred: children walks during async incubation can crash in the QV4 GC.
  Component.onCompleted: Qt.callLater(_initializeItems)

  // Position every sub-tab so they stack vertically. Each y is a binding so the
  // stack re-flows when an earlier page changes height.
  function _layoutStacked() {
    for (let i = 0; i < contentItems.length; i++) {
      const child = contentItems[i];
      child.y = Qt.binding(() => root._stackedOffset(i) + root.stackHeadHeight);
      child.visible = true;
    }
  }

  function _stackedOffset(index) {
    let off = 0;
    for (let j = 0; j < index; j++)
      off += (contentItems[j] ? contentItems[j].implicitHeight : 0) + root.stackHeadHeight;
    return off;
  }

  // Pick up the sub-tab titles from the sibling NTabBar. Both live in the same
  // tab component, so the lookup stops one level up.
  function _syncStackTitles() {
    const bar = _findTabBar();
    root.stackTitles = (bar && bar.groupMode === true) ? bar.groupTitles() : [];
  }

  function _findTabBar() {
    const p = parent;
    if (!p || !p.children)
      return null;
    for (let i = 0; i < p.children.length; i++) {
      const child = p.children[i];
      if (child && child.objectName === "NTabBar")
        return child;
    }
    return null;
  }

  function _initializeItems() {
    contentItems = [];
    for (let i = 0; i < container.children.length; i++) {
      const child = container.children[i];
      contentItems.push(child);
      child.width = Qt.binding(() => root.width);

      if (i === currentIndex) {
        child.x = 0;
        child.visible = true;
      } else {
        child.x = root.width;
        child.visible = false;
      }
    }
    if (stacked) {
      setIndexWithoutAnimation(currentIndex);
      _layoutStacked();
    }
    initialized = true;
  }

  onStackedChanged: {
    _syncStackTitles();
    if (!initialized)
      return;
    if (stacked) {
      setIndexWithoutAnimation(currentIndex);
      _layoutStacked();
    }
  }

  onCurrentIndexChanged: {
    if (stacked)
      _syncStackTitles();
    if (!initialized || contentItems.length === 0)
      return;
    if (stacked)
      return;
    if (previousIndex === currentIndex)
      return;

    _animateTransition(previousIndex, currentIndex);
    previousIndex = currentIndex;
  }

  function _animateTransition(fromIdx, toIdx) {
    // Stop any running animations
    fromXAnim.stop();
    fromOpacityAnim.stop();
    toXAnim.stop();
    toOpacityAnim.stop();

    // Reset all items to clean state (except target)
    for (let i = 0; i < contentItems.length; i++) {
      if (i !== toIdx) {
        contentItems[i].visible = false;
        contentItems[i].opacity = 1.0;
      }
    }

    const fromItem = contentItems[fromIdx];
    const toItem = contentItems[toIdx];
    const slideLeft = toIdx > fromIdx;

    // Set height to max of both items during animation
    const fromHeight = fromItem ? fromItem.implicitHeight : 0;
    const toHeight = toItem ? toItem.implicitHeight : 0;
    animatingHeight = Math.max(fromHeight, toHeight);
    animating = true;

    // Position outgoing item and make visible for animation
    if (fromItem) {
      fromItem.visible = true;
      fromItem.x = 0;
      fromItem.opacity = 1.0;
    }

    // Position incoming item off-screen (with gap) and set initial opacity
    if (toItem) {
      toItem.visible = true;
      toItem.x = slideLeft ? root.width + transitionGap : -root.width - transitionGap;
      toItem.opacity = 0.0;
    }

    // Animate both items together (with gap)
    if (fromItem) {
      fromXAnim.target = fromItem;
      fromXAnim.to = slideLeft ? -root.width - transitionGap : root.width + transitionGap;
      fromOpacityAnim.target = fromItem;
      fromXAnim.start();
      fromOpacityAnim.start();
    }

    if (toItem) {
      toXAnim.target = toItem;
      toOpacityAnim.target = toItem;
      toXAnim.start();
      toOpacityAnim.start();
    }
  }

  NumberAnimation {
    id: fromXAnim
    property: "x"
    duration: root.transitionTime
    easing.type: Easing.OutCubic
    onFinished: {
      if (target && target !== contentItems[currentIndex]) {
        target.visible = false;
        target.opacity = 1.0;
      }
      animating = false;
    }
  }

  NumberAnimation {
    id: fromOpacityAnim
    property: "opacity"
    to: 0.25
    duration: root.transitionTime
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: toXAnim
    property: "x"
    to: 0
    duration: root.transitionTime
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: toOpacityAnim
    property: "opacity"
    to: 1.0
    duration: root.transitionTime
    easing.type: Easing.OutCubic
  }
}
