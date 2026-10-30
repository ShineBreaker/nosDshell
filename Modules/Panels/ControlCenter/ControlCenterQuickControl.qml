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
* Page order comes from controlCenter.quickPageOrder; a page drops out when
* its content is all toggled off or its service is unavailable. Cards page:
* the enabled controlCenter.cards — weather, media, system monitor. Basic
* page: volume + brightness sliders (24 px glyphs at both ends) and two rows
* of quick switch buttons taken from controlCenter.shortcuts.left ++ .right
* (5 per row, 10 shown — no overflow pages); each region obeys its card
* toggle (audio-card/brightness-card/shortcuts-card). Detail pages: Wi-Fi,
* Bluetooth, VPN — reusing the same services as the existing panels, styled
* per §3.5.4.
*/
Item {
  id: root

  property var screen: null
  // Collapses the strip down to the indicator band so the notification
  // list above can use the freed space; in-session only.
  property bool collapsed: false

  readonly property real listWidth: Math.max(1, root.width - Style.margin2M)

  // ---------------- pages ----------------
  // The strip's pages live in controlCenter.quickPageOrder (§3.5.2):
  // "cards" = the enabled controlCenter.cards, "basic" = sliders + switch
  // grid, then the detail pages. A page drops out of the strip when its
  // content is all toggled off or its service is unavailable; ids missing
  // from the stored order append at the end in canonical order.
  readonly property var _knownPages: ["cards", "basic", "wifi", "bluetooth", "vpn"]

  // Only ids this page actually renders — profile/shortcuts/audio/brightness
  // cards were redistributed to the header, switch grid and basic page per
  // DESIGN §3.5.2, so their (still enabled) settings entries must not reach
  // the Repeater: an unmapped id loads a zero-height Loader that still eats
  // a layout slot + column spacing and opens a dead band above the cards.
  readonly property var cards: (Settings.data.controlCenter.cards || []).filter(c => ["weather-card", "media-sysmon-card"].indexOf(c.id) >= 0)
  readonly property var enabledCards: cards.filter(c => c.enabled && (c.id !== "weather-card" || Settings.data.location.weatherEnabled))

  // Up to ten switches on the basic page (5 per row); the rest are simply
  // not shown — the settings UI lets the user pick which ones matter.
  readonly property var shortcuts: (Settings.data.controlCenter.shortcuts?.left).concat(Settings.data.controlCenter.shortcuts?.right).slice(0, 10)

  function cardEnabled(id) {
    const arr = Settings.data.controlCenter.cards || [];
    for (var i = 0; i < arr.length; i++)
      if (arr[i] && arr[i].id === id)
        return !!arr[i].enabled;
    return false;
  }

  // Hoisted so both the row and the page-availability check see the same
  // monitor lookup.
  readonly property var brightnessMonitor: BrightnessService.getMonitorForScreen(root.screen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)) ?? null
  readonly property bool brightnessUsable: root.cardEnabled("brightness-card") && root.brightnessMonitor !== null && root.brightnessMonitor.brightnessControlAvailable

  function pageAvailable(id) {
    switch (id) {
    case "cards":
      return enabledCards.length > 0;
    case "basic":
      return cardEnabled("audio-card") || cardEnabled("shortcuts-card") || brightnessUsable;
    case "wifi":
      return true;
    case "bluetooth":
      return BluetoothService.bluetoothAvailable;
    case "vpn":
      return VPNService.connections && Object.keys(VPNService.connections).length > 0;
    }
    return false;
  }

  readonly property var orderedPages: {
    const declared = Settings.data.controlCenter.quickPageOrder || [];
    var seq = [];
    declared.forEach(id => {
                       if (_knownPages.indexOf(id) !== -1 && seq.indexOf(id) === -1)
                       seq.push(id);
                     });
    _knownPages.forEach(id => {
                          if (seq.indexOf(id) === -1)
                          seq.push(id);
                        });
    return seq.filter(id => pageAvailable(id));
  }

  readonly property int pageCount: orderedPages.length

  // The shown page is stored BY ID, not index — a reorder or availability
  // flip re-seats the derived index on the same page automatically instead
  // of silently switching content. A page that drops out of orderedPages
  // snaps to the first ordered page (onOrderedPagesChanged below).
  property string currentPageId: ""
  readonly property int currentPage: {
    const idx = orderedPages.indexOf(currentPageId);
    return idx >= 0 ? idx : 0;
  }
  readonly property string currentDetailPage: ["wifi", "bluetooth", "vpn"].indexOf(currentPageId) >= 0 ? currentPageId : ""

  // Direction of the last page turn (+1 next / -1 previous); the incoming page
  // slides in from that side.
  property int navDirection: 1

  function nextPage() {
    navDirection = 1;
    if (pageCount > 0)
      currentPageId = orderedPages[(currentPage + 1) % pageCount];
  }

  function previousPage() {
    navDirection = -1;
    if (pageCount > 0)
      currentPageId = orderedPages[(currentPage - 1 + pageCount) % pageCount];
  }

  onOrderedPagesChanged: {
    if (orderedPages.indexOf(currentPageId) === -1)
      currentPageId = orderedPages.length > 0 ? orderedPages[0] : "";
  }

  // The strip follows the current page's own height — the cards page reports
  // its real content (weather card grows with data, media/sysmon row is
  // fixed), the basic/detail pages use the quickControlPanelHeight token —
  // plus the page indicator. Collapsed, it shrinks to the indicator band so
  // the corner chevron keeps the exact same screen position.
  implicitHeight: collapsed ? Style.pageIndicatorHeight : content.implicitHeight + Style.pageIndicatorHeight

  Behavior on implicitHeight {
    NAnim {
      duration: Style.motionPanel
      curve: "out"
    }
  }

  clip: true

  // Select a page by id (any entry of _knownPages); unknown or currently
  // unavailable pages fall back to the first ordered page.
  function openPage(name) {
    const idx = orderedPages.indexOf(name);
    const target = idx >= 0 ? idx : 0;
    navDirection = target >= currentPage ? 1 : -1;
    currentPageId = orderedPages.length > 0 ? orderedPages[target] : "";
  }

  Component.onCompleted: {
    if (!currentPageId)
      currentPageId = orderedPages.length > 0 ? orderedPages[0] : "";
    if (NetworkService.wifiEnabled && !NetworkService.scanningActive)
      NetworkService.scan();
    VPNService.refresh();
  }

  // Slide-in transition for the incoming page: a directional settle matching
  // the module-view slide language (Style.motionPage). Transform-based so the
  // anchored layout never fights the animation.
  onCurrentPageIdChanged: pageSettle.restart()

  ParallelAnimation {
    id: pageSettle

    NAnim {
      target: pageSlide
      property: "x"
      from: root.navDirection * root.pageEnterOffset
      to: 0
      duration: Style.motionPage
      curve: "out"
    }
    NAnim {
      target: content
      property: "opacity"
      from: 0
      to: 1
      duration: Style.motionPage
      curve: "out"
    }
  }

  readonly property real pageEnterOffset: Math.round(root.width * 0.12)

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.pageIndicatorHeight
    spacing: 0
    visible: !root.collapsed
    opacity: 1
    transform: Translate {
      id: pageSlide
      x: 0
    }

    // ---------------- cards page ----------------
    Item {
      id: cardsPage
      Layout.fillWidth: true
      // The cards page reports its own height: enabled cards' implicit
      // heights plus top/bottom breathing room — no dead space under
      // whichever cards are on.
      Layout.preferredHeight: cardsCol.implicitHeight + Style.margin2M
      visible: root.currentPageId === "cards"

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
        gradientColor: Colors.maskShell
        ScrollBar.horizontal.visible: false

        ColumnLayout {
          id: cardsCol
          width: cardsScroll.availableWidth
          spacing: Style.marginM

          Repeater {
            // enabledCards already filters disabled/weather-gated entries so
            // a toggled-off card never instantiates a Loader slot at all.
            model: root.enabledCards

            delegate: Loader {
              required property var modelData
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
      visible: root.currentPageId === "basic"

      ColumnLayout {
        id: basicCol
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        spacing: Style.marginS

        // Volume slider — audio-card toggle
        RowLayout {
          id: volumeRow
          Layout.fillWidth: true
          Layout.preferredHeight: Style.sliderBasicHeight
          spacing: Style.marginS
          visible: root.cardEnabled("audio-card")

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
            color: Colors.onShellSecondary
          }

          NSlider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0
            to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
            value: volumeRow.localVolume
            stepSize: 0.01
            onMoved: {
              volumeRow.localVolume = value;
              AudioService.setVolume(value);
            }
            tooltipText: `${Math.round(value * 100)}%`
          }

          NIcon {
            icon: "volume-high"
            pointSize: Style.fontSizeTitle
            color: Colors.onShellSecondary
          }
        }

        // Brightness slider — brightness-card toggle; also hidden when the
        // hardware reports no brightness control.
        RowLayout {
          id: brightnessRow
          Layout.fillWidth: true
          Layout.preferredHeight: Style.sliderBasicHeight
          Layout.topMargin: Style.marginS
          spacing: Style.marginS
          visible: root.brightnessUsable

          Connections {
            target: root.brightnessMonitor
            ignoreUnknownSignals: true
            function onBrightnessUpdated() {
              const bm = root.brightnessMonitor;
              if (bm && !brightnessSlider.pressed)
                brightnessRow.localBrightness = bm.brightness || 0;
            }
          }

          property real localBrightness: root.brightnessMonitor ? (root.brightnessMonitor.brightness || 0) : 0

          NIcon {
            icon: "brightness-low"
            pointSize: Style.fontSizeTitle
            color: Colors.onShellSecondary
          }

          NSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: brightnessRow.localBrightness
            stepSize: 0.01
            onMoved: {
              brightnessRow.localBrightness = value;
              root.brightnessMonitor?.setBrightness(value);
            }
            tooltipText: `${Math.round(value * 100)}%`
          }

          NIcon {
            icon: "brightness-high"
            pointSize: Style.fontSizeTitle
            color: Colors.onShellSecondary
          }
        }

        // Quick switch rows — shortcuts-card toggle. 5 per row, 10 shown —
        // cells are 70 px wide (Style.quickSwitchWidth); the grid is centred
        // so a shorter button count still lands in DDE's rhythm.
        SwitchGrid {
          Layout.preferredHeight: switchRows * Style.quickSwitchHeight + Math.max(0, switchRows - 1) * Style.marginS
          Layout.preferredWidth: Math.min(parent.width, naturalWidth)
          Layout.topMargin: Style.marginS
          Layout.alignment: Qt.AlignHCenter
          visible: root.cardEnabled("shortcuts-card")
          items: root.currentPageId === "basic" ? root.shortcuts : []
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
        gradientColor: Colors.maskShell
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

        // Collapse chevron, bottom-right corner: constant screen position whether
        // the strip is expanded or folded down to the indicator band — collapse
        // and re-expand are the same click target.
        NIconButton {
          anchors.right: parent.right
          anchors.rightMargin: Style.marginM
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Math.max(0, Math.round((Style.pageIndicatorHeight - implicitHeight) / 2))
          icon: root.collapsed ? "chevron-up" : "chevron-down"
          baseSize: Math.round(Style.baseWidgetSize * 0.8)
          tooltipText: root.collapsed ? I18n.tr("panels.control-center.quick-controls-expand") : I18n.tr("panels.control-center.quick-controls-collapse")
          onClicked: root.collapsed = !root.collapsed
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
