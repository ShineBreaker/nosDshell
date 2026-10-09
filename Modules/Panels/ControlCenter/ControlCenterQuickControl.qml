import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
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
* Basic page: volume + brightness sliders (24 px glyphs at both ends,
* brightness hidden when unavailable) and a row of quick switch buttons taken
* from controlCenter.shortcuts.left ++ .right (5 per row, overflow spills onto
* extra switch pages). Detail pages: Wi-Fi, Bluetooth, Display, VPN — reusing
* the same services as the existing panels, styled per §3.5.4.
*/
Item {
  id: root

  property var screen: null

  readonly property real listWidth: Math.max(1, root.width - Style.margin2M)

  // ---------------- pages ----------------
  readonly property var shortcuts: (Settings.data.controlCenter.shortcuts?.left ?? []).concat(Settings.data.controlCenter.shortcuts?.right ?? [])
  // The basic page already shows the first 5; switch pages only carry the
  // overflow past them (§3.5.2 "overflow spills onto extra switch pages").
  readonly property int switchPageCount: Math.max(0, Math.ceil((shortcuts.length - 5) / 5))

  readonly property var detailPages: {
    var pages = ["wifi"];
    if (BluetoothService.bluetoothAvailable)
      pages.push("bluetooth");
    pages.push("display");
    if (VPNService.connections && Object.keys(VPNService.connections).length > 0)
      pages.push("vpn");
    return pages;
  }

  readonly property int pageCount: 1 + switchPageCount + detailPages.length
  property int currentPage: 0

  // Direction of the last page turn (+1 next / -1 previous); the incoming page
  // slides in from that side.
  property int navDirection: 1

  readonly property string currentDetailPage: {
    const idx = currentPage - 1 - switchPageCount;
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

  onSwitchPageCountChanged: {
    // Keep the current page in range when the shortcut list changes
    if (currentPage >= pageCount)
      currentPage = Math.max(0, pageCount - 1);
  }

  onPageCountChanged: {
    if (currentPage >= pageCount)
      currentPage = Math.max(0, pageCount - 1);
  }

  implicitHeight: content.implicitHeight + Style.pageIndicatorHeight
  clip: true

  // Select a page by id ("basic" or wifi/bluetooth/display/vpn); pages that
  // are unavailable in this environment fall back to the basic page.
  function openPage(name) {
    const idx = detailPages.indexOf(name);
    const target = idx >= 0 ? 1 + switchPageCount + idx : 0;
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

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.pageIndicatorHeight
    spacing: 0
    opacity: 1
    transform: Translate {
      id: pageSlide
      x: 0
    }

    // ---------------- basic page ----------------
    Item {
      id: basicPage
      Layout.fillWidth: true
      Layout.preferredHeight: Style.quickControlPanelHeight
      visible: root.currentPage === 0

      ColumnLayout {
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

        // Quick switch row(s): 5 per page, overflow on dedicated switch pages
        // Cells are 70 px wide (Style.quickSwitchWidth); the row is centred so
        // a shorter button count still lands in DDE's rhythm.
        SwitchGrid {
          Layout.preferredHeight: Style.quickSwitchHeight
          Layout.preferredWidth: Math.min(parent.width, naturalWidth)
          Layout.topMargin: Style.marginS
          Layout.alignment: Qt.AlignHCenter
          items: root.currentPage === 0 ? root.shortcuts.slice(0, Math.min(5, root.shortcuts.length)) : []
          baseIndex: 0
        }
      }
    }

    // ---------------- switch pages (overflow) ----------------
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.quickControlPanelHeight
      visible: root.currentPage >= 1 && root.currentPage <= root.switchPageCount

      // Same cell geometry and width cap as the basic row; the row is centred
      // in the page slot so a short page reads balanced instead of sparse.
      SwitchGrid {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.margin2M, naturalWidth)
        // Switch pages continue past the basic row: page N shows
        // shortcuts [5 + (N-1)*5, 5 + N*5) so page 1 is never a duplicate
        // of the basic page.
        items: {
          const start = 5 + (root.currentPage - 1) * 5;
          const end = Math.min(start + 5, root.shortcuts.length);
          return root.shortcuts.slice(start, end);
        }
        baseIndex: 5 + (root.currentPage - 1) * 5
      }
    }

    // ---------------- detail pages ----------------
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.quickControlPanelHeight
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
          width: detailScroll.availableWidth
          screen: root.screen
          page: root.currentDetailPage
        }
      }
    }
  }

  // The quick-switch cell row shared by the basic page and overflow switch
  // pages — identical geometry guarantees the same 70 px pitch on every page.
  // items is the page-local slice; baseIndex is the absolute offset into
  // root.shortcuts for widget bookkeeping.
  component SwitchGrid: GridLayout {
    id: switchGrid
    property var items: []
    property int baseIndex: 0
    // Centre short rows: width hugs the actual cell count so a 3-button page
    // is a centred trio, not a sparse left-aligned spread in a 5-cell box.
    readonly property real naturalWidth: items.length * Style.quickSwitchWidth + Math.max(0, items.length - 1) * Style.marginXS

    columns: Math.max(1, Math.min(5, items.length))
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
          pageCount: root.pageCount
          currentPage: root.currentPage
          onNextRequested: root.nextPage()
          onPreviousRequested: root.previousPage()
        }
      }
