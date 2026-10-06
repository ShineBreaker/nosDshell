import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property var now: Time.now

  // Resolve settings: try user settings or defaults from BarWidgetRegistry
  readonly property string clockColor: widgetSettings.clockColor !== undefined ? widgetSettings.clockColor : widgetMetadata.clockColor
  readonly property bool useCustomFont: widgetSettings.useCustomFont !== undefined ? widgetSettings.useCustomFont : widgetMetadata.useCustomFont
  readonly property string customFont: widgetSettings.customFont !== undefined ? widgetSettings.customFont : widgetMetadata.customFont
  readonly property string formatHorizontal: widgetSettings.formatHorizontal !== undefined ? widgetSettings.formatHorizontal : widgetMetadata.formatHorizontal
  readonly property string formatVertical: widgetSettings.formatVertical !== undefined ? widgetSettings.formatVertical : widgetMetadata.formatVertical
  readonly property string tooltipFormat: widgetSettings.tooltipFormat !== undefined ? widgetSettings.tooltipFormat : widgetMetadata.tooltipFormat
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  // DDE efficient clock keeps a visible gap between its two lines; the legacy
  // negative spacing below stays for the single-capsule Noctalia look.
  readonly property int lineSpacing: widgetSettings.lineSpacing !== undefined ? widgetSettings.lineSpacing : widgetMetadata.lineSpacing
  // "fashion" = DDE fashion dock presentation: rounded-square clock tile
  // (big HH over mm digits — derived from the gxde-dock datetimewidget layout)
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"
  readonly property bool onShellSurface: efficientMode || fashionMode

  readonly property color textColor: onShellSurface ? Color.onShell : Color.resolveColorKey(clockColor)

  // DDE efficient clock: hh:mm / yyyy-MM-dd on two lines (three lines when vertical)
  readonly property string effectiveFormatHorizontal: efficientMode ? "hh:mm\\nyyyy/MM/dd" : formatHorizontal.trim()
  readonly property string effectiveFormatVertical: efficientMode ? "hh mm MM/dd" : formatVertical.trim()

  // Content dimensions for implicit sizing (efficient: text width + 20)
  readonly property real contentWidth: isBarVertical ? capsuleHeight : Math.round(horizontalLoader.implicitWidth + (efficientMode ? 20 : Style.margin2M))
  readonly property real contentHeight: isBarVertical ? Math.round(verticalLoader.implicitHeight + Style.margin2S) : capsuleHeight

  // Size: use implicit width/height
  // BarWidgetLoader sets explicit width/height to extend click area
  implicitWidth: fashionMode ? Style.dockItemThickness : contentWidth
  implicitHeight: fashionMode ? Style.dockItemThickness : contentHeight

  // DDE fashion clock tile: the original gxde-dock clock face with segmented
  // digits, drawn from the copied SVG artwork. Geometry is taken verbatim from
  // gxde-dock/plugins/datetime/datetimewidget.cpp:106-188.
  Item {
    id: fashionTile
    visible: root.fashionMode
    width: Style.dockItemThickness
    height: width
    anchors.centerIn: parent

    readonly property string iconsDir: Quickshell.shellDir + "/Assets/DDE/gxde-dock/plugins/datetime/resources/icons/"
    // datetimewidget.cpp:123 — the face is min(w, h) * 0.8 of the item
    readonly property int perfectIconSize: Math.trunc(Math.min(width, height) * Style.dockClockFaceRatio)
    // datetimewidget.cpp:132-135
    readonly property int bigNumHeight: Math.trunc(perfectIconSize * Style.dockClockBigNumHeightRatio)
    readonly property int bigNumWidth: Math.trunc(bigNumHeight * Style.dockClockBigNumWidthRatio)
    readonly property int smallNumHeight: Math.trunc(bigNumHeight * Style.dockClockSmallNumHeightRatio)
    readonly property int smallNumWidth: Math.trunc(smallNumHeight * Style.dockClockSmallNumWidthRatio)
    // datetimewidget.cpp:164-165 — the am/pm tip is two small digits wide, forced even
    readonly property int tipsWidth: (smallNumWidth * 2 + Style.dockClockBigSmallGap) & ~1
    readonly property int tipsHeight: Math.trunc(tipsWidth / 2)
    // DDE keys the widget off a "24HourFormat" setting; nosDshell has no equivalent,
    // so follow the clock's own format string (HH = 24h, hh/AP = 12h).
    // The trailing "a" makes the 12h string 5 characters like DDE's "hhmma";
    // only the first four are digits. Qt.formatDateTime keeps plain 0-9 glyphs,
    // which is why DDE pins QLocale to Chinese (datetimewidget.cpp:106-108).
    readonly property bool use24Hour: /H/.test(formatHorizontal)
    readonly property string digits: Qt.formatDateTime(root.now, use24Hour ? "HHmm" : "hhmma")

    Image {
      id: face
      source: fashionTile.iconsDir + "background.svg"
      sourceSize.width: fashionTile.perfectIconSize
      sourceSize.height: fashionTile.perfectIconSize
      width: fashionTile.perfectIconSize
      height: fashionTile.perfectIconSize
      anchors.centerIn: parent
      smooth: true
      asynchronous: true
      cache: true
    }

    // datetimewidget.cpp:140 — first big digit, horizontally offset so the
    // "HH" block plus the minutes block sit centred inside the face
    Item {
      id: bigNum1
      width: fashionTile.bigNumWidth
      height: fashionTile.bigNumHeight
      x: face.x + Math.trunc(fashionTile.perfectIconSize / 2) - fashionTile.bigNumWidth * 2 + Style.dockClockBigNumLeftBias
      y: face.y + Math.trunc(fashionTile.perfectIconSize / 2) - Math.trunc(fashionTile.bigNumHeight / 2)

      Image {
        anchors.fill: parent
        source: fashionTile.iconsDir + "big" + fashionTile.digits.charAt(0) + ".svg"
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
      }
    }

    // datetimewidget.cpp:146
    Item {
      id: bigNum2
      width: fashionTile.bigNumWidth
      height: fashionTile.bigNumHeight
      x: bigNum1.x + fashionTile.bigNumWidth + Style.dockClockBigNumGap
      y: bigNum1.y

      Image {
        anchors.fill: parent
        source: fashionTile.iconsDir + "big" + fashionTile.digits.charAt(1) + ".svg"
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
      }
    }

    // datetimewidget.cpp:154 (12h) / :179 (24h) — the small block sits on the
    // big block's baseline in 24h mode, and one pixel higher in 12h mode
    Item {
      id: smallNum1
      width: fashionTile.smallNumWidth
      height: fashionTile.smallNumHeight
      x: bigNum2.x + fashionTile.bigNumWidth + Style.dockClockBigSmallGap
      y: bigNum2.y + (fashionTile.use24Hour ? fashionTile.smallNumHeight : Style.dockClockAmPmLeftInset)

      Image {
        anchors.fill: parent
        source: fashionTile.iconsDir + "small" + fashionTile.digits.charAt(2) + ".svg"
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
      }
    }

    // datetimewidget.cpp:160 / :185
    Item {
      id: smallNum2
      width: fashionTile.smallNumWidth
      height: fashionTile.smallNumHeight
      x: smallNum1.x + fashionTile.smallNumWidth + Style.dockClockSmallNumGap
      y: smallNum1.y

      Image {
        anchors.fill: parent
        source: fashionTile.iconsDir + "small" + fashionTile.digits.charAt(3) + ".svg"
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
      }
    }

    // datetimewidget.cpp:163-174 — am/pm tip, 12h only, sitting on the big baseline
    Item {
      id: amPmTip
      visible: !fashionTile.use24Hour
      width: fashionTile.tipsWidth
      height: fashionTile.tipsHeight
      x: bigNum2.x + fashionTile.bigNumWidth + Style.dockClockBigSmallGap
      y: bigNum2.y + fashionTile.bigNumHeight - fashionTile.tipsHeight

      Image {
        anchors.fill: parent
        source: fashionTile.iconsDir + (root.now.getHours() > 11 ? "tips-pm.svg" : "tips-am.svg")
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
      }
    }
  }

  // Visual clock capsule - stays at content size, centered in parent
  Rectangle {
    id: visualClock
    visible: !root.fashionMode
    width: root.contentWidth
    height: root.contentHeight
    anchors.centerIn: parent

    radius: efficientMode ? Style.radiusPopup : Style.radiusL
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Item {
      id: clockContainer
      anchors.centerIn: parent

      // Horizontal
      Loader {
        id: horizontalLoader
        active: !isBarVertical
        anchors.centerIn: parent
        sourceComponent: ColumnLayout {
          anchors.centerIn: parent
          spacing: root.efficientMode ? root.lineSpacing : (Settings.data.bar.showCapsule ? -5 : -3)
          Repeater {
            id: repeater
            model: I18n.locale.toString(now, effectiveFormatHorizontal).split("\\n")
            NText {
              visible: text !== ""
              text: modelData
              family: useCustomFont && customFont ? customFont : Settings.data.ui.fontDefault
              Binding on pointSize {
                value: {
                  // DDE datetimewidget draws both lines with a single font size.
                  if (efficientMode)
                    return barFontSize;
                  if (repeater.model.length == 1) {
                    // Single line: Full size
                    return barFontSize;
                  } else if (repeater.model.length == 2) {
                    // Two lines: First line is bigger than the second
                    return (index == 0) ? Math.round(barFontSize * 0.9) : Math.round(barFontSize * 0.75);
                  } else {
                    // More than two lines: Make it small!
                    return Math.round(barFontSize * 0.75);
                  }
                }
              }
              applyUiScale: false
              color: textColor
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
              features: ({
                           "tnum": 1
                         })
            }
          }
        }
      }

      // Vertical
      Loader {
        id: verticalLoader
        active: isBarVertical
        anchors.centerIn: parent // Now this works without layout conflicts
        sourceComponent: ColumnLayout {
          anchors.centerIn: parent
          spacing: -2
          Repeater {
            model: I18n.locale.toString(now, effectiveFormatVertical).split(" ")
            delegate: NText {
              visible: text !== ""
              text: modelData
              family: useCustomFont && customFont ? customFont : Settings.data.ui.fontDefault
              pointSize: barFontSize
              applyUiScale: false
              color: textColor
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
              features: ({
                           "tnum": 1
                         })
            }
          }
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.open-calendar"),
        "action": "open-calendar",
        "icon": "calendar"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   // Close the context menu
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "open-calendar") {
                     PanelService.getPanel("clockPanel", screen)?.toggle(root);
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  // Build tooltip text with formatted time/date
  function buildTooltipText() {
    if (tooltipFormat && tooltipFormat.trim() !== "") {
      return I18n.locale.toString(now, tooltipFormat.trim());
    }
    // Fallback to default if no format is set
    return I18n.tr("common.calendar"); // Defaults to "Calendar"
  }

  MouseArea {
    id: clockMouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: {
      if (!PanelService.getPanel("clockPanel", screen)?.isPanelOpen) {
        TooltipService.show(root, buildTooltipText(), BarService.getTooltipDirection(root.screen?.name));
        tooltipRefreshTimer.start();
      }
    }
    onExited: {
      tooltipRefreshTimer.stop();
      TooltipService.hide();
    }
    onClicked: mouse => {
                 TooltipService.hide();
                 if (mouse.button === Qt.RightButton) {
                   PanelService.showContextMenu(contextMenu, root, screen);
                 } else {
                   PanelService.getPanel("clockPanel", screen)?.toggle(this);
                 }
               }
  }

  Timer {
    id: tooltipRefreshTimer
    interval: 1000
    repeat: true
    onTriggered: {
      if (clockMouseArea.containsMouse && !PanelService.getPanel("clockPanel", screen)?.isPanelOpen) {
        TooltipService.updateText(buildTooltipText());
      }
    }
  }
}
