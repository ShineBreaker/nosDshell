import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NDccRow {
  id: root

  property real minimumWidth: 280
  property real popupHeight: 180

  property bool selectOnNavigation: true
  property string label: ""
  property string description: ""
  property ListModel model: {}
  property string currentKey: ""
  property string placeholder: ""
  property string searchPlaceholder: I18n.tr("placeholders.search")
  property Component delegate: null
  property var defaultValue: undefined
  property string settingsPath: ""
  // A labelled combo is a settings row; a bare one is not.
  property bool dccRow: label !== "" || description !== ""
  // Set when the combo lives on a translucent shell surface — the popup keeps
  // the blurred popupShell look (see NComboBox.onShellSurface).
  property bool onShellSurface: false
  // Fill the width the parent gives this combo instead of locking to
  // minimumWidth. Used when the combo shares a fixed control column with a
  // trailing button (NSectionEditor).
  property bool flexWidth: false
  readonly property real preferredHeight: 30

  signal selected(string key)

  plain: !root.dccRow
  spacing: root.dccRow ? Style.marginM : Style.marginL
  Layout.fillWidth: true

  readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey !== defaultValue)
  readonly property string indicatorTooltip: {
    if (defaultValue === undefined)
      return "";
    var displayValue = "";
    if (defaultValue === "") {
      // Try to find the display name for empty key in the model
      if (_modelRows.length > 0) {
        for (var i = 0; i < _modelRows.length; i++) {
          var item = _modelRows[i];
          if (item && item.key === "") {
            displayValue = item.name || I18n.tr("panels.indicator.system-default");
            break;
          }
        }
        // If not found in model, show "System Default" instead of "(empty)"
        if (displayValue === "") {
          displayValue = I18n.tr("panels.indicator.system-default");
        }
      } else {
        displayValue = I18n.tr("panels.indicator.system-default");
      }
    } else {
      // Try to find the display name for the default key in the model
      if (_modelRows.length > 0) {
        for (var i = 0; i < _modelRows.length; i++) {
          var item2 = _modelRows[i];
          if (item2 && item2.key === defaultValue) {
            displayValue = item2.name || String(defaultValue);
            break;
          }
        }
        if (displayValue === "") {
          displayValue = String(defaultValue);
        }
      } else {
        displayValue = String(defaultValue);
      }
    }
    return I18n.tr("panels.indicator.default-value", {
                     "value": displayValue
                   });
  }

  // Filtered model for search results
  property ListModel filteredModel: ListModel {}
  property string searchText: ""

  // Plain-dict mirrors for binding-side lookups. ListModel.get()/model.<role>
  // reads inside bindings capture the live row proxy and crash in
  // QQmlListModel::data→captureProperty when the model mutates (DESIGN §1.7);
  // the mirror is rebuilt from JS handlers, where get() is safe.
  property var _modelRows: []
  property var _activeRows: []

  function _rowsOf(m) {
    var rows = [];
    if (!m)
      return rows;
    var n = (m.count !== undefined) ? m.count : m.length;
    for (var i = 0; i < n; i++) {
      var r = (m.count !== undefined) ? m.get(i) : m[i];
      rows.push({
                  "key": r.key,
                  "name": r.name,
                  "badges": (r.badges !== undefined && r.badges !== null) ? r.badges : []
                });
    }
    return rows;
  }

  // Set while filterModel batch-fills filteredModel: ListModel::append emits
  // countChanged synchronously per row, and each hit would rebuild both
  // mirrors (O((N+M)×M) gets per keystroke). While set, rebuilds are skipped;
  // the batch caller rebuilds once at the end.
  property bool _batchFilling: false

  function rebuildRows() {
    if (_batchFilling)
      return;
    _modelRows = _rowsOf(root.model);
    _activeRows = _rowsOf(root.activeModel);
  }

  function findIndexByKey(key) {
    for (var i = 0; i < _modelRows.length; i++) {
      if (_modelRows[i].key === key) {
        return i;
      }
    }
    return -1;
  }

  // The active model used for the popup list (source model or filtered results)
  readonly property var activeModel: isFiltered ? filteredModel : root.model
  onActiveModelChanged: rebuildRows()
  onModelChanged: rebuildRows()
  Component.onCompleted: rebuildRows()

  Connections {
    target: root.model
    function onCountChanged() {
      root.rebuildRows();
    }
    function onDataChanged() {
      root.rebuildRows();
    }
  }
  Connections {
    target: root.activeModel
    function onCountChanged() {
      root.rebuildRows();
    }
    function onDataChanged() {
      root.rebuildRows();
    }
  }

  function findIndexInActiveModel(key) {
    for (var i = 0; i < _activeRows.length; i++) {
      if (_activeRows[i].key === key) {
        return i;
      }
    }
    return -1;
  }

  function nameByKey(key) {
    for (var i = 0; i < _modelRows.length; i++) {
      if (_modelRows[i].key === key) {
        return _modelRows[i].name;
      }
    }
    return "";
  }

  // Whether we're using filtered results or the source model directly
  property bool isFiltered: false

  function filterModel() {
    // Check if model exists and has items
    if (!root.model || root.model.count === undefined || root.model.count === 0) {
      filteredModel.clear();
      isFiltered = false;
      return;
    }

    var query = searchText.trim();
    if (query === "") {
      // No search text - use source model directly, don't copy
      filteredModel.clear();
      isFiltered = false;
      return;
    }

    // We have search text - need to filter
    _batchFilling = true;
    try {
      isFiltered = true;
      filteredModel.clear();

      // Fuzzy search runs on the plain-dict mirror rows.
      var items = _modelRows;

      // Use fuzzy search if available, fallback to simple search
      if (typeof FuzzySort !== 'undefined') {
        var fuzzyResults = FuzzySort.go(query, items, {
                                          "key": "name",
                                          "limit": 50
                                        });

        // Add results in order of relevance
        for (var j = 0; j < fuzzyResults.length; j++) {
          filteredModel.append(fuzzyResults[j].obj);
        }
      } else {
        // Fallback to simple search
        var searchLower = query.toLowerCase();
        for (var i = 0; i < items.length; i++) {
          var item = items[i];
          if (item.name.toLowerCase().includes(searchLower)) {
            filteredModel.append(item);
          }
        }
      }
    } finally {
      // One rebuild for the whole batch: isFiltered's model switch, clear()
      // and every append were all skipped above.
      _batchFilling = false;
      rebuildRows();
    }
  }

  onSearchTextChanged: {
    filterModel();
    listView.currentIndex = 0;
  }

  NLabel {
    id: titleLabel

    label: root.label
    description: root.description
    labelWeight: Style.fontWeightRegular
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
    Layout.fillWidth: true
    Layout.minimumWidth: root.dccRow ? Math.min(titleLabel.labelImplicitWidth, Style.settingsFieldTitleMaxWidth) : 0
  }

  ComboBox {
    id: combo

    // Same disabled treatment as NComboBox: full opacity, color swap
    // (textDisabledDark) instead of a blanket alpha that brightens the field.
    Layout.margins: Style.borderS
    // Fixed width trio: minimum/preferred/maximum depend only on the plain
    // root.minimumWidth property and Style tokens. Never read root.width
    // (the RowLayout's own laid-out width) here, and never feed an attached
    // Layout value back into implicitWidth: that round-trip
    // (layout result -> attached minimum -> implicit size -> layout result)
    // was the recursive-rearrange feedback loop.
    // In narrow contexts (the 352 px module view, §3.5.3) the row squeezes
    // the box toward the 120 floor instead of starving the label column.
    Layout.fillWidth: true
    // A settings row pins the control column (DESIGN §3.5.4 控件列宽) so the
    // fields of neighbouring rows line up; a bare combo still follows its own
    // minimumWidth so popups and the launcher keep sizing to content.
    Layout.minimumWidth: root.dccRow ? Style.settingsFieldWidth : (root.flexWidth ? 0 : Math.round(120 * Style.uiScaleRatio))
    Layout.preferredWidth: root.dccRow ? Style.settingsFieldWidth : (root.flexWidth ? -1 : Math.round(root.minimumWidth * Style.uiScaleRatio))
    Layout.maximumWidth: root.dccRow ? Style.settingsFieldWidth : (root.flexWidth ? Number.POSITIVE_INFINITY : Math.round(root.minimumWidth * Style.uiScaleRatio))
    Layout.preferredHeight: Math.round(root.preferredHeight * Style.uiScaleRatio)
    // Plain-dict mirror rows — never the live ListModel (DESIGN §1.7).
    model: root._activeRows
    textRole: "name"
    currentIndex: findIndexInActiveModel(currentKey)
    onActivated: {
      var row = root._activeRows[combo.currentIndex];
      if (row)
        root.selected(row.key);
    }

    background: Rectangle {
      // §3.5.4: the drop-down looks like a text field — field fill, radius 5,
      // 1 px accent outline on focus.
      implicitHeight: Style.settingsFieldHeight
      color: combo.enabled ? Colors.overlay("field") : Colors.overlay("idle")
      border.color: combo.activeFocus ? Colors.accent : "transparent"
      border.width: Style.borderS
      radius: Style.settingsFieldRadius

      Behavior on border.color {
        enabled: !Colors.isTransitioning
        NColorAnim {
          duration: Style.motionSwitch
          curve: "swift"
        }
      }
    }

    contentItem: NText {
      leftPadding: Style.marginL
      rightPadding: combo.indicator.width + Style.marginL
      pointSize: Style.fontSizeM
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight

      // Look up current selection directly in source model by key
      readonly property int sourceIndex: root.findIndexByKey(root.currentKey)
      readonly property bool hasSelection: sourceIndex >= 0 && sourceIndex < root._modelRows.length

      // Stay opaque: the disabled signal is the color swap, not extra alpha.
      opacity: 1.0
      color: combo.enabled ? (hasSelection ? Colors.onShell : Colors.onShellTertiary) : Colors.textDisabledDark
      text: hasSelection ? root.nameByKey(root.currentKey) : root.placeholder
    }

    indicator: NIcon {
      x: combo.width - width - Style.marginM
      y: combo.topPadding + (combo.availableHeight - height) / 2
      icon: "caret-down"
      pointSize: Style.fontSizeL
      color: combo.enabled ? Colors.onShellSecondary : Colors.textDisabledDark
    }

    popup: Popup {
      y: combo.height + Style.marginS
      width: combo.width
      height: Math.round((root.popupHeight + 60) * Style.uiScaleRatio)
      padding: Style.marginS
      enter: NPopupEnter {}
      exit: NPopupExit {}

      contentItem: ColumnLayout {
        spacing: Style.marginS

        // Search input
        NTextInput {
          id: searchInput
          inputIconName: "search"
          Layout.fillWidth: true
          placeholderText: root.searchPlaceholder
          text: root.searchText
          onTextChanged: root.searchText = text
          fontSize: Style.fontSizeS

          Keys.onPressed: event => {
                            if (Keybinds.checkKey(event, 'enter', Settings)) {
                              selectHighlighted();
                              combo.popup.close();
                              event.accepted = true;
                              return;
                            }

                            if (Keybinds.checkKey(event, 'escape', Settings)) {
                              combo.popup.close();
                              event.accepted = true;
                              return;
                            }

                            if (Keybinds.checkKey(event, 'up', Settings)) {
                              if (listView.currentIndex > 0) {
                                listView.currentIndex--;
                                if (root.selectOnNavigation)
                                selectHighlighted();
                              }
                              event.accepted = true;
                              return;
                            }

                            if (Keybinds.checkKey(event, 'down', Settings)) {
                              if (listView.currentIndex < listView.count - 1) {
                                listView.currentIndex++;
                                if (root.selectOnNavigation)
                                selectHighlighted();
                              }
                              event.accepted = true;
                              return;
                            }
                          }

          function selectHighlighted() {
            var row = root._activeRows[listView.currentIndex];
            if (row)
              root.selected(row.key);
          }
        }

        NListView {
          id: listView
          Layout.fillWidth: true
          Layout.fillHeight: true
          // Plain-dict mirror rows — never the live ListModel: binding-side
          // model.<role>/get() reads capture the row proxy and crash on the
          // next mutation (DESIGN §1.7).
          model: combo.popup.visible ? root._activeRows : null
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          // Same overlay-scrollbar rule as NComboBox's popup: no reserved
          // gutter, but the thumb stays visible while the list overflows.
          reserveScrollbarSpace: false
          showScrollbarWhenScrollable: true

          onCurrentIndexChanged: {
            if (currentIndex >= 0)
              positionViewAtIndex(currentIndex, ListView.Contain);
          }

          delegate: root.delegate ? root.delegate : defaultDelegate

          Component {
            id: defaultDelegate
            ItemDelegate {
              id: delegateRoot
              width: listView.availableWidth
              leftPadding: Style.marginM
              rightPadding: Style.marginM
              topPadding: Style.marginS
              bottomPadding: Style.marginS
              hoverEnabled: true
              highlighted: ListView.view.currentIndex === index

              onHoveredChanged: {
                if (hovered) {
                  ListView.view.currentIndex = index;
                }
              }

              onClicked: {
                var row = root._activeRows[index];
                if (row)
                  root.selected(row.key);
                combo.popup.close();
              }

              contentItem: RowLayout {
                width: delegateRoot.width - delegateRoot.leftPadding - delegateRoot.rightPadding
                spacing: Style.marginM

                NText {
                  text: modelData ? modelData.name : ""
                  pointSize: Style.fontSizeM
                  color: highlighted ? Colors.onAccent : Colors.onShell
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                RowLayout {
                  spacing: Style.marginXXS
                  Layout.alignment: Qt.AlignRight

                  // Generic badge renderer — modelData rows are plain dicts
                  Repeater {
                    model: (modelData && modelData.badges) ? modelData.badges.length : 0

                    delegate: NIcon {
                      required property int index
                      readonly property var badgeData: (modelData && modelData.badges) ? modelData.badges[index] : null

                      icon: badgeData && badgeData.icon ? badgeData.icon : ""
                      pointSize: {
                        if (!badgeData || !badgeData.size)
                          return Style.fontSizeXS;
                        if (badgeData.size === "xsmall")
                          return Style.fontSizeXXS;
                        else if (badgeData.size === "medium")
                          return Style.fontSizeM;
                        else
                          return Style.fontSizeXS;
                      }
                      color: highlighted ? Colors.onAccent : (badgeData && badgeData.color ? badgeData.color : Colors.onShellSecondary)
                      Layout.preferredWidth: Math.round(Style.baseWidgetSize * 0.6)
                      Layout.preferredHeight: Math.round(Style.baseWidgetSize * 0.6)
                      visible: badgeData && badgeData.icon !== undefined && badgeData.icon !== ""
                    }
                  }
                }
              }
              background: Rectangle {
                anchors.fill: parent
                color: highlighted ? Colors.accent : "transparent"
                radius: Style.radiusRow
              }
            }
          }
        }
      }

      background: NArrowRect {
        // Same as NComboBox: page-surface menus stay opaque (Colors.popupPage)
        // — popupShell's translucency would bleed settings page text
        // through the list.
        arrowEdge: ""
        fillColor: root.onShellSurface ? Colors.popupShell : Colors.popupPage
        borderColor: root.onShellSurface ? Colors.borderShell : Colors.mOutline
        borderWidth: Style.borderS
        radius: Style.radiusPopup
        shadow: Style.shadowPopup
      }
    }

    // Update the currentIndex if the currentKey is changed externally
    Connections {
      target: root
      function onCurrentKeyChanged() {
        combo.currentIndex = root.findIndexInActiveModel(root.currentKey);
      }
    }

    // Focus search input when popup opens and ensure model is filtered
    Connections {
      target: combo.popup
      function onVisibleChanged() {
        if (combo.popup.visible) {
          // Ensure the model is filtered when popup opens
          filterModel();
          listView.currentIndex = Math.max(0, root.findIndexInActiveModel(root.currentKey));
          // Small delay to ensure the popup is fully rendered
          Qt.callLater(() => {
                         if (searchInput && searchInput.inputItem) {
                           searchInput.inputItem.forceActiveFocus();
                         }
                       });
        } else {
          root.searchText = "";
        }
      }
    }
  }
}
