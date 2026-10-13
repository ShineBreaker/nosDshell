import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Cards
import qs.Modules.Panels.ControlCenter
import qs.Services.Hardware
import qs.Services.Media
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterQuickControl - the fixed bottom quick-control panel (§3.5.2).
*
* Cards page (first): the enabled controlCenter.cards — weather, media,
* system monitor — as the home page's default widgets. Basic page: volume +
* brightness sliders (24 px glyphs at both ends, brightness hidden when
* unavailable) and two rows of quick switch buttons taken from
* controlCenter.shortcuts.left ++ .right (5 per row, 10 shown — no overflow
* pages). Detail pages: Wi-Fi, Bluetooth, VPN — reusing the same
* services as the existing panels, styled per §3.5.4.
*/
Item {
  id: root

  property var screen: null
  // Collapses the strip down to its handle so the notification list above
  // can use the freed space; in-session only.
  property bool collapsed: false

  readonly property real listWidth: Math.max(1, root.width - Style.margin2M)

  // ---------------- pages ----------------
  // Page 0 is the cards page (the home page's default widgets), page 1 the
  // basic page; detail pages follow.
  readonly property var cards: Settings.data.controlCenter.cards

  // Up to ten switches on the basic page (5 per row); the rest are simply
  // not shown — the settings UI lets the user pick which ones matter.
  readonly property var shortcuts: (Settings.data.controlCenter.shortcuts?.left).concat(Settings.data.controlCenter.shortcuts?.right).slice(0, 10)

  readonly property var detailPages: {
    var pages = ["wifi"];
    if (BluetoothService.bluetoothAvailable)
      pages.push("bluetooth");
    if (VPNService.connections && Object.keys(VPNService.connections).length > 0)
      pages.push("vpn");
    return pages;
  }

  readonly property int pageCount: 2 + detailPages.length
  property int currentPage: 0

  // Direction of the last page turn (+1 next / -1 previous); the incoming page
  // slides in from that side.
  property int navDirection: 1

  readonly property string currentDetailPage: {
    const idx = currentPage - 2;
    return (idx >= 0 && idx < detailPages.length) ? detailPages[idx] : "";
  }

  function nextPage() {
    navDirection = 1;
    currentPage = (currentPage + 1) % pageCount;
  }

  function previousPage() {
    navDirection = -1;
    currentPage = (currentPage - 1 + pageCount) % pageCount;
  }

  onPageCountChanged: {
    if (currentPage >= pageCount)
      currentPage = Math.max(0, pageCount - 1);
  }

  // The strip follows the current page's own height — the cards page reports
  // its real content (weather card grows with data, media/sysmon row is
  // fixed), the basic/detail pages use the quickControlPanelHeight token —
  // plus the collapse handle and the page indicator.
  implicitHeight: collapseBar.implicitHeight + (collapsed ? 0 : content.implicitHeight + Style.pageIndicatorHeight)

  Behavior on implicitHeight {
    NumberAnimation {
      duration: Style.motionPanel
      easing.type: Easing.InOutCubic
    }
  }

  clip: true

  // Select a page by id ("cards"/"basic" or wifi/bluetooth/vpn);
  // pages unavailable in this environment fall back to the cards page.
  function openPage(name) {
    var target = 0;
    if (name === "basic")
      target = 1;
    else if (name !== "cards") {
      const idx = detailPages.indexOf(name);
      if (idx >= 0)
        target = 2 + idx;
    }
    navDirection = target >= currentPage ? 1 : -1;
    currentPage = target;
  }

  Component.onCompleted: {
    if (NetworkService.wifiEnabled && !NetworkService.scanningActive)
      NetworkService.scan();
    VPNService.refresh();
  }

  // Slide-in transition for the incoming page: a directional settle matching
  // the module-view slide language (Style.motionPanel). Transform-based so the
  // anchored layout never fights the animation.
  onCurrentPageChanged: pageSettle.restart()

  ParallelAnimation {
    id: pageSettle

    NumberAnimation {
      target: pageSlide
      property: "x"
      from: root.navDirection * root.pageEnterOffset
      to: 0
      duration: Style.motionPanel
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: content
      property: "opacity"
      from: 0
      to: 1
      duration: Style.motionPanel
      easing.type: Easing.OutCubic
    }
  }

  readonly property real pageEnterOffset: Math.round(root.width * 0.12)

  // Collapse handle: slim top bar with a centered chevron; the notification
  // list above gets the freed space while collapsed.
  Item {
    id: collapseBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    implicitHeight: Math.round(Style.baseWidgetSize * 0.8)

    NIconButton {
      anchors.centerIn: parent
      icon: root.collapsed ? "chevron-up" : "chevron-down"
      baseSize: collapseBar.implicitHeight
      tooltipText: root.collapsed ? I18n.tr("panels.control-center.quick-controls-expand") : I18n.tr("panels.control-center.quick-controls-collapse")
      onClicked: root.collapsed = !root.collapsed
    }
  }

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: collapseBar.bottom
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.pageIndicatorHeight
    spacing: 0
    visible: !root.collapsed
    opacity: 1
    transform: Translate {
      id: pageSlide
      x: 0
    }

    // ---------------- cards page (first page) ----------------
    Item {
      id: cardsPage
      Layout.fillWidth: true
      // The cards page reports its own height: enabled cards' implicit
      // heights plus top/bottom breathing room — no dead space under
      // whichever cards are on.
      Layout.preferredHeight: cardsCol.implicitHeight + Style.margin2M
      visible: root.currentPage === 0

      // If cards ever outgrow the panel the page still scrolls.
      NScrollView {
        id: cardsScroll
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginM
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        gradientColor: Color.maskShell
        ScrollBar.horizontal.visible: false

        ColumnLayout {
          id: cardsCol
          width: cardsScroll.availableWidth
          spacing: Style.marginM

          Repeater {
            model: root.cards

            delegate: Loader {
              required property var modelData
              active: modelData.enabled && (modelData.id !== "weather-card" || Settings.data.location.weatherEnabled)
              visible: active
              Layout.fillWidth: true

              sourceComponent: {
                switch (modelData.id) {
                case "weather-card":
                  return cardWeather;
                case "media-sysmon-card":
                  return cardMediaSysmon;
                }
              }
            }
          }
        }
      }
    }

    // ---------------- basic page ----------------
    Item {
      id: basicPage
      Layout.fillWidth: true
      // Content-driven like the cards page — a short switch list hugs its
      // rows instead of padding out to the list-page slot height.
      Layout.preferredHeight: basicCol.implicitHeight + Style.margin2M
      visible: root.currentPage === 1

      ColumnLayout {
        id: basicCol
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        spacing: Style.marginS

        // Volume slider
        RowLayout {
          id: volumeRow
          Layout.fillWidth: true
          Layout.preferredHeight: Style.sliderBasicHeight
          spacing: Style.marginS

          property real localVolume: AudioService.volume

          // Service-side refreshes (wpctl polls) must not yank the knob while a
          // drag is in progress — same guard the brightness row uses.
          Connections {
            target: AudioService
            function onVolumeChanged() {
              if (!volumeSlider.pressed)
                volumeRow.localVolume = AudioService.volume;
            }
          }

          NIcon {
            icon: "volume-off"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }

          NSlider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0
            to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
            value: volumeRow.localVolume
            stepSize: 0.01
            heightRatio: 0.5
            onMoved: {
              volumeRow.localVolume = value;
              AudioService.setVolume(value);
            }
            tooltipText: `${Math.round(value * 100)}%`
          }

          NIcon {
            icon: "volume-high"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }
        }

        // Brightness slider (hidden when brightness control is unavailable)
        RowLayout {
          id: brightnessRow
          Layout.fillWidth: true
          Layout.preferredHeight: Style.sliderBasicHeight
          Layout.topMargin: Style.marginS
          spacing: Style.marginS
          visible: brightnessMonitor !== null && brightnessMonitor.brightnessControlAvailable

          readonly property var brightnessMonitor: BrightnessService.getMonitorForScreen(root.screen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)) ?? null

          Connections {
            target: brightnessRow.brightnessMonitor
            ignoreUnknownSignals: true
            function onBrightnessUpdated() {
              const bm = brightnessRow.brightnessMonitor;
              if (bm && !brightnessSlider.pressed)
                brightnessRow.localBrightness = bm.brightness || 0;
            }
          }

          property real localBrightness: brightnessMonitor ? (brightnessMonitor.brightness || 0) : 0

          NIcon {
            icon: "brightness-low"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }

          NSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: brightnessRow.localBrightness
            stepSize: 0.01
            heightRatio: 0.5
            onMoved: {
              brightnessRow.localBrightness = value;
              brightnessRow.brightnessMonitor?.setBrightness(value);
            }
            tooltipText: `${Math.round(value * 100)}%`
          }

          NIcon {
            icon: "brightness-high"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }
        }

        // Quick switch rows: 5 per row, 10 shown — cells are 70 px wide
        // (Style.quickSwitchWidth); the grid is centred so a shorter button
        // count still lands in DDE's rhythm.
        SwitchGrid {
          Layout.preferredHeight: switchRows * Style.quickSwitchHeight + Math.max(0, switchRows - 1) * Style.marginS
          Layout.preferredWidth: Math.min(parent.width, naturalWidth)
          Layout.topMargin: Style.marginS
          Layout.alignment: Qt.AlignHCenter
          items: root.currentPage === 1 ? root.shortcuts : []
          baseIndex: 0
        }
      }
    }

    // ---------------- detail pages ----------------
    Item {
      Layout.fillWidth: true
      // Hug short lists (margin on top only — rows pad themselves), cap at
      // the token height and scroll beyond it.
      Layout.preferredHeight: Math.min(detailContent.implicitHeight + Style.marginM, Style.quickControlPanelHeight)
      visible: root.currentDetailPage !== ""

      // Lists are confined to the page slot and scroll when they exceed it —
      // an unclipped column used to spill over the page indicator.
      NScrollView {
        id: detailScroll
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginM
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        gradientColor: Color.maskShell
        ScrollBar.horizontal.visible: false

        ControlCenterDetailPages {
          id: detailContent
          width: detailScroll.availableWidth
          screen: root.screen
          page: root.currentDetailPage
        }
      }
    }
  }

  // The quick-switch cell grid on the basic page — 5 columns, up to 2 rows.
  // items is the (already capped) slice; baseIndex is the absolute offset
  // into root.shortcuts for widget bookkeeping.
  component SwitchGrid: GridLayout {
    id: switchGrid
    property var items: []
    property int baseIndex: 0
    readonly property int switchRows: Math.ceil(items.length / 5)
    // Centre short rows: width hugs the last row's cell count so a short
    // page is centred, not left-aligned in a 5-cell box.
    readonly property int rowCellCount: Math.min(5, items.length)
    readonly property real naturalWidth: rowCellCount * Style.quickSwitchWidth + Math.max(0, rowCellCount - 1) * Style.marginXS

    columns: Math.max(1, rowCellCount)
    columnSpacing: Style.marginXS
    rowSpacing: Style.marginS

    Repeater {
      model: switchGrid.items

      delegate: QuickSwitchButton {
        required property var modelData
        required property int index

        // The model is sliced to this page, so index is page-local;
        // absoluteIndex is the position in the full shortcut list.
        readonly property int absoluteIndex: switchGrid.baseIndex + index
        readonly property var widgetData: modelData

        widgetId: widgetData !== undefined ? widgetData.id : ""
        widgetScreen: root.screen
        widgetProps: widgetData !== undefined ? {
                                                  "widgetId": widgetData.id,
                                                  "section": "quickSettings",
                                                  "sectionWidgetIndex": absoluteIndex,
                                                  "sectionWidgetsCount": root.shortcuts.length,
                                                  "widgetSettings": widgetData
                                                } : null
      }
    }
  }

  PageIndicator {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    visible: !root.collapsed
    pageCount: root.pageCount
    currentPage: root.currentPage
    onNextRequested: root.nextPage()
    onPreviousRequested: root.previousPage()
  }

  Component {
    id: cardWeather
    WeatherCard {}
  }

  Component {
    id: cardMediaSysmon
    RowLayout {
      spacing: Style.marginS

      MediaCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.controlCenterMediaCardRowHeight
      }

      SystemMonitorCard {
        Layout.preferredWidth: Math.round(Style.baseWidgetSize * 2.625)
        Layout.fillHeight: true
      }
    }
  }
}
