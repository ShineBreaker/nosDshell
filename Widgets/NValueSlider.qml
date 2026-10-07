import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NDccRow {
  id: root

  property real from: 0
  property real to: 1
  property real value: 0
  property real stepSize: 0.01
  property var cutoutColor: Color.mSurface
  property bool snapAlways: true
  property real heightRatio: 0.7
  property string text: ""
  property real textSize: Style.fontSizeM
  property real customHeight: -1
  property real customHeightRatio: -1
  property string label: ""
  property string description: ""
  property var defaultValue: undefined
  property bool showReset: false
  // A labelled slider is a settings row; a bare one is not.
  property bool dccRow: label !== "" || description !== ""

  // Signals
  signal moved(real value)
  signal pressedChanged(bool pressed, real value)

  plain: !root.dccRow
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property bool sliderActive: slider.activeFocus || slider.pressed
  readonly property bool isValueChanged: defaultValue !== undefined && (value !== defaultValue)
  readonly property string indicatorTooltip: {
    if (defaultValue === undefined)
      return "";
    var defaultVal = defaultValue;
    if (typeof defaultVal === "number") {
      // If it's a decimal between 0 and 1, format as percentage
      if (defaultVal > 0 && defaultVal <= 1 && from >= 0 && from < 1) {
        return I18n.tr("panels.indicator.default-value", {
                         "value": Math.floor(defaultVal * 100) + "%"
                       });
      }
      return I18n.tr("panels.indicator.default-value", {
                       "value": String(defaultVal)
                     });
    }
    return I18n.tr("panels.indicator.default-value", {
                     "value": String(defaultVal)
                   });
  }

  // §3.5.4 DCCSlider: the title (and its value) sit on one line, the 2 px
  // groove runs underneath. A bare slider — the audio/brightness popups — keeps
  // the value beside the groove instead, since it has no title line.
  ColumnLayout {
    spacing: Style.settingsSliderTitleGap
    Layout.fillWidth: true

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM
      visible: root.dccRow && (root.label !== "" || root.description !== "" || root.text !== "")

      NLabel {
        label: root.label
        description: root.description
        labelWeight: Style.fontWeightRegular
        visible: root.label !== "" || root.description !== ""
        showIndicator: root.isValueChanged
        indicatorTooltip: root.indicatorTooltip
        Layout.fillWidth: true
      }

      NText {
        visible: root.text !== ""
        text: root.text
        pointSize: root.textSize
        family: Settings.data.ui.fontFixed
        color: Color.onShellSecondary
        opacity: root.enabled ? 1.0 : 0.6
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
      }
    }

    RowLayout {
      spacing: Style.marginL
      Layout.fillWidth: true

      NSlider {
        id: slider
        Layout.fillWidth: true
        from: root.from
        to: root.to
        value: root.value
        stepSize: root.stepSize
        cutoutColor: root.cutoutColor
        snapAlways: root.snapAlways
        heightRatio: root.customHeightRatio > 0 ? root.customHeightRatio : root.heightRatio
        onMoved: root.moved(value)
        onPressedChanged: root.pressedChanged(pressed, value)
      }

      NText {
        visible: !root.dccRow && root.text !== ""
        text: root.text
        pointSize: root.textSize
        family: Settings.data.ui.fontFixed
        color: Color.onShellSecondary
        opacity: root.enabled ? 1.0 : 0.6
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 45 * Style.uiScaleRatio
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  Item {
    id: buttonItem
    visible: root.showReset && root.defaultValue !== undefined
    Layout.preferredWidth: Style.settingsFieldHeight
    Layout.preferredHeight: Style.settingsFieldHeight

    NIconButton {
      icon: "restore"
      enabled: root.enabled
      baseSize: Style.baseWidgetSize * 0.8
      tooltipText: I18n.tr("common.reset")
      onClicked: root.moved(root.defaultValue)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
