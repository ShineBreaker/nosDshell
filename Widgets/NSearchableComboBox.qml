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
  // LineEditWidget fixes its title column at 140 px (lineeditwidget.cpp:83).
  property real titleWidth: Style.settingsFieldTitleWidth

  readonly property real preferredHeight: 30

  signal selected(string key)

  plain: !root.dccRow
  spacing: root.dccRow ? Style.settingsFieldGap : Style.marginL
  Layout.fillWidth: true

  readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey !== defaultValue)
  readonly property string indicatorTooltip: {
    if (defaultValue === undefined)
      return "";
    var displayValue = "";
    if (defaultValue === "") {
      // Try to find the display name for empty key in the model
      if (model && model.count > 0) {
        for (var i = 0; i < model.count; i++) {
          var item = model.get(i);
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
      if (model && model.count > 0) {
        for (var i = 0; i < model.count; i++) {
          var item = model.get(i);
          if (item && item.key === defaultValue) {
            displayValue = item.name || String(defaultValue);
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

  function findIndexByKey(key) {
    if (!root.model)
      return -1;
    for (var i = 0; i < root.model.count; i++) {
      if (root.model.get(i).key === key) {
        return i;
      }
    }
    return -1;
  }

  // The active model used for the popup list (source model or filtered results)
  readonly property var activeModel: isFiltered ? filteredModel : root.model

  function findIndexInActiveModel(key) {
    if (!activeModel || activeModel.count === undefined)
      return -1;
    for (var i = 0; i < activeModel.count; i++) {
      if (activeModel.get(i).key === key) {
        return i;
      }
    }
    return -1;
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
    isFiltered = true;
    filteredModel.clear();

    // Convert ListModel to array for fuzzy search
    var items = [];
    for (var i = 0; i < root.model.count; i++) {
      items.push(root.model.get(i));
    }

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
    Layout.maximumWidth: root.dccRow ? root.titleWidth : Number.POSITIVE_INFINITY
    Layout.minimumWidth: root.dccRow ? Math.min(titleLabel.labelImplicitWidth, root.titleWidth) : 0
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
    Layout.minimumWidth: Math.round(120 * Style.uiScaleRatio)
    Layout.preferredWidth: Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.maximumWidth: Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.preferredHeight: Math.round(root.preferredHeight * Style.uiScaleRatio)
    model: root.activeModel
    textRole: "name"
    currentIndex: findIndexInActiveModel(currentKey)
    onActivated: {
      if (combo.currentIndex >= 0 && root.activeModel && combo.currentIndex < root.activeModel.count) {
        root.selected(root.activeModel.get(combo.currentIndex).key);
      }
    }

    background: Rectangle {
      // §3.5.4: the drop-down looks like a text field — field fill, radius 5,
      // 1 px accent outline on focus.
      implicitHeight: Style.settingsFieldHeight
      color: combo.enabled ? Color.overlay("field") : Color.overlay("idle")
      border.color: combo.activeFocus ? Color.accent : "transparent"
      border.width: Style.borderS
      radius: Style.settingsFieldRadius

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
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
      readonly property bool hasSelection: root.model && sourceIndex >= 0 && sourceIndex < root.model.count

      // Stay opaque: the disabled signal is the color swap, not extra alpha.
      opacity: 1.0
      color: combo.enabled ? (hasSelection ? Color.onShell : Color.onShellTertiary) : Color.textDisabledDark
      text: hasSelection ? root.model.get(sourceIndex).name : root.placeholder
    }

    indicator: NIcon {
      x: combo.width - width - Style.marginM
      y: combo.topPadding + (combo.availableHeight - height) / 2
      icon: "caret-down"
      pointSize: Style.fontSizeL
      color: combo.enabled ? Color.onShellSecondary : Color.textDisabledDark
    }

    popup: Popup {
      y: combo.height + Style.marginS
      width: combo.width
      height: Math.round((root.popupHeight + 60) * Style.uiScaleRatio)
      padding: Style.marginS

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
            if (listView.currentIndex >= 0 && listView.model && listView.currentIndex < listView.model.count) {
              var selectedKey = listView.model.get(listView.currentIndex).key;
              root.selected(selectedKey);
            }
          }
        }

        NListView {
          id: listView
          Layout.fillWidth: true
          Layout.fillHeight: true
          gradientColor: "transparent"
          // Use activeModel (source model when not filtering, filtered results when searching)
          model: combo.popup.visible ? root.activeModel : null
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded

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
                var selectedKey = listView.model.get(index).key;
                root.selected(selectedKey);
                combo.popup.close();
              }

              contentItem: RowLayout {
                width: delegateRoot.width - delegateRoot.leftPadding - delegateRoot.rightPadding
                spacing: Style.marginM

                NText {
                  text: name
                  pointSize: Style.fontSizeM
                  color: highlighted ? Color.onAccent : Color.onShell
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                RowLayout {
                  spacing: Style.marginXXS
                  Layout.alignment: Qt.AlignRight

                  // Generic badge renderer
                  Repeater {
                    model: {
                      if (typeof badges === 'undefined' || badges === null)
                        return 0;
                      // Handle both arrays and ListModels
                      if (typeof badges.length !== 'undefined')
                        return badges.length;
                      if (typeof badges.count !== 'undefined')
                        return badges.count;
                      return 0;
                    }

                    delegate: NIcon {
                      required property int index
                      readonly property var badgeData: {
                        if (typeof badges === 'undefined' || badges === null)
                          return null;
                        // Handle both arrays and ListModels
                        if (typeof badges.length !== 'undefined')
                          return badges[index];
                        if (typeof badges.get !== 'undefined')
                          return badges.get(index);
                        return null;
                      }

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
                      color: highlighted ? Color.onAccent : (badgeData && badgeData.color ? badgeData.color : Color.onShellSecondary)
                      Layout.preferredWidth: Math.round(Style.baseWidgetSize * 0.6)
                      Layout.preferredHeight: Math.round(Style.baseWidgetSize * 0.6)
                      visible: badgeData && badgeData.icon !== undefined && badgeData.icon !== ""
                    }
                  }
                }
              }
              background: Rectangle {
                anchors.fill: parent
                color: highlighted ? Color.accent : "transparent"
                radius: 0
              }
            }
          }
        }
      }

      background: Rectangle {
        // Same as NComboBox: page-surface menus stay opaque — popupShell's
        // translucency would bleed settings page text through the list.
        color: root.onShellSurface ? Color.popupShell : Color.mSurfaceVariant
        border.color: root.onShellSurface ? Color.borderShell : Color.mOutline
        border.width: Style.borderS
        radius: Style.radiusPopup
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
