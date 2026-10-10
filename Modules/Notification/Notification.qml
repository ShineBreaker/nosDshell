import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// DDE 15 notification bubble (DESIGN §3.6, gxde-session-ui dde-osd/notification):
// light mask surface, 300x70 base, app icon at (11,11), actions as a right
// strip. maxVisible = 1 (default) shows one bubble at a time.
Variants {

  model: {
    const screens = Quickshell.screens.filter(screen => Settings.data.notifications.monitors.includes(screen.name));
    // Empty list can mean two things :
    // - No (visible) notification display activated in settings
    // - One or more (not visible) displays are activated but unplugged
    // In both cases we fallback to show notification on all screens
    return screens.length === 0 ? Quickshell.screens : screens;
  }

  delegate: Loader {
    id: root
    required property ShellScreen modelData
    // modelData can hold a stale ShellScreen (PanelService.liveScreen)
    readonly property ShellScreen liveScreen: PanelService.liveScreen(modelData)
    property ListModel notificationModel: NotificationService.popupModel

    // Deferred activation via Qt.callLater to avoid activating the Loader
    // synchronously during ListModel.insert() (which would cause nested
    // incubation with the inner Repeater).
    property bool shouldBeActive: false
    active: shouldBeActive || delayTimer.running

    // Keep loader active briefly after last notification to allow animations to complete
    Timer {
      id: delayTimer
      interval: Style.motionBubbleOut + 200
      repeat: false
    }

    function activate() {
      shouldBeActive = true;
    }

    Connections {
      target: notificationModel
      function onCountChanged() {
        if (notificationModel.count > 0) {
          if (!root.shouldBeActive) {
            Qt.callLater(root.activate);
          }
        } else if (root.shouldBeActive) {
          root.shouldBeActive = false;
          delayTimer.restart();
        }
      }
    }

    sourceComponent: PanelWindow {
      id: notifWindow
      screen: root.liveScreen

      WlrLayershell.namespace: "nosdshell-notifications-" + (screen?.name || "unknown")
      WlrLayershell.layer: (Settings.data.notifications?.overlayLayer) ? WlrLayer.Overlay : WlrLayer.Top
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      color: "transparent"

      // Make shadow area click-through, only notification content is clickable
      mask: Region {
        x: 0
        y: 0
        width: notifWindow.width
        height: notifWindow.height
        intersection: Intersection.Xor

        Region {
          // The clickable content area is inset by shadowPadding from all edges
          x: notifWindow.shadowPadding
          y: notifWindow.shadowPadding
          width: notifWindow.notifWidth
          height: Math.max(0, notifWindow.height - notifWindow.shadowPadding * 2)
          intersection: Intersection.Subtract
        }
      }

      // Parse location setting
      readonly property string location: Settings.data.notifications.location || "top_right"
      readonly property bool isTop: location.startsWith("top")
      readonly property bool isBottom: location.startsWith("bottom")
      readonly property bool isLeft: location.endsWith("_left")
      readonly property bool isRight: location.endsWith("_right")
      readonly property bool isCentered: location === "top" || location === "bottom"

      readonly property bool hasBar: BarService.hasBarOnScreen(notifWindow.screen?.name)
      readonly property string barPos: hasBar ? Settings.getBarPositionForScreen(notifWindow.screen?.name) : ""
      readonly property bool isFloating: hasBar && Settings.getEffectiveBarType() === "floating"
      readonly property real barHeight: hasBar ? Style.getBarHeightForScreen(notifWindow.screen?.name) : 0

      readonly property bool isFramed: hasBar && Settings.getEffectiveBarType() === "framed"
      readonly property real frameThickness: Settings.data.bar.frameThickness ?? 8

      // Left of the control center when it is open (DESIGN §3.6,
      // dde-osd/notification/bubblemanager.cpp getX: bubbles sit left of the CC)
      readonly property var ccPanel: PanelService.getPanel("controlCenterPanel", notifWindow.screen)
      readonly property bool ccOpen: (ccPanel && ccPanel.isPanelOpen) || false
      readonly property real ccWidth: ccOpen ? 408 : 0

      // DDE bubble metrics — see Style §3.6 block
      readonly property int notifWidth: Style.bubbleBaseWidth
      readonly property int bubbleHeight: Style.bubbleBaseHeight
      readonly property int shadowPadding: Style.shadowBlurMax + Style.marginL

      // DDE keeps 20 px from the screen edge (bubblemanager.cpp getX/getY,
      // bubble.h Padding), and stacks bubbles 10 px apart when maxVisible > 1.
      readonly property int edgeOffset: Style.bubbleEdgeOffset

      // Calculate bar and frame offsets for each edge separately
      readonly property int barOffsetTop: {
        if (barPos !== "top")
          return isFramed ? frameThickness : 0;
        const floatMarginV = isFloating ? Math.ceil(Settings.data.bar.marginVertical) : 0;
        return barHeight + floatMarginV;
      }

      readonly property int barOffsetBottom: {
        if (barPos !== "bottom")
          return isFramed ? frameThickness : 0;
        const floatMarginV = isFloating ? Math.ceil(Settings.data.bar.marginVertical) : 0;
        return barHeight + floatMarginV;
      }

      readonly property int barOffsetLeft: {
        if (barPos !== "left")
          return isFramed ? frameThickness : 0;
        const floatMarginH = isFloating ? Math.ceil(Settings.data.bar.marginHorizontal) : 0;
        return barHeight + floatMarginH;
      }

      readonly property int barOffsetRight: {
        if (barPos !== "right")
          return isFramed ? frameThickness : 0;
        const floatMarginH = isFloating ? Math.ceil(Settings.data.bar.marginHorizontal) : 0;
        return barHeight + floatMarginH;
      }

      // Anchoring
      anchors.top: isTop
      anchors.bottom: isBottom
      anchors.left: isLeft
      anchors.right: isRight

      // Margins for PanelWindow - only apply bar offset for the specific edge where the bar is
      margins.top: isTop ? barOffsetTop - shadowPadding + edgeOffset : 0
      margins.bottom: isBottom ? barOffsetBottom - shadowPadding + edgeOffset : 0
      margins.left: isLeft ? barOffsetLeft - shadowPadding + edgeOffset : 0
      margins.right: isRight ? barOffsetRight - shadowPadding + edgeOffset + (ccOpen ? ccWidth : 0) : 0

      implicitWidth: notifWidth + shadowPadding * 2
      implicitHeight: notificationStack.implicitHeight + Style.marginL

      property var animateConnection: null

      Component.onCompleted: {
        animateConnection = function (notificationId) {
          var delegate = null;
          if (notificationRepeater) {
            for (var i = 0; i < notificationRepeater.count; i++) {
              var item = notificationRepeater.itemAt(i);
              if (item?.notificationId === notificationId) {
                delegate = item;
                break;
              }
            }
          }

          try {
            if (delegate && typeof delegate.animateOut === "function" && !delegate.isRemoving) {
              delegate.animateOut();
            }
          } catch (e) {
            // Service fallback if delegate is already invalid
            NotificationService.dismissPopup(notificationId);
          }
        };

        NotificationService.animateAndRemove.connect(animateConnection);
      }

      Component.onDestruction: {
        if (animateConnection) {
          NotificationService.animateAndRemove.disconnect(animateConnection);
          animateConnection = null;
        }
      }

      ColumnLayout {
        id: notificationStack

        anchors {
          top: parent.isTop ? parent.top : undefined
          bottom: parent.isBottom ? parent.bottom : undefined
          left: parent.isLeft ? parent.left : undefined
          right: parent.isRight ? parent.right : undefined
          horizontalCenter: parent.isCentered ? parent.horizontalCenter : undefined
        }

        spacing: Style.bubbleStackSpacing

        Repeater {
          id: notificationRepeater
          model: notificationModel

          delegate: Item {
            id: card

            property string notificationId: model.id
            property var notificationData: model
            property bool isHovered: false
            property bool isRemoving: false

            readonly property int animationDelay: index * 100
            readonly property real slideDistance: 12 // motionBubbleIn rise

            readonly property var actions: {
              try {
                return model.actionsJson ? JSON.parse(model.actionsJson) : [];
              } catch (e) {
                return [];
              }
            }

            // "default" is the click-body action and is not rendered as a button
            readonly property var visibleActions: actions.filter(a => a.identifier !== "default")

            Layout.preferredWidth: notifWindow.notifWidth + notifWindow.shadowPadding * 2
            Layout.preferredHeight: bubbleBody.height + notifWindow.shadowPadding * 2
            Layout.maximumHeight: Layout.preferredHeight

            // Animation properties
            property real opacityValue: 0.0
            property real slideOffset: 0
            // DDE entry slides the bubble in horizontally from the edge it is
            // anchored to (bubble.cpp: waylandEnterOffset -12→0 on rightMargin).
            property real enterOffset: 0
            property real swipeOffset: 0
            property real swipeOffsetY: 0
            property real pressGlobalX: 0
            property real pressGlobalY: 0
            property bool isSwiping: false
            property bool suppressClick: false
            readonly property bool useVerticalSwipe: notifWindow.location === "bottom" || notifWindow.location === "top"
            readonly property real swipeStartThreshold: Math.round(18 * Style.uiScaleRatio)
            readonly property real swipeDismissThreshold: Math.max(110, bubbleBody.width * 0.32)
            readonly property real verticalSwipeDismissThreshold: Math.max(70, bubbleBody.height * 0.35)

            opacity: opacityValue
            transform: Translate {
              x: card.swipeOffset + card.enterOffset
              y: card.slideOffset + card.swipeOffsetY
            }

            readonly property real slideInOffset: notifWindow.isTop ? -slideDistance : slideDistance
            readonly property real slideOutOffset: -slideDistance

            function clampSwipeDelta(deltaX) {
              if (notifWindow.isRight)
                return Math.max(0, deltaX);
              if (notifWindow.isLeft)
                return Math.min(0, deltaX);
              return deltaX;
            }

            function clampVerticalSwipeDelta(deltaY) {
              if (notifWindow.isBottom)
                return Math.max(0, deltaY);
              if (notifWindow.isTop)
                return Math.min(0, deltaY);
              return deltaY;
            }

            function triggerEntryAnimation() {
              animInDelayTimer.stop();
              enterSlideAnim.stop();
              enterXAnim.stop();
              removalTimer.stop();
              resumeTimer.stop();
              isRemoving = false;
              isHovered = false;
              isSwiping = false;
              swipeOffset = 0;
              swipeOffsetY = 0;
              slideOffset = 0;
              enterOffset = 0;
              if (Settings.data.general.animationDisabled) {
                opacityValue = 1.0;
                return;
              }

              opacityValue = 0.0;
              animInDelayTimer.interval = animationDelay;
              animInDelayTimer.start();
            }

            Component.onCompleted: triggerEntryAnimation()

            onNotificationIdChanged: triggerEntryAnimation()

            Timer {
              id: animInDelayTimer
              interval: 0
              repeat: false
              onTriggered: {
                if (card.isRemoving)
                  return;
                // Explicit from/to: arming the offset before the stagger delay
                // would let the Behavior drift, and a same-tick second write
                // would collapse the animation to 0→0.
                if (card.useVerticalSwipe) {
                  enterSlideAnim.from = card.slideInOffset;
                  enterSlideAnim.restart();
                } else {
                  enterXAnim.from = notifWindow.isLeft ? -card.slideDistance : card.slideDistance;
                  enterXAnim.restart();
                }
                card.opacityValue = 1.0;
              }
            }

            function animateOut() {
              if (isRemoving)
                return;
              animInDelayTimer.stop();
              enterSlideAnim.stop();
              enterXAnim.stop();
              resumeTimer.stop();
              isRemoving = true;
              isSwiping = false;
              swipeOffsetY = 0;
              if (!Settings.data.general.animationDisabled) {
                // DDE exits toward the screen edge the bubble hangs on
                // (bubble.cpp m_outAnimation: right-edge collapse, OutCubic).
                if (useVerticalSwipe) {
                  swipeOffset = 0;
                  slideOffset = slideOutOffset;
                } else {
                  slideOffset = 0;
                  swipeOffset = notifWindow.isLeft ? -(bubbleBody.width + Style.marginXL) : bubbleBody.width + Style.marginXL;
                }
                opacityValue = 0.0;
              }
            }

            function dismissBySwipe() {
              if (isRemoving)
                return;
              animInDelayTimer.stop();
              enterSlideAnim.stop();
              enterXAnim.stop();
              resumeTimer.stop();
              isRemoving = true;
              isSwiping = false;
              swipeOffset = 0;
              if (!Settings.data.general.animationDisabled) {
                if (useVerticalSwipe) {
                  swipeOffsetY = swipeOffsetY >= 0 ? bubbleBody.height + Style.marginXL : -bubbleBody.height - Style.marginXL;
                } else {
                  swipeOffset = swipeOffset >= 0 ? bubbleBody.width + Style.marginXL : -bubbleBody.width - Style.marginXL;
                  swipeOffsetY = 0;
                }
                opacityValue = 0.0;
              }
            }

            function runAction(actionId, isDismissed) {
              if (!isDismissed) {
                if (NotificationService.invokeActionAndSuppressClose(notificationId, actionId))
                  card.animateOut();
              } else {
                if (Settings.data.notifications.clearDismissed)
                  NotificationService.removeFromHistory(notificationId);
                card.animateOut();
              }
            }

            Timer {
              id: removalTimer
              interval: Style.motionBubbleOut
              repeat: false
              onTriggered: {
                NotificationService.dismissPopup(notificationId);
              }
            }

            onIsRemovingChanged: {
              if (isRemoving) {
                removalTimer.start();
              }
            }

            Behavior on opacity {
              enabled: !Settings.data.general.animationDisabled
              NumberAnimation {
                duration: card.isRemoving ? Style.motionBubbleOut : Style.motionBubbleIn
                easing.type: Easing.OutCubic
              }
            }

            Behavior on slideOffset {
              enabled: !Settings.data.general.animationDisabled
              NumberAnimation {
                duration: card.isRemoving ? Style.motionBubbleOut : Style.motionBubbleIn
                easing.type: Easing.OutCubic
              }
            }

            Behavior on enterOffset {
              enabled: !Settings.data.general.animationDisabled
              NumberAnimation {
                duration: Style.motionBubbleIn
                easing.type: Easing.OutCubic
              }
            }

            NumberAnimation {
              id: enterSlideAnim
              target: card
              property: "slideOffset"
              to: 0
              duration: Style.motionBubbleIn
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              id: enterXAnim
              target: card
              property: "enterOffset"
              to: 0
              duration: Style.motionBubbleIn
              easing.type: Easing.OutCubic
            }

            Behavior on swipeOffset {
              enabled: !Settings.data.general.animationDisabled && !card.isSwiping
              NumberAnimation {
                duration: card.isRemoving ? Style.motionBubbleOut : Style.animationFast
                easing.type: Easing.OutCubic
              }
            }

            Behavior on swipeOffsetY {
              enabled: !Settings.data.general.animationDisabled && !card.isSwiping
              NumberAnimation {
                duration: card.isRemoving ? Style.motionBubbleOut : Style.animationFast
                easing.type: Easing.OutCubic
              }
            }

            // The bubble itself (shadow area excluded from the clickable mask)
            Rectangle {
              id: bubbleBody
              anchors.centerIn: parent
              width: notifWindow.notifWidth
              height: contentColumn.implicitHeight + Style.margin2M
              radius: Style.radiusWindow
              color: Color.stackAlpha(Color.maskTransient, Color.adaptiveOpacity(Settings.data.notifications.backgroundOpacity) || 1.0)
              border.color: Color.stackAlpha(Color.borderTransient, Color.adaptiveOpacity(Settings.data.notifications.backgroundOpacity) || 1.0)
              border.width: Style.borderS

              NDropShadow {
                anchors.fill: parent
                source: bubbleBody
                autoPaddingEnabled: true
                shadow: Style.shadowBubble
              }

              // App / notification image at (11,11)
              NImageRounded {
                id: bubbleIcon
                x: Style.bubbleIconInset
                y: Style.bubbleIconInset
                width: Style.bubbleIconSize
                height: Style.bubbleIconSize
                radius: Style.radiusRow
                imagePath: model.originalImage || ""
                symbolicColor: Color.onTransient
                borderColor: "transparent"
                borderWidth: 0
                fallbackIcon: "bell"
                fallbackIconSize: Math.round(Style.fontSizeXXL * Style.uiScaleRatio)
              }

              // Text column: x=70, width 220 (150 when actions exist)
              ColumnLayout {
                id: contentColumn
                x: Style.bubbleTextInset
                y: Style.marginM
                width: notifWindow.notifWidth - Style.bubbleTextInset - (card.visibleActions.length > 0 ? Style.bubbleActionsWidth : Style.marginM)
                spacing: Style.marginXXXS

                // Title — onTransient Medium
                NText {
                  Layout.fillWidth: true
                  text: model.summary || I18n.tr("common.no-summary")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightMedium
                  color: Color.onTransient
                  textFormat: Text.StyledText
                  wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  maximumLineCount: 2
                  elide: Text.ElideRight
                  visible: text.length > 0
                }

                // Body — onTransientBody, at most 3 lines
                NText {
                  Layout.fillWidth: true
                  text: model.body || ""
                  pointSize: Style.fontSizeS
                  color: Color.onTransientBody
                  textFormat: Text.StyledText
                  wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  maximumLineCount: Style.bubbleMaxBodyLines
                  elide: Text.ElideRight
                  visible: text.length > 0
                }

                // App name + relative time
                NText {
                  Layout.fillWidth: true
                  text: (model.appName || "") + (model.appName ? " · " : "") + Time.formatRelativeTime(model.timestamp)
                  pointSize: Style.fontSizeXXS
                  color: Color.onTransientBody
                  elide: Text.ElideRight
                  visible: text.length > 0
                }
              }

              // Action strip on the right (70 px, accentAction text)
              ColumnLayout {
                id: actionStrip
                visible: card.visibleActions.length > 0
                x: bubbleBody.width - Style.bubbleActionsWidth
                y: 0
                width: Style.bubbleActionsWidth
                height: parent.height
                spacing: 0

                Repeater {
                  model: card.visibleActions

                  delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: actionArea.containsMouse ? Color.transientAction : "transparent"

                    NText {
                      anchors.centerIn: parent
                      width: parent.width - Style.marginXS
                      text: {
                        var actionText = modelData.text || "OK";
                        if (actionText.includes(","))
                          return actionText.split(",")[1] || actionText;
                        return actionText;
                      }
                      pointSize: Style.fontSizeS
                      color: actionArea.containsMouse ? "white" : Color.transientAction
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                      id: actionArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: card.runAction(modelData.identifier, false)
                    }
                  }
                }

                // 1 px separators between action buttons
                Repeater {
                  model: Math.max(0, card.visibleActions.length - 1)
                  delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Color.overlayTransient("hover")
                  }
                }
              }

              // Close × on hover, top-right
              NIconButton {
                id: closeButton
                icon: "close"
                tooltipText: I18n.tr("tooltips.dismiss-notification")
                baseSize: Style.baseWidgetSize * 0.6
                // Sits on a transient tile, not the shell — use the flipped
                // transient foreground (DESIGN §1.2)
                colorFg: Color.onTransientBody
                colorFgHover: Color.onTransient
                colorBgHover: Color.overlayTransient("hover")
                anchors.top: parent.top
                anchors.topMargin: Style.marginXS
                anchors.right: parent.right
                anchors.rightMargin: Style.marginXS
                opacity: card.isHovered ? 0.6 : 0
                visible: opacity > 0

                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }

                onClicked: card.runAction("", true)
              }

              HoverHandler {
                onHoveredChanged: {
                  card.isHovered = hovered;
                  if (hovered) {
                    resumeTimer.stop();
                    NotificationService.pauseTimeout(card.notificationId);
                  } else {
                    resumeTimer.start();
                  }
                }
              }

              Timer {
                id: resumeTimer
                interval: 50
                repeat: false
                onTriggered: {
                  if (!card.isHovered)
                    NotificationService.resumeTimeout(card.notificationId);
                }
              }

              // Click body = default action; drag to dismiss
              MouseArea {
                id: cardDragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                onPressed: mouse => {
                             if (mouse.button === Qt.LeftButton) {
                               const globalPoint = cardDragArea.mapToGlobal(mouse.x, mouse.y);
                               card.pressGlobalX = globalPoint.x;
                               card.pressGlobalY = globalPoint.y;
                               card.isSwiping = false;
                               card.suppressClick = false;
                             }
                           }
                onPositionChanged: mouse => {
                                     if (!(mouse.buttons & Qt.LeftButton) || card.isRemoving)
                                     return;
                                     const globalPoint = cardDragArea.mapToGlobal(mouse.x, mouse.y);
                                     const rawDeltaX = globalPoint.x - card.pressGlobalX;
                                     const rawDeltaY = globalPoint.y - card.pressGlobalY;
                                     const deltaX = card.clampSwipeDelta(rawDeltaX);
                                     const deltaY = card.clampVerticalSwipeDelta(rawDeltaY);
                                     if (!card.isSwiping) {
                                       if (card.useVerticalSwipe) {
                                         if (Math.abs(deltaY) < card.swipeStartThreshold)
                                         return;
                                         card.isSwiping = true;
                                       } else {
                                         if (Math.abs(deltaX) < card.swipeStartThreshold)
                                         return;
                                         card.isSwiping = true;
                                       }
                                       card.enterSlideAnim.stop();
                                       card.enterXAnim.stop();
                                     }
                                     if (card.useVerticalSwipe) {
                                       card.swipeOffset = 0;
                                       card.swipeOffsetY = deltaY;
                                     } else {
                                       card.swipeOffset = deltaX;
                                       card.swipeOffsetY = 0;
                                     }
                                   }
                onReleased: mouse => {
                              if (mouse.button === Qt.RightButton) {
                                card.animateOut();
                                if (Settings.data.notifications.clearDismissed)
                                NotificationService.removeFromHistory(card.notificationId);
                                return;
                              }

                              if (mouse.button !== Qt.LeftButton)
                              return;

                              if (card.isSwiping) {
                                const dismissDistance = card.useVerticalSwipe ? Math.abs(card.swipeOffsetY) : Math.abs(card.swipeOffset);
                                const threshold = card.useVerticalSwipe ? card.verticalSwipeDismissThreshold : card.swipeDismissThreshold;
                                if (dismissDistance >= threshold) {
                                  card.dismissBySwipe();
                                  if (Settings.data.notifications.clearDismissed)
                                  NotificationService.removeFromHistory(card.notificationId);
                                } else {
                                  card.swipeOffset = 0;
                                  card.swipeOffsetY = 0;
                                }
                                card.suppressClick = true;
                                card.isSwiping = false;
                                return;
                              }

                              if (card.suppressClick)
                              return;

                              const hasDefault = card.actions.some(a => a.identifier === "default");
                              if (hasDefault && NotificationService.invokeActionAndSuppressClose(card.notificationId, "default")) {
                                card.animateOut();
                              } else {
                                // Without a default action, or if invoking it fails,
                                // the best fallback is focusing the sender window.
                                NotificationService.focusSenderWindow(model.appName);
                                card.animateOut();
                              }
                            }
                onCanceled: {
                  card.isSwiping = false;
                  card.swipeOffset = 0;
                  card.swipeOffsetY = 0;
                }
              }
            }
          }
        }
      }
    }
  }
}
