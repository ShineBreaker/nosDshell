import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

NDccRow {
  id: root

  property real minimumWidth: 170
  property real popupHeight: 180

  property string label: ""
  property string description: ""
  property string tooltip: ""
  property var model
  property string currentKey: ""
  property string placeholder: ""
  property var defaultValue: undefined
  property string settingsPath: ""
  property real baseSize: 1.0
  // A labelled combo is a settings row; a bare one is not.
  property bool dccRow: label !== "" || description !== ""
  // Set when the combo lives on a translucent shell surface (glass panels):
  // the popup then keeps the blurred popupShell look instead of an opaque
  // page-surface menu.
  property bool onShellSurface: false

  readonly property real preferredHeight: Math.round(30 * root.baseSize)
  readonly property var comboBox: combo

  signal selected(string key)

  plain: !root.dccRow
  spacing: Style.marginL

  // Less strict comparison with != (instead of !==) so it can properly compare int vs string (ex for FPS: 30 and "30")
  readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey != defaultValue)

  // Plain-dict mirror for all binding-side row reads. model.get()/model.<role>
  // inside bindings capture the live row proxy and crash in
  // QQmlListModel::data→captureProperty when a ListModel source mutates
  // (DESIGN §1.7). Rebuilt from JS handlers, where get() is safe.
  property var _modelRows: []

  function _rebuildRows() {
    var rows = [];
    if (root.model) {
      if (Array.isArray(root.model)) {
        rows = root.model.slice();
      } else if (typeof root.model.get === 'function') {
        for (var i = 0; i < root.model.count; i++) {
          var r = root.model.get(i);
          rows.push({
                      "key": r.key,
                      "name": r.name
                    });
        }
      }
    }
    _modelRows = rows;
  }

  Component.onCompleted: _rebuildRows()
  onModelChanged: _rebuildRows()

  // The source may be a plain array — Connections needs a QObject target,
  // so only hook mutation signals when the model is a real ListModel.
  Connections {
    target: (root.model && typeof root.model.count === "number") ? root.model : null
    ignoreUnknownSignals: true
    function onCountChanged() {
      root._rebuildRows();
    }
    function onDataChanged() {
      root._rebuildRows();
    }
  }

  readonly property string indicatorTooltip: {
    if (defaultValue === undefined)
      return "";
    var displayValue = "";
    var found = false;
    for (var i = 0; i < _modelRows.length; i++) {
      var item = _modelRows[i];
      if (item && item.key === defaultValue) {
        displayValue = item.name || (defaultValue === "" ? I18n.tr("panels.indicator.system-default") : String(defaultValue));
        found = true;
        break;
      }
    }
    if (!found) {
      displayValue = defaultValue === "" ? I18n.tr("panels.indicator.system-default") : String(defaultValue);
    }
    return I18n.tr("panels.indicator.default-value", {
                     "value": displayValue
                   });
  }

  function itemCount() {
    return _modelRows.length;
  }

  function getItem(index) {
    return _modelRows[index] ?? null;
  }

  function findIndexByKey(key) {
    for (var i = 0; i < _modelRows.length; i++) {
      var item = _modelRows[i];
      if (item && item.key === key)
        return i;
    }
    return -1;
  }

  NLabel {
    id: titleLabel

    label: root.label
    description: root.description
    labelWeight: Style.fontWeightRegular
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
    Layout.fillWidth: true
    // §3.5.4: the title sits in a fixed column, the field takes the rest —
    // without this cap a fixed-width combo starves the label to ~50 px and
    // mid-length titles wrap ("一周的第一/天"). The floor keeps the label on
    // one line when the field still has room to give (it shrinks first).
    Layout.maximumWidth: root.dccRow ? Style.settingsFieldTitleWidth : Number.POSITIVE_INFINITY
    Layout.minimumWidth: root.dccRow ? Math.min(titleLabel.labelImplicitWidth, Style.settingsFieldTitleWidth) : 0
  }

  ComboBox {
    id: combo

    // Disabled keeps full opacity and swaps colors instead: a 0.6 alpha over
    // the field's dark fill blends toward the row and looks *brighter*
    // (DDE uses textDisabledDark, DESIGN §1.1).
    Layout.margins: Style.borderS
    // Fixed width trio: minimum/preferred/maximum depend only on the plain
    // root.minimumWidth property and Style tokens. Never read root.width (the
    // row's own laid-out width) here and never feed an attached Layout value
    // back into implicitWidth — that round-trip is the recursive-rearrange
    // feedback loop fixed for NSearchableComboBox in 63db30154.
    Layout.fillWidth: true
    // A settings row pins the control column (DESIGN §3.5.4 控件列宽) so the
    // fields of neighbouring rows line up; a bare combo still follows its own
    // minimumWidth so popups and the launcher keep sizing to content.
    Layout.minimumWidth: root.dccRow ? Style.settingsFieldWidth : Math.round(120 * Style.uiScaleRatio)
    Layout.preferredWidth: root.dccRow ? Style.settingsFieldWidth : Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.maximumWidth: root.dccRow ? Style.settingsFieldWidth : Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.preferredHeight: Math.round(root.preferredHeight * Style.uiScaleRatio)
    // Plain-dict mirror rows — never the live ListModel (DESIGN §1.7).
    model: root._modelRows
    textRole: "name"
    currentIndex: root.findIndexByKey(root.currentKey)

    onActivated: {
      var item = root.getItem(combo.currentIndex);
      if (item && item.key !== undefined)
        root.selected(item.key);
    }

    Keys.onUpPressed: event => {
                        if (combo.popup.visible) {
                          if (listView.currentIndex > 0) {
                            listView.currentIndex--;
                            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                          }
                          event.accepted = true;
                        } else {
                          event.accepted = false;
                        }
                      }

    Keys.onDownPressed: event => {
                          if (combo.popup.visible) {
                            if (listView.currentIndex < root.itemCount() - 1) {
                              listView.currentIndex++;
                              listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                            }
                            event.accepted = true;
                          } else {
                            event.accepted = false;
                          }
                        }

    Keys.onReturnPressed: event => {
                            if (combo.popup.visible) {
                              var item = root.getItem(listView.currentIndex);
                              if (item && item.key !== undefined) {
                                root.selected(item.key);
                                combo.currentIndex = listView.currentIndex;
                                combo.popup.close();
                              }
                              event.accepted = true;
                            } else {
                              event.accepted = false;
                            }
                          }

    Keys.onEnterPressed: event => {
                           combo.Keys.returnPressed(event);
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

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
          if (root.tooltip != "") {
            TooltipService.show(root, root.tooltip);
          }
        }
        onExited: {
          if (root.tooltip != "") {
            TooltipService.hide();
          }
        }
      }
    }

    contentItem: NText {
      leftPadding: Style.marginL
      rightPadding: combo.indicator.width + Style.marginL
      pointSize: Style.fontSizeM
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      // Stay opaque: the disabled signal is the color swap, not extra alpha.
      opacity: 1.0
      color: combo.enabled ? (combo.currentIndex >= 0 ? Colors.onShell : Colors.onShellTertiary) : Colors.textDisabledDark
      text: {
        if (combo.currentIndex >= 0 && combo.currentIndex < root.itemCount()) {
          var item = root.getItem(combo.currentIndex);
          return item ? item.name : root.placeholder;
        }
        return root.placeholder;
      }
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
      implicitWidth: combo.width
      implicitHeight: Math.min(Math.round(root.popupHeight * Style.uiScaleRatio), listView.contentHeight + Style.margin2M)
      padding: Style.marginS
      enter: NPopupEnter {}
      exit: NPopupExit {}

      onOpened: {
        listView.currentIndex = combo.currentIndex;
        listView.positionViewAtIndex(combo.currentIndex, ListView.Beginning);
      }

      contentItem: NListView {
        id: listView
        property var comboBox: combo
        gradientColor: "transparent"
        model: combo.popup.visible ? root._modelRows : null
        highlightMoveDuration: 0
        // Overlay scrollbar: a permanent empty gutter would offset the
        // highlight from the frame edge; the thumb shows whenever the list
        // overflows so hidden rows stay discoverable.
        reserveScrollbarSpace: false
        showScrollbarWhenScrollable: true

        // Dark menu rows (DESIGN §3.3): accent highlight, radiusRow corners
        // inside the popup padding (DDE hover block pairs with the frame).
        delegate: Rectangle {
          id: delegateRect
          required property int index
          property bool isHighlighted: listView.currentIndex === index

          width: listView.availableWidth
          height: delegateText.implicitHeight + Style.margin2S
          radius: Style.radiusRow
          color: isHighlighted ? Colors.accent : "transparent"

          NText {
            id: delegateText
            anchors.fill: parent
            anchors.leftMargin: 20 * Style.uiScaleRatio
            anchors.rightMargin: 20 * Style.uiScaleRatio
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            pointSize: Style.fontSizeM
            color: delegateRect.isHighlighted ? Colors.onAccent : Colors.onShell
            text: {
              var item = root._modelRows[delegateRect.index];
              return item && item.name ? item.name : "";
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
              if (containsMouse) {
                listView.currentIndex = delegateRect.index;
              }
            }
            onClicked: {
              var item = root.getItem(delegateRect.index);
              if (item && item.key !== undefined) {
                root.selected(item.key);
                listView.comboBox.currentIndex = delegateRect.index;
                listView.comboBox.popup.close();
              }
            }
          }
        }
      }

      background: NArrowRect {
        // Page-surface menus stay opaque (Colors.popupPage) — popupShell's
        // translucency (built for blurred shell popups) bleeds page text
        // through the list. On a shell surface the glass look is intentional.
        arrowEdge: ""
        fillColor: root.onShellSurface ? Colors.popupShell : Colors.popupPage
        borderColor: root.onShellSurface ? Colors.borderShell : Colors.mOutline
        borderWidth: Style.borderS
        radius: Style.radiusPopup
        shadow: Style.shadowPopup
      }
    }

    Connections {
      target: root
      function onCurrentKeyChanged() {
        combo.currentIndex = root.findIndexByKey(root.currentKey);
      }
      function onModelChanged() {
        combo.currentIndex = root.findIndexByKey(root.currentKey);
      }
    }
  }
}
