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

  readonly property real preferredHeight: Math.round(30 * root.baseSize)
  readonly property var comboBox: combo

  signal selected(string key)

  plain: !root.dccRow
  spacing: Style.marginL

  // Less strict comparison with != (instead of !==) so it can properly compare int vs string (ex for FPS: 30 and "30")
  readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey != defaultValue)

  readonly property string indicatorTooltip: {
    if (defaultValue === undefined)
      return "";
    var displayValue = "";
    if (defaultValue === "") {
      // Try to find the display name for empty key in the model
      var found = false;
      if (root.model) {
        if (Array.isArray(root.model)) {
          for (var i = 0; i < root.model.length; i++) {
            var item = root.model[i];
            if (item && item.key === "") {
              displayValue = item.name || I18n.tr("panels.indicator.system-default");
              found = true;
              break;
            }
          }
        } else if (typeof root.model.get === 'function') {
          for (var i = 0; i < root.itemCount(); i++) {
            var item = root.getItem(i);
            if (item && item.key === "") {
              displayValue = item.name || I18n.tr("panels.indicator.system-default");
              found = true;
              break;
            }
          }
        }
      }
      // If not found in model, show "System Default" instead of "(empty)"
      if (!found) {
        displayValue = I18n.tr("panels.indicator.system-default");
      }
    } else {
      // Try to find the display name for the default key in the model
      var found = false;
      if (root.model) {
        if (Array.isArray(root.model)) {
          for (var i = 0; i < root.model.length; i++) {
            var item = root.model[i];
            if (item && item.key === defaultValue) {
              displayValue = item.name || String(defaultValue);
              found = true;
              break;
            }
          }
        } else if (typeof root.model.get === 'function') {
          for (var i = 0; i < root.itemCount(); i++) {
            var item = root.getItem(i);
            if (item && item.key === defaultValue) {
              displayValue = item.name || String(defaultValue);
              found = true;
              break;
            }
          }
        }
      }
      if (!found) {
        displayValue = String(defaultValue);
      }
    }
    return I18n.tr("panels.indicator.default-value", {
                     "value": displayValue
                   });
  }

  function itemCount() {
    if (!root.model)
      return 0;
    if (typeof root.model.count === 'number')
      return root.model.count;
    if (Array.isArray(root.model))
      return root.model.length;
    return 0;
  }

  function getItem(index) {
    if (!root.model)
      return null;
    if (typeof root.model.get === 'function')
      return root.model.get(index);
    if (Array.isArray(root.model))
      return root.model[index];
    return null;
  }

  function findIndexByKey(key) {
    for (var i = 0; i < itemCount(); i++) {
      var item = getItem(i);
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
    Layout.minimumWidth: Math.round(120 * Style.uiScaleRatio)
    Layout.preferredWidth: Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.maximumWidth: Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.preferredHeight: Math.round(root.preferredHeight * Style.uiScaleRatio)
    model: root.model
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
      color: combo.enabled ? Color.overlay("field") : Color.overlay("idle")
      border.color: combo.activeFocus ? Color.accent : "transparent"
      border.width: Style.borderS
      radius: Style.settingsFieldRadius

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
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
      color: combo.enabled ? (combo.currentIndex >= 0 ? Color.onShell : Color.onShellTertiary) : Color.textDisabledDark
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
      color: combo.enabled ? Color.onShellSecondary : Color.textDisabledDark
    }

    popup: Popup {
      y: combo.height + Style.marginS
      implicitWidth: combo.width
      implicitHeight: Math.min(Math.round(root.popupHeight * Style.uiScaleRatio), listView.contentHeight + Style.margin2M)
      padding: 0

      onOpened: {
        listView.currentIndex = combo.currentIndex;
        listView.positionViewAtIndex(combo.currentIndex, ListView.Beginning);
      }

      contentItem: NListView {
        id: listView
        property var comboBox: combo
        model: combo.popup.visible ? root.model : null
        highlightMoveDuration: 0
        //showGradientMasks: false

        // Dark menu rows (DESIGN §3.3): full-row accent highlight, no row radius
        delegate: Rectangle {
          id: delegateRect
          required property int index
          property bool isHighlighted: listView.currentIndex === index

          width: listView.availableWidth
          height: delegateText.implicitHeight + 8
          radius: 0
          color: isHighlighted ? Color.accent : "transparent"

          NText {
            id: delegateText
            anchors.fill: parent
            anchors.leftMargin: 20 * Style.uiScaleRatio
            anchors.rightMargin: 20 * Style.uiScaleRatio
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            pointSize: Style.fontSizeM
            color: delegateRect.isHighlighted ? Color.onAccent : Color.onShell
            text: {
              var item = root.getItem(delegateRect.index);
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

      background: Rectangle {
        color: Color.popupShell
        border.color: Color.borderShell
        border.width: Style.borderS
        radius: Style.radiusPopup
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
