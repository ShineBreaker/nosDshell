import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

/**
* NToggle - a DDE SwitchWidget row (DESIGN §3.5.4).
*
* With a label it presents as a SettingsItem row: title on the left, the
* 40x22 DSwitchButton on the right (off = white x 0.2, on = accent, 18 px white
* knob, 150 ms). Without a label — the dock/panel popups — it falls back to the
* bare switch, which is what `dccRow: false` selects.
*/
NDccRow {
  id: root

  property string label: ""
  property string description: ""
  property string icon: ""
  property bool checked: false
  property bool hovering: false
  property int baseSize: Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio)
  property var defaultValue: undefined
  property string settingsPath: ""
  // A labelled toggle is a settings row; a bare one is not.
  property bool dccRow: label !== "" || description !== ""

  signal toggled(bool checked)
  signal entered
  signal exited

  plain: !root.dccRow
  spacing: Style.marginM

  readonly property bool isValueChanged: (defaultValue !== undefined) && (checked !== defaultValue)
  readonly property string indicatorTooltip: defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {
                                                                                    "value": typeof defaultValue === "boolean" ? (defaultValue ? "true" : "false") : String(defaultValue)
                                                                                  }) : ""

  NLabel {
    Layout.fillWidth: true
    label: root.label
    description: root.description
    icon: root.icon
    labelWeight: Style.fontWeightRegular
    iconColor: root.checked ? Color.accent : Color.onShell
    visible: root.label !== "" || root.description !== ""
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  // DSwitchButton: 40x22 capsule, off = white x 0.2, on = accent, white 18px knob (DESIGN §3.5.4)
  readonly property real _switchScale: Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio) > 0 ? root.baseSize / Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio) : 1

  Rectangle {
    id: switcher

    opacity: enabled ? 1.0 : 0.6
    Layout.alignment: Qt.AlignVCenter
    Layout.margins: Style.borderS
    implicitWidth: Math.round(40 * root._switchScale)
    implicitHeight: Math.round(22 * root._switchScale)
    radius: height / 2
    color: root.checked ? Color.accent : Color.overlay("strong")

    Behavior on color {
      ColorAnimation {
        duration: Style.motionSwitch
      }
    }

    Rectangle {
      implicitWidth: Math.round(18 * root._switchScale)
      implicitHeight: Math.round(18 * root._switchScale)
      radius: height / 2
      color: "#FFFFFF"
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 0
      x: root.checked ? switcher.width - width - 2 : 2

      Behavior on x {
        NumberAnimation {
          duration: Style.motionSwitch
          easing.type: Easing.OutCubic
        }
      }
    }

    MouseArea {
      enabled: root.enabled
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: {
        if (!enabled)
          return;
        hovering = true;
        root.entered();
      }
      onExited: {
        if (!enabled)
          return;
        hovering = false;
        root.exited();
      }
      onClicked: {
        if (!enabled)
          return;
        root.toggled(!root.checked);
      }
    }
  }
}
