import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Widgets

/**
* NotificationHistoryList - the notification history list, reusable.
*
* Extracted from Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml
* so the control-center notification page (DESIGN §3.5.2) and the standalone
* panel share one implementation. Interactions (expand/collapse, actions,
* swipe-dismiss, delete) are preserved; the visuals follow the tokens.
*
* Layout contract: give it a width and a bounded height (fillHeight in the
* host page) — the list virtualizes inside that height and owns its scrolling
* (upstream wrapped the same list in an NScrollView; the Flickable moved in
* here so delegates stay O(visible), not O(maxHistory)). `closeOnAction`
* closes the owning panel after a successful action invocation.
*/
Item {
  id: root

  property var screen: null
  property bool showClearAll: true
  property var closeOnAction: null
  property real leftMargin: Style.marginM
  property real rightMargin: Style.marginS

  property int currentRange: 0 // 0 = all
  property int focusIndex: -1
  property int actionIndex: -1
  property string expandedId: ""

  readonly property var historyModel: NotificationService.historyModel
  readonly property real layoutWidth: Math.max(1, root.width - root.leftMargin - root.rightMargin)

  function parseActions(actions) {
    try {
      return JSON.parse(actions || "[]");
    } catch (e) {
      return [];
    }
  }

  function dateOnly(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
  }

  function rangeForTimestamp(ts) {
    const dt = new Date(ts);
    const today = dateOnly(new Date());
    const thatDay = dateOnly(dt);
    const diffDays = Math.floor((today - thatDay) / (1000 * 60 * 60 * 24));
    if (diffDays === 0)
      return 0;
    if (diffDays === 1)
      return 1;
    return 2;
  }

  // Model-layer range filter: only matching notifications instantiate
  // delegates (a Repeater over the full history with visible:false would
  // still create up to maxHistory rich items). Roles stay live, so async
  // image-cache updates (setProperty) keep reaching the delegates.
  DelegateModel {
    id: visualModel
    model: root.historyModel
    groups: DelegateModelGroup {
      id: shownGroup
      name: "shown"
      includeByDefault: true
    }
    filterOnGroup: "shown"
  }

  function applyRangeFilter() {
    for (var i = 0; i < visualModel.items.count; i++) {
      const item = visualModel.items.get(i);
      if (item)
        item.inShown = root.isInCurrentRange(item.model.timestamp);
    }
  }

  onCurrentRangeChanged: {
    root.applyRangeFilter();
    focusIndex = -1;
    actionIndex = -1;
  }
  // Late arrivals (history loaded from disk after startup) default to shown;
  // filter once they land.
  Component.onCompleted: Qt.callLater(root.applyRangeFilter)

  Connections {
    target: root.historyModel
    function onCountChanged() {
      // New arrivals default to shown; re-filter in the same frame.
      root.applyRangeFilter();
      if (root.focusIndex >= notificationList.count)
        root.focusIndex = notificationList.count - 1;
    }
  }

  function isInCurrentRange(ts) {
    if (currentRange === 0)
      return true;
    return rangeForTimestamp(ts) === (currentRange - 1);
  }

  function hasNotificationsInCurrentRange() {
    const m = NotificationService.historyModel;
    if (!m || m.count === 0)
      return false;
    for (var i = 0; i < m.count; ++i) {
      const item = m.get(i);
      if (item && isInCurrentRange(item.timestamp))
        return true;
    }
    return false;
  }

  implicitHeight: mainColumn.implicitHeight

  function invokeAndClose(id, actionId) {
    if (NotificationService.invokeAction(id, actionId) && root.closeOnAction)
      root.closeOnAction();
  }

  // Keyboard model (upstream NotificationHistoryPanel.qml): Tab/Backtab cycles
  // ranges, up/down moves the selection, left/right walks the focused item's
  // actions, Enter activates, keyRemove/Delete dismisses. focusIndex is a
  // *visual* index — delegates only exist for the current range filter, so no
  // hidden items need skipping the way the upstream full-model scan did.
  focus: true
  onVisibleChanged: {
    if (visible)
      root.forceActiveFocus();
  }

  Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                      currentRange = (currentRange + 1) % 4;
                      event.accepted = true;
                      return;
                    }
                    if (event.key === Qt.Key_Backtab) {
                      currentRange = (currentRange - 1 + 4) % 4;
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'up', Settings)) {
                      moveSelection(-1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'down', Settings)) {
                      moveSelection(1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'left', Settings)) {
                      moveAction(-1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'right', Settings)) {
                      moveAction(1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'enter', Settings)) {
                      activateSelection();
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'remove', Settings) || event.key === Qt.Key_Delete) {
                      removeSelection();
                      event.accepted = true;
                      return;
                    }
                  }

  // Visible delegate lookup for the keyboard model; the ListView instantiates
  // only what is on screen, so positionViewAtIndex (moveSelection) keeps the
  // focused row instantiated before the next key press reads it.
  function delegateAt(visualIndex) {
    return notificationList.itemAtIndex(visualIndex);
  }

  function moveSelection(dir) {
    var count = notificationList.count;
    if (count === 0)
      return;

    var newIndex = focusIndex;
    if (newIndex === -1)
      newIndex = dir > 0 ? -1 : count;

    newIndex += dir;
    if (newIndex < 0 || newIndex >= count)
      return;

    focusIndex = newIndex;
    actionIndex = -1;
    notificationList.positionViewAtIndex(focusIndex, ListView.Contain);
  }

  function moveAction(dir) {
    var delegate = delegateAt(focusIndex);
    if (!delegate)
      return;
    var count = delegate.actionsList.length;
    if (count === 0)
      return;
    actionIndex = Math.max(-1, Math.min(actionIndex + dir, count - 1));
  }

  function activateSelection() {
    var delegate = delegateAt(focusIndex);
    if (!delegate)
      return;

    if (actionIndex >= 0 && actionIndex < delegate.actionsList.length) {
      var action = delegate.actionsList[actionIndex];
      if (action.identifier === "default")
        return;
      invokeAndClose(delegate.notificationId, action.identifier);
      return;
    }
    if (!(delegate.canExpand || delegate.isExpanded))
      return;
    root.expandedId = delegate.isExpanded ? "" : delegate.notificationId;
  }

  function removeSelection() {
    var delegate = delegateAt(focusIndex);
    if (delegate)
      delegate.remove();
  }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    spacing: Style.marginS

    // Clear-all row (DESIGN §3.5.2): flat text button, overlay("idle"), padding 4
    Item {
      Layout.fillWidth: true
      implicitHeight: clearAll.implicitHeight
      visible: root.showClearAll && NotificationService.historyModel.count > 0

      Rectangle {
        id: clearAll
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: clearAllText.implicitWidth + Style.margin2S
        implicitHeight: clearAllText.implicitHeight + Style.margin2XS
        radius: Style.radiusRow
        color: Color.overlay("idle")

        NText {
          id: clearAllText
          anchors.centerIn: parent
          text: I18n.tr("actions.clear-history")
          pointSize: Style.fontSizeS
          color: Color.onShellSecondary
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: NotificationService.clearHistory()
        }

        Behavior on color {
          enabled: !Color.isTransitioning
          ColorAnimation {
            duration: Style.animationFast
          }
        }
      }
    }

    // Empty state (centered, onShellTertiary)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.marginXL * 6
      visible: !root.hasNotificationsInCurrentRange()

      NText {
        anchors.centerIn: parent
        text: I18n.tr("notifications.panel.no-notifications")
        pointSize: Style.fontSizeM
        color: Color.onShellTertiary
      }
    }

    // The list itself: virtualized (delegates are O(visible), not
    // O(maxHistory)); the slide-out of a removing row stays inside the clip.
    Item {
      id: listBox
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      visible: root.hasNotificationsInCurrentRange()

      NListView {
        id: notificationList
        anchors.fill: parent
        spacing: Style.marginS
        reuseItems: true
        gradientColor: "transparent"
        reserveScrollbarSpace: false
        boundsBehavior: Flickable.StopAtBounds
        model: visualModel

        delegate: Item {
          id: delegateItem
          width: notificationList.width
          height: contentColumn.implicitHeight + Style.margin2S

          readonly property string notificationId: model.id
            readonly property string appName: model.appName || ""
            readonly property bool isExpanded: root.expandedId === notificationId
            readonly property bool canExpand: summaryText.truncated || bodyText.truncated
            readonly property var actionsList: root.parseActions(model.actionsJson)
            readonly property bool isFocused: index === root.focusIndex
            readonly property int removeAnimationDuration: Style.animationNormal
            readonly property int iconSize: Math.round(24 * Style.uiScaleRatio)
            readonly property bool hasActions: actionsList.some(a => a.identifier !== "default")
            readonly property bool markdownEnabled: Settings.data.notifications.enableMarkdown
            readonly property int textFormat: (markdownEnabled && isExpanded) ? Text.MarkdownText : Text.StyledText
            readonly property string summary: model.summary || I18n.tr("common.no-summary")
            readonly property string body: model.body || ""

            function remove() {
              if (isRemoving)
                return;
              isRemoving = true;
              if (Settings.data.general.animationDisabled) {
                NotificationService.removeFromHistory(notificationId);
                return;
              }
              removeTimer.restart();
            }

            property bool isRemoving: false
            // Item recycling (reuseItems) keeps plain properties across
            // rebinds: reset the remove-slide state when this instance is
            // rebind to another notification.
            onNotificationIdChanged: isRemoving = false

            Timer {
              id: removeTimer
              interval: delegateItem.removeAnimationDuration
              repeat: false
              onTriggered: NotificationService.removeFromHistory(delegateItem.notificationId)
            }

            // Deleting slides the row out along the width axis
            // (gxde-control-center notifymodel.cpp: timerEvent, 20 px/10 ms);
            // the reflow after removal is instant, no height collapse.
            x: isRemoving ? width : 0

            Behavior on x {
              enabled: !Settings.data.general.animationDisabled && delegateItem.isRemoving
              NumberAnimation {
                duration: delegateItem.removeAnimationDuration
                easing.type: Easing.OutCubic
              }
            }

            // Item surface: white text, overlay("strong"), radiusItem (DESIGN §3.5.2)
            Rectangle {
              anchors.fill: parent
              radius: Style.radiusItem
              color: Color.overlay("strong")
              border.color: delegateItem.isFocused ? Color.accent : "transparent"
              border.width: Style.borderS
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.focusIndex = index;
                root.actionIndex = -1;
                root.expandedId = (delegateItem.canExpand || delegateItem.isExpanded) ? (delegateItem.isExpanded ? "" : notificationId) : "";
              }
            }

            HoverHandler {
              id: hoverHandler
              target: parent
            }

            RowLayout {
              id: contentColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.marginS
              spacing: Style.marginS

              NImageRounded {
                Layout.preferredWidth: delegateItem.iconSize
                Layout.preferredHeight: delegateItem.iconSize
                Layout.alignment: Qt.AlignTop
                radius: Math.min(Style.radiusRow, width / 2)
                imagePath: model.cachedImage || model.originalImage || ""
                borderColor: "transparent"
                borderWidth: 0
                fallbackIcon: "bell"
                fallbackIconSize: 24
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NText {
                    text: delegateItem.appName || "Unknown App"
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightMedium
                    color: Color.onShell
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  NText {
                    textFormat: Text.PlainText
                    text: Time.formatRelativeTime(model.timestamp)
                    pointSize: Style.fontSizeXXS
                    color: Color.onShellTertiary
                  }
                }

                NText {
                  id: summaryText
                  Layout.fillWidth: true
                  text: (delegateItem.markdownEnabled && delegateItem.isExpanded) ? (model.summaryMarkdown || I18n.tr("common.no-summary")) : delegateItem.summary
                  pointSize: Style.fontSizeM
                  color: Color.onShell
                  textFormat: delegateItem.textFormat
                  wrapMode: Text.Wrap
                  maximumLineCount: delegateItem.isExpanded ? 999 : 2
                  elide: Text.ElideRight
                }

                NText {
                  id: bodyText
                  Layout.fillWidth: true
                  text: (delegateItem.markdownEnabled && delegateItem.isExpanded) ? (model.bodyMarkdown || "") : delegateItem.body
                  pointSize: Style.fontSizeS
                  color: Color.onShellSecondary
                  textFormat: delegateItem.textFormat
                  wrapMode: Text.Wrap
                  maximumLineCount: delegateItem.isExpanded ? 999 : 3
                  elide: Text.ElideRight
                  visible: text.length > 0
                }

                // Actions as flat text buttons in accentAlt (DESIGN §3.5.2)
                Flow {
                  Layout.fillWidth: true
                  visible: delegateItem.hasActions
                  spacing: Style.marginS

                  Repeater {
                    model: delegateItem.actionsList

                    delegate: NText {
                      readonly property bool isDefault: modelData.identifier === "default"
                      text: modelData.text
                      pointSize: Style.fontSizeS
                      color: (delegateItem.isFocused && root.actionIndex === index) ? Color.accent : Color.accentAlt
                      font.weight: (delegateItem.isFocused && root.actionIndex === index) ? Style.fontWeightSemiBold : Style.fontWeightNormal
                      visible: !isDefault

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                          root.focusIndex = delegateItem.index;
                          root.actionIndex = index;
                          root.invokeAndClose(delegateItem.notificationId, modelData.identifier);
                        }
                      }
                    }
                  }
                }
              }
            }

            // Close × revealed on hover, overlaid on the card top-right so the
            // timestamp can use the full row width (gxde notifydelegate.cpp:
            // the button floats over the item instead of reserving a slot).
            NIconButton {
              id: closeButton
              anchors.right: delegateItem.right
              anchors.top: delegateItem.top
              anchors.margins: Style.marginXS
              z: 1
              baseSize: Style.baseWidgetSize * 0.7
              applyUiScale: false
              visible: opacity > 0
              opacity: hoverHandler.hovered ? 1 : 0
              icon: "x"
              colorFg: Color.onShellTertiary
              colorBg: "transparent"
              colorBgHover: Color.overlay("hover")
              colorFgHover: Color.onShell
              tooltipText: I18n.tr("tooltips.dismiss-notification")
              onClicked: delegateItem.remove()
            }
          }
        }
      }
    }
  }
