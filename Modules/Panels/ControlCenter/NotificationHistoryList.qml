import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
*
* View model (DESIGN §3.5.2): the list header, the day sections and the
* per-app groups are folded into one flat descriptor array — `header` /
* `section` / `notif` rows — built from NotificationService.historyModel, so
* the whole content block travels with the top-anchored notifications. A
* notification row carries only its source index and precomputed group facts;
* the delegate reads the entry off `_historyRows`, a plain-dict mirror the
* service-model Connections rebuild on every mutation — binding-side
* `historyModel.get()`/`model.<role>` reads capture the live row proxy and
* crash on the next insert (DESIGN §1.7). The mirror rebuild still lets the
* async image cache (setProperty on cachedImage) reach the delegates.
* Rows hold no QObject references, so nothing here can dangle.
*
* The upstream invisible Tab range filter (currentRange / Keys.onTabPressed /
* isInCurrentRange / rangeForTimestamp) is gone: the day sections are rendered
* rows now.
*
* Expand state: the per-notification text expand is keyed by notification id
* (upstream expandedId); the per-group expand is keyed by the group, which is
* scoped to its day section so the same app in two sections expands
* independently.
*/
Item {
  id: root

  property var screen: null
  property var closeOnAction: null
  property real leftMargin: Style.marginM
  property real rightMargin: Style.marginS

  // Expanded state: notification id (truncated text) / group key.
  property string expandedNotification: ""
  property string expandedGroup: ""

  // Keyboard focus: index into the descriptor row space (-1 = none), plus
  // which action button of the focused row is active (-1 = the body).
  property int focusIndex: -1
  property int actionIndex: -1

  readonly property var historyModel: NotificationService.historyModel

  // Plain-dict mirror for binding-side reads. historyModel.get()/model.<role>
  // inside bindings capture the live row proxy and crash in
  // QQmlListModel::data→captureProperty on the next insert/setProperty
  // (DESIGN §1.7). Rebuilt from JS handlers only.
  property var _historyRows: []

  function _rebuildHistoryRows() {
    const m = NotificationService.historyModel;
    const rows = [];
    for (var i = 0; m && i < m.count; i++) {
      const r = m.get(i);
      rows.push({
                  "id": r.id,
                  "appName": r.appName,
                  "summary": r.summary,
                  "summaryMarkdown": r.summaryMarkdown,
                  "body": r.body,
                  "bodyMarkdown": r.bodyMarkdown,
                  "actionsJson": r.actionsJson,
                  "cachedImage": r.cachedImage,
                  "originalImage": r.originalImage,
                  "timestamp": r.timestamp,
                  "urgency": r.urgency
                });
    }
    _historyRows = rows;
  }

  Component.onCompleted: _rebuildHistoryRows()

  Connections {
    target: NotificationService.historyModel
    function onCountChanged() {
      root._rebuildHistoryRows();
    }
    function onDataChanged() {
      root._rebuildHistoryRows();
    }
  }

  function _entryAt(modelIndex) {
    return (modelIndex >= 0 && modelIndex < _historyRows.length) ? _historyRows[modelIndex] : null;
  }

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

  // 0 = today, 1 = yesterday, 2 = earlier (DESIGN §3.5.2).
  function dayBucket(ts) {
    const diffDays = Math.round((dateOnly(new Date()) - dateOnly(new Date(ts))) / 86400000);
    if (diffDays <= 0)
      return 0;
    if (diffDays === 1)
      return 1;
    return 2;
  }

  function bucketTitle(bucket) {
    if (bucket === 1)
      return I18n.tr("notifications.panel.section-yesterday");
    if (bucket >= 2)
      return I18n.tr("notifications.panel.section-earlier");
    return I18n.tr("notifications.panel.section-today");
  }

  // Group keys are scoped to their day section: the same app can appear in
  // both "today" and "yesterday", and each occurrence is its own group.
  function groupKeyFor(bucket, appName) {
    return bucket + "|" + (appName || "");
  }

  function groupAppName(key) {
    const sep = key.indexOf("|");
    return sep < 0 ? key : key.slice(sep + 1);
  }

  function groupBucket(key) {
    const sep = key.indexOf("|");
    return sep < 0 ? 0 : parseInt(key.slice(0, sep));
  }

  // Flat row space over the live model: the list header, one section header
  // per day bucket, then one row per notification. Two passes — group sizes
  // are only final after the whole model has been walked, and the delegate
  // reads them off the row instead of re-deriving them.
  readonly property var descriptors: {
    const rows = [];
    if (_historyRows.length === 0)
      return rows;

    rows.push({
                kind: "header"
              });

    // All same-app notifications inside one day bucket share a group, no
    // matter how they interleave with other apps (DESIGN §3.5.2). A group
    // renders where its newest member sits — the model runs newest-first —
    // so groups themselves stay in latest-activity order.
    let bucket = -1;
    let groups = [];
    let slotOf = {};
    const groupCounts = {};
    const flushBucket = () => {
      for (const g of groups) {
        groupCounts[rows.length] = g.members.length;
        rows.push({
                    kind: "group",
                    groupKey: g.key,
                    bucket: g.bucket
                  });
        for (const mi of g.members)
        rows.push({
                    kind: "notif",
                    modelIndex: mi,
                    groupKey: g.key,
                    bucket: g.bucket
                  });
      }
    };
    for (var i = 0; i < _historyRows.length; i++) {
      const entry = _historyRows[i];
      const rowBucket = root.dayBucket(entry.timestamp);
      if (rowBucket !== bucket) {
        flushBucket();
        bucket = rowBucket;
        groups = [];
        slotOf = {};
        rows.push({
                    kind: "section",
                    bucket: bucket
                  });
      }
      const rowKey = root.groupKeyFor(bucket, entry.appName);
      if (!(rowKey in slotOf)) {
        slotOf[rowKey] = groups.length;
        groups.push({
                      key: rowKey,
                      bucket: bucket,
                      members: []
                    });
      }
      groups[slotOf[rowKey]].members.push(i);
    }
    flushBucket();

    // Second pass: fill in the final group size and the head flag.
    let currentGroup = -1;
    let seen = 0;
    for (var j = 0; j < rows.length; j++) {
      if (rows[j].kind === "group") {
        currentGroup = j;
        seen = 0;
        continue;
      }
      if (rows[j].kind !== "notif")
        continue;
      seen++;
      rows[j].groupSize = groupCounts[currentGroup];
      rows[j].isHead = seen === 1;
    }
    return rows;
  }

  // Rows the keyboard walks: notifications only, and a collapsed group
  // contributes its newest row alone.
  readonly property var visibleRows: {
    const rows = root.descriptors;
    const out = [];
    for (var i = 0; i < rows.length; i++) {
      const row = rows[i];
      if (row.kind !== "notif")
        continue;
      if (row.groupSize === 1 || row.isHead || root.expandedGroup === row.groupKey)
        out.push(row);
    }
    return out;
  }

  // The list is top-anchored: down moves towards older notifications.
  function moveSelection(dir) {
    const rows = root.visibleRows;
    if (rows.length === 0)
      return;

    let current = -1;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].modelIndex === root.rowModelIndex(root.focusIndex)) {
        current = i;
        break;
      }
    }
    let next = current === -1 ? (dir > 0 ? -1 : rows.length) : current;
    next += dir;
    if (next < 0 || next >= rows.length)
      return;

    root.focusIndex = root.rowIndexOf(rows[next]);
    root.actionIndex = -1;
    notificationList.positionViewAtIndex(root.focusIndex, ListView.Contain);
  }

  // focusIndex is a row-space index; the delegates are keyed by it, so the
  // model-index lookups below only serve the keyboard's bookkeeping.
  function rowModelIndex(rowIndex) {
    const rows = root.descriptors;
    return rowIndex >= 0 && rowIndex < rows.length && rows[rowIndex].kind === "notif" ? rows[rowIndex].modelIndex : -1;
  }

  function rowIndexOf(row) {
    const rows = root.descriptors;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === "notif" && rows[i].modelIndex === row.modelIndex)
        return i;
    }
    return -1;
  }

  function delegateAt(rowIndex) {
    return notificationList.itemAtIndex(rowIndex);
  }

  function moveAction(dir) {
    const delegate = root.delegateAt(root.focusIndex);
    if (!delegate)
      return;
    const count = delegate.actionsList.length;
    if (count === 0)
      return;
    root.actionIndex = Math.max(-1, Math.min(root.actionIndex + dir, count - 1));
  }

  // Enter (DESIGN §3.5.2): active action, then collapse the open group, then
  // open a collapsed group, then expand truncated text, then the primary
  // action.
  function activateSelection() {
    const delegate = root.delegateAt(root.focusIndex);
    if (!delegate)
      return;

    if (root.actionIndex >= 0 && root.actionIndex < delegate.actionsList.length) {
      const action = delegate.actionsList[root.actionIndex];
      if (action.identifier !== "default")
        root.invokeAndClose(delegate.notificationId, action.identifier);
      return;
    }
    if (delegate.isGroupExpanded) {
      root.expandedGroup = "";
      return;
    }
    if (delegate.groupSize > 1) {
      root.expandedGroup = delegate.groupKey;
      return;
    }
    if (delegate.canExpand) {
      root.expandedNotification = delegate.notificationId;
      return;
    }
    root.invokeDefault(delegate.notificationId, delegate.appName);
  }

  function removeSelection() {
    const delegate = root.delegateAt(root.focusIndex);
    if (delegate)
      delegate.dismiss(0);
  }

  function invokeAndClose(id, actionId) {
    if (NotificationService.invokeAction(id, actionId) && root.closeOnAction)
      root.closeOnAction();
  }

  // Body click (DESIGN §3.5.2, upstream NotificationHistoryPanel.qml:795-806):
  // the default action when there is one, focusing the sender window when
  // there isn't (or it failed); both close the control centre.
  function invokeDefault(id, appName) {
    if (!NotificationService.invokeAction(id, "default") && appName)
      NotificationService.focusSenderWindow(appName);
    if (root.closeOnAction)
      root.closeOnAction();
  }

  // "清除这组" (DESIGN §3.5.2): every notification of one app group inside
  // its day section.
  function clearGroup(key) {
    const appName = root.groupAppName(key);
    const bucket = root.groupBucket(key);
    const model = NotificationService.historyModel;
    const ids = [];
    for (var i = 0; i < model.count; i++) {
      const entry = model.get(i);
      if ((entry.appName || "") === appName && root.dayBucket(entry.timestamp) === bucket)
        ids.push(entry.id);
    }
    for (var j = 0; j < ids.length; j++)
      NotificationService.removeFromHistory(ids[j]);
    if (root.expandedGroup === key)
      root.expandedGroup = "";
  }

  focus: true
  onVisibleChanged: {
    if (visible)
      root.forceActiveFocus();
  }

  // Keyboard model (DESIGN §3.5.2): up/down walks the visible notifications
  // (a collapsed group is one stop), left/right walks the focused row's
  // actions, Enter activates, Delete removes. Tab no longer filters: the day
  // sections are rows now.
  Keys.onPressed: event => {
                    if (Keybinds.checkKey(event, 'up', Settings)) {
                      root.moveSelection(-1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'down', Settings)) {
                      root.moveSelection(1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'left', Settings)) {
                      root.moveAction(-1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'right', Settings)) {
                      root.moveAction(1);
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'enter', Settings)) {
                      root.activateSelection();
                      event.accepted = true;
                      return;
                    }
                    if (Keybinds.checkKey(event, 'remove', Settings) || event.key === Qt.Key_Delete) {
                      root.removeSelection();
                      event.accepted = true;
                      return;
                    }
                  }

  implicitHeight: mainColumn.implicitHeight

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    spacing: Style.marginS

    // Empty state (onShellTertiary). The list top-anchors its rows once they
    // exist; with nothing to show the hint takes the whole column.
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: NotificationService.historyModel.count === 0

      NText {
        anchors.centerIn: parent
        text: I18n.tr("notifications.panel.no-notifications")
        pointSize: Style.fontSizeM
        color: Colors.onShellTertiary
      }
    }

    // The list: virtualized (delegates are O(visible), not O(maxHistory));
    // the slide-out of a removing row stays inside the clip. Top-anchored:
    // notifications pin to the section top and slack sits at the bottom —
    // the block must not shift when the quick-control strip changes height.
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      visible: NotificationService.historyModel.count > 0

      NListView {
        id: notificationList
        anchors.fill: parent
        // The inter-row gap lives inside the delegate cell (bottom pad),
        // not in `spacing`: ListView bills spacing for EVERY delegate —
        // a collapsed group's 0-height hidden rows would still each pay
        // marginS and blow a hole between the day sections.
        spacing: 0
        reuseItems: true
        gradientColor: "transparent"
        reserveScrollbarSpace: false
        boundsBehavior: Flickable.StopAtBounds
        model: root.descriptors

        delegate: Item {
          id: delegateItem
          width: notificationList.width
          // Header / section rows are 24 px; a collapsed group's hidden rows
          // take no space, so a group really is one stop in the view. The
          // stacked-edge allowance is recomputed from the same predicates the
          // edges use (reading a child's height/visibility here would make
          // the row's height depend on its own layout). The trailing
          // marginS is this row's own bottom pad — see `spacing: 0` above.
          readonly property bool hasStackedEdges: modelData.kind === "notif" && isHead && (modelData.groupSize || 1) > 1 && !isGroupExpanded
          height: {
            if (modelData.kind === "header" || modelData.kind === "section")
              return 24 + Style.marginS;
            return shown ? cardSurface.height + (hasStackedEdges ? Style.marginXXS + 10 : 0) + Style.marginS : 0;
          }

          // Live source entry: the row carries only the index, so the image
          // cache's setProperty(cachedImage) reaches this delegate. Header
          // and section rows have no source index.
          readonly property int modelIndex: modelData.modelIndex || 0
          readonly property var entry: modelData.kind === "notif" ? root._entryAt(modelIndex) : null
          readonly property string notificationId: entry ? entry.id : ""
          readonly property string appName: entry ? (entry.appName || "") : ""
          readonly property string groupKey: modelData.groupKey || ""
          readonly property int groupSize: modelData.groupSize || 1
          readonly property bool isHead: modelData.isHead === true
          // Empty-key guard: header/section/group rows carry no id, and the
          // "" sentinel for "nothing expanded" would otherwise mark every
          // such row expanded — painting a live expandButton over the header
          // row's clear-all (it ate clicks: z:1 keeps it on top).
          readonly property bool isGroupExpanded: groupKey !== "" && root.expandedGroup === groupKey
          // A collapsed multi-notification group shows its newest entry only.
          readonly property bool shown: modelData.kind === "notif" && (groupSize === 1 || isGroupExpanded || isHead)
          // `index` is the view's delegate context property — reachable bare
          // inside the delegate, but NOT via delegateItem.index (that looks
          // for a real property on the Item and binds undefined).
          readonly property int rowIndex: index

          readonly property var actionsList: root.parseActions(entry ? entry.actionsJson : "[]")
          readonly property bool isFocused: index === root.focusIndex
          readonly property int removeAnimationDuration: Style.animationNormal
          readonly property int iconSize: Math.round(24 * Style.uiScaleRatio)
          readonly property bool hasActions: actionsList.some(a => a.identifier !== "default")
          readonly property bool markdownEnabled: Settings.data.notifications.enableMarkdown
          readonly property int textFormat: (markdownEnabled && isExpanded) ? Text.MarkdownText : Text.StyledText
          readonly property string summary: entry ? (entry.summary || I18n.tr("common.no-summary")) : ""
          readonly property string body: entry ? (entry.body || "") : ""
          // Per-notification text expansion (truncated summary/body).
          readonly property bool isExpanded: notificationId !== "" && root.expandedNotification === notificationId
          readonly property bool canExpand: shown && (summaryText.truncated || bodyText.truncated)

          property bool isRemoving: false
          // Item recycling (reuseItems) keeps plain properties across
          // rebinds: reset the slide-out state when this instance is rebound
          // to another notification.
          onNotificationIdChanged: isRemoving = false

          // Dismiss (DESIGN §3.5.2, upstream dismissBySwipe): slide out along
          // the drag direction, then drop the row once the slide finishes.
          // `dir` picks the side (0 = the hover ×, which slides right).
          function dismiss(dir) {
            if (isRemoving)
              return;
            isRemoving = true;
            interactionArea.isSwiping = false;
            interactionArea.swipeOffset = dir >= 0 ? width + Style.marginL : -width - Style.marginL;
            if (Style.reduceMotion) {
              NotificationService.removeFromHistory(notificationId);
              return;
            }
            removeTimer.restart();
          }

          Timer {
            id: removeTimer
            interval: delegateItem.removeAnimationDuration
            repeat: false
            onTriggered: NotificationService.removeFromHistory(delegateItem.notificationId)
          }

          opacity: isRemoving ? 0 : 1

          Behavior on opacity {
            enabled: !Style.reduceMotion && delegateItem.isRemoving
            NAnim {
              duration: Style.motionExit
              curve: "out"
            }
          }

          // The swipe lives in a Translate so it composes with the dismiss
          // fade above (upstream used the same pair).
          transform: Translate {
            x: interactionArea.swipeOffset
          }

          // ---- list header row (DESIGN §3.5.2) ----
          RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24
            visible: modelData.kind === "header"
            spacing: Style.marginS

            NText {
              Layout.fillWidth: true
              text: I18n.tr("notifications.panel.title")
              pointSize: Style.fontSizeS
              color: Qt.alpha(Colors.onShell, 0.6)
              font.weight: Style.fontWeightMedium
              elide: Text.ElideRight
            }

            // "全部清除" is a button-class control: hover/press fade over
            // motionPointer (DESIGN §1.7), idle fill and radiusRow.
            Rectangle {
              id: clearAll
              objectName: "notifClearAll"
              implicitWidth: clearAllText.implicitWidth + Style.margin2XS
              implicitHeight: clearAllText.implicitHeight + Style.margin2XS
              radius: Style.radiusRow
              color: clearAllMouse.containsMouse ? Colors.overlay("hover") : Colors.overlay("idle")

              Behavior on color {
                enabled: !Colors.isTransitioning
                NColorAnim {
                  duration: Style.motionPointer
                  curve: "swift"
                }
              }

              NText {
                id: clearAllText
                anchors.centerIn: parent
                text: I18n.tr("actions.clear-history")
                pointSize: Style.fontSizeS
                color: Colors.onShellSecondary
              }

              MouseArea {
                id: clearAllMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: NotificationService.clearHistory()
              }
            }
          }

          // ---- day section header (DESIGN §3.5.2) ----
          NText {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24
            verticalAlignment: Text.AlignVCenter
            visible: modelData.kind === "section"
            text: root.bucketTitle(modelData.bucket)
            pointSize: Style.fontSizeXS
            color: Qt.alpha(Colors.onShell, 0.6)
            font.weight: Style.fontWeightMedium
            elide: Text.ElideRight
          }

          // ---- notification card (DESIGN §3.5.2) ----
          // z: 1 keeps the card above interactionArea (declared last among the
          // siblings, so it would otherwise shadow every sibling subtree):
          // the in-card MouseAreas on "还有 N 条", the action buttons and the
          // expanded-group header must stay clickable while the blanket area
          // below still catches clicks/drags on the card's blank space.
          Rectangle {
            id: cardSurface
            objectName: "notifCard"
            z: 1
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: shown ? cardColumn.implicitHeight + Style.margin2S : 0
            radius: Style.radiusItem
            color: Colors.overlay("strong")
            border.color: delegateItem.isFocused ? Colors.accent : "transparent"
            border.width: Style.borderS
            visible: shown

            // Expand/collapse is a data-driven size change.
            Behavior on height {
              enabled: !Style.reduceMotion
              NAnim {
                duration: Style.motionExpand
                curve: "expand"
              }
            }

            ColumnLayout {
              id: cardColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.marginS
              spacing: Style.marginXXS

              // Expanded group header (DESIGN §3.5.2): app name, "收起" and
              // the per-group clear ×, at the top of the group.
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: delegateItem.isGroupExpanded && delegateItem.isHead

                NText {
                  Layout.fillWidth: true
                  text: delegateItem.appName || I18n.tr("system.unknown-app")
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightMedium
                  color: Colors.onShell
                  elide: Text.ElideRight
                }

                NText {
                  text: I18n.tr("notifications.panel.collapse-group")
                  pointSize: Style.fontSizeXS
                  color: Colors.accentAlt
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expandedGroup = ""
                  }
                }

                NIconButton {
                  baseSize: Style.baseWidgetSize * 0.7
                  applyUiScale: false
                  icon: "x"
                  colorFg: Colors.onShellTertiary
                  colorBg: "transparent"
                  colorBgHover: Colors.overlay("hover")
                  colorFgHover: Colors.onShell
                  tooltipText: I18n.tr("notifications.panel.clear-group")
                  onClicked: root.clearGroup(delegateItem.groupKey)
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NImageRounded {
                  Layout.preferredWidth: delegateItem.iconSize
                  Layout.preferredHeight: delegateItem.iconSize
                  Layout.alignment: Qt.AlignTop
                  radius: Math.min(Style.radiusRow, width / 2)
                  imagePath: entry ? (entry.cachedImage || entry.originalImage || "") : ""
                  symbolicColor: Colors.onShell
                  borderColor: "transparent"
                  borderWidth: 0
                  fallbackIcon: "bell"
                  fallbackIconSize: 24
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXXS

                  // Meta row: app name + relative time (DESIGN §3.5.2).
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                      Layout.fillWidth: true
                      text: delegateItem.appName || I18n.tr("system.unknown-app")
                      pointSize: Style.fontSizeXS
                      font.weight: Style.fontWeightMedium
                      color: Colors.onShell
                      elide: Text.ElideRight
                    }

                    NText {
                      textFormat: Text.PlainText
                      text: Time.formatRelativeTime(entry ? entry.timestamp : 0)
                      pointSize: Style.fontSizeXXS
                      color: Colors.onShellTertiary
                    }
                  }

                  NText {
                    id: summaryText
                    Layout.fillWidth: true
                    text: (delegateItem.markdownEnabled && delegateItem.isExpanded) ? (entry.summaryMarkdown || I18n.tr("common.no-summary")) : delegateItem.summary
                    pointSize: Style.fontSizeM
                    color: Colors.onShell
                    textFormat: delegateItem.textFormat
                    wrapMode: Text.Wrap
                    maximumLineCount: delegateItem.isExpanded ? 999 : 2
                    elide: Text.ElideRight
                    onLinkActivated: link => Qt.openUrlExternally(link)
                  }

                  NText {
                    id: bodyText
                    Layout.fillWidth: true
                    text: (delegateItem.markdownEnabled && delegateItem.isExpanded) ? (entry.bodyMarkdown || "") : delegateItem.body
                    pointSize: Style.fontSizeS
                    color: Colors.onShellSecondary
                    textFormat: delegateItem.textFormat
                    wrapMode: Text.Wrap
                    maximumLineCount: delegateItem.isExpanded ? 999 : 3
                    elide: Text.ElideRight
                    visible: text.length > 0
                    onLinkActivated: link => Qt.openUrlExternally(link)
                  }

                  // Actions: accentAlt text buttons (DESIGN §3.5.2).
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
                        color: (delegateItem.isFocused && root.actionIndex === index) ? Colors.accent : Colors.accentAlt
                        font.weight: (delegateItem.isFocused && root.actionIndex === index) ? Style.fontWeightSemiBold : Style.fontWeightNormal
                        visible: !isDefault

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.focusIndex = delegateItem.rowIndex;
                            root.actionIndex = index;
                            root.invokeAndClose(delegateItem.notificationId, modelData.identifier);
                          }
                        }
                      }
                    }
                  }

                  // "还有 N 条" (DESIGN §3.5.2): opens the group. Only the
                  // newest card of a collapsed multi-entry group carries it.
                  NText {
                    Layout.fillWidth: true
                    objectName: "notifMore"
                    visible: delegateItem.isHead && delegateItem.groupSize > 1 && !delegateItem.isGroupExpanded
                    text: I18n.tr("notifications.panel.more-in-group", {
                                    count: delegateItem.groupSize - 1
                                  })
                    pointSize: Style.fontSizeXXS
                    color: Colors.onShellTertiary
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.expandedGroup = delegateItem.groupKey
                    }
                  }
                }
              }
            }
          }

          // Stacked edges (DESIGN §3.5.2): two staggered bottom edges under
          // the newest card of a collapsed multi-entry group — each 8 px
          // further in, 4 px tall, overlay("hover"), radiusItem.
          Item {
            id: stackedEdges
            anchors.top: cardSurface.bottom
            anchors.topMargin: Style.marginXXS
            anchors.horizontalCenter: parent.horizontalCenter
            width: cardSurface.width
            height: Style.marginXXS + 8
            visible: delegateItem.shown && delegateItem.isHead && delegateItem.groupSize > 1 && !delegateItem.isGroupExpanded

            Rectangle {
              y: 0
              x: 8
              width: cardSurface.width - 16
              height: 4
              radius: Style.radiusItem
              color: Colors.overlay("hover")
            }

            Rectangle {
              y: Style.marginXXS + 4
              x: 16
              width: cardSurface.width - 32
              height: 4
              radius: Style.radiusItem
              color: Colors.overlay("hover")
            }
          }

          // Chevron for a truncated summary/body (DESIGN §3.5.2): expands
          // the full text in place. Top-right of the card, left of the
          // hover ×.
          NIconButton {
            id: expandButton
            anchors.top: cardSurface.top
            anchors.right: cardSurface.right
            anchors.margins: Style.marginXS
            anchors.rightMargin: closeButton.width + Style.marginXS
            z: 1
            baseSize: Style.baseWidgetSize * 0.7
            applyUiScale: false
            icon: delegateItem.isExpanded ? "chevron-up" : "chevron-down"
            colorFg: Colors.onShellTertiary
            colorBg: "transparent"
            colorBgHover: Colors.overlay("hover")
            colorFgHover: Colors.onShell
            tooltipText: delegateItem.isExpanded ? I18n.tr("notifications.panel.click-to-collapse") : I18n.tr("notifications.panel.click-to-expand")
            visible: delegateItem.canExpand || delegateItem.isExpanded
            onClicked: root.expandedNotification = delegateItem.isExpanded ? "" : delegateItem.notificationId
          }

          // Hover-revealed × (DESIGN §3.5.2): deletes this notification.
          // Floats over the card's top-right corner (gxde
          // notifydelegate.cpp: the button floats over the item).
          NIconButton {
            id: closeButton
            anchors.right: cardSurface.right
            anchors.top: cardSurface.top
            anchors.margins: Style.marginXS
            z: 1
            baseSize: Style.baseWidgetSize * 0.7
            applyUiScale: false
            visible: opacity > 0
            opacity: hoverHandler.hovered ? 1 : 0
            icon: "x"
            colorFg: Colors.onShellTertiary
            colorBg: "transparent"
            colorBgHover: Colors.overlay("hover")
            colorFgHover: Colors.onShell
            tooltipText: I18n.tr("tooltips.dismiss-notification")
            onClicked: delegateItem.dismiss(0)
          }

          // Card interaction (upstream NotificationHistoryPanel.qml:795-806):
          // click runs the default action or focuses the sender, a drag past
          // the upstream thresholds dismisses, a shorter drag springs back,
          // and a link inside an expanded body wins over the primary action.
          MouseArea {
            id: interactionArea
            anchors.fill: parent
            // Leave the row's trailing pad to the flickable — it is the
            // inter-row gap, not card surface: clicks/drags there must not
            // act on this notification.
            anchors.bottomMargin: Style.marginS
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            enabled: delegateItem.shown && !delegateItem.isRemoving

            property real pressGlobalX: 0
            property real pressGlobalY: 0
            property real swipeOffset: 0
            property bool isSwiping: false
            property string pendingLink: ""
            readonly property real swipeStartThreshold: Math.round(16 * Style.uiScaleRatio)
            readonly property real swipeDismissThreshold: Math.max(110, width * 0.3)

            // A released swipe springs back on the CDS drag-release spring
            // (motionSnapBack, "snappy"); a dismissing swipe slides out on
            // motionExit (DESIGN §3.5.2).
            Behavior on swipeOffset {
              enabled: !Style.reduceMotion && !interactionArea.isSwiping
              NAnim {
                duration: delegateItem.isRemoving ? Style.motionExit : Style.motionSnapBack
                curve: delegateItem.isRemoving ? "out" : "snappy"
              }
            }

            function isSafeLink(link) {
              if (!link)
                return false;
              const lower = link.toLowerCase();
              return ["http://", "https://", "mailto:"].some(scheme => lower.startsWith(scheme));
            }

            function linkAtPoint(x, y) {
              if (!Settings.data.notifications.enableMarkdown || !delegateItem.isExpanded)
                return "";
              for (const textItem of [summaryText, bodyText]) {
                if (!textItem || !textItem.visible)
                  continue;
                const p = textItem.mapFromItem(interactionArea, x, y);
                if (p.x >= 0 && p.y >= 0 && p.x <= textItem.width && p.y <= textItem.height) {
                  const link = textItem.linkAt ? textItem.linkAt(p.x, p.y) : "";
                  if (isSafeLink(link))
                    return link;
                }
              }
              return "";
            }

            onPressed: mouse => {
                         root.focusIndex = delegateItem.rowIndex;
                         root.actionIndex = -1;
                         if (delegateItem.isExpanded)
                         interactionArea.pendingLink = interactionArea.linkAtPoint(mouse.x, mouse.y);
                         if (mouse.button !== Qt.LeftButton)
                         return;
                         const globalPoint = interactionArea.mapToGlobal(mouse.x, mouse.y);
                         interactionArea.pressGlobalX = globalPoint.x;
                         interactionArea.pressGlobalY = globalPoint.y;
                         interactionArea.isSwiping = false;
                       }
            onPositionChanged: mouse => {
                                 if (!(mouse.buttons & Qt.LeftButton) || delegateItem.isRemoving)
                                 return;
                                 const globalPoint = interactionArea.mapToGlobal(mouse.x, mouse.y);
                                 const deltaX = globalPoint.x - interactionArea.pressGlobalX;
                                 const deltaY = globalPoint.y - interactionArea.pressGlobalY;

                                 if (!interactionArea.isSwiping) {
                                   if (Math.abs(deltaX) < interactionArea.swipeStartThreshold)
                                   return;
                                   // Only horizontal-dominant movement starts a swipe.
                                   if (Math.abs(deltaX) <= Math.abs(deltaY) * 1.15)
                                   return;
                                   interactionArea.isSwiping = true;
                                 }
                                 if (interactionArea.pendingLink && Math.abs(deltaX) >= interactionArea.swipeStartThreshold)
                                 interactionArea.pendingLink = "";
                                 interactionArea.swipeOffset = deltaX;
                               }
            onReleased: mouse => {
                          if (mouse.button !== Qt.LeftButton)
                          return;

                          if (interactionArea.isSwiping) {
                            // Past the threshold the row flies out and goes;
                            // short of it the spring-back Behavior applies.
                            if (Math.abs(interactionArea.swipeOffset) >= interactionArea.swipeDismissThreshold)
                            delegateItem.dismiss(interactionArea.swipeOffset >= 0 ? 1 : -1);
                            else
                            interactionArea.swipeOffset = 0;
                            interactionArea.isSwiping = false;
                            interactionArea.pendingLink = "";
                            return;
                          }

                          if (interactionArea.pendingLink) {
                            Qt.openUrlExternally(interactionArea.pendingLink);
                            interactionArea.pendingLink = "";
                            return;
                          }

                          // Collapsed group → expand; truncated text → expand
                          // in place; otherwise the primary action.
                          if (delegateItem.groupSize > 1 && !delegateItem.isGroupExpanded) {
                            root.expandedGroup = delegateItem.groupKey;
                            return;
                          }
                          if (delegateItem.canExpand) {
                            root.expandedNotification = delegateItem.notificationId;
                            return;
                          }
                          root.invokeDefault(delegateItem.notificationId, delegateItem.appName);
                        }
            onCanceled: {
              interactionArea.isSwiping = false;
              interactionArea.swipeOffset = 0;
              interactionArea.pendingLink = "";
            }

            HoverHandler {
              id: hoverHandler
              target: parent
            }
          }
        }
      }
    }
  }

  // Removals from the hover ×, the group clear or the service itself can
  // leave the keyboard focus past the end of the row space.
  Connections {
    target: NotificationService.historyModel
    function onCountChanged() {
      if (root.focusIndex >= root.descriptors.length)
        root.focusIndex = root.descriptors.length - 1;
    }
  }
}
