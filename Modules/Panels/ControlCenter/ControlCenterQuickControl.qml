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
  readonly property int switchPageCount: Math.max(1, Math.ceil(shortcuts.length / 5))

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

  readonly property string currentDetailPage: {
    const idx = currentPage - 1 - switchPageCount;
    return (idx >= 0 && idx < detailPages.length) ? detailPages[idx] : "";
  }

  function nextPage() {
    currentPage = (currentPage + 1) % pageCount;
  }

  function previousPage() {
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

  // Select a page by id ("basic" or wifi/bluetooth/display/vpn); pages that
  // are unavailable in this environment fall back to the basic page.
  function openPage(name) {
    const idx = detailPages.indexOf(name);
    currentPage = idx >= 0 ? 1 + switchPageCount + idx : 0;
  }

  Component.onCompleted: {
    if (NetworkService.wifiEnabled && !NetworkService.scanningActive)
      NetworkService.scan();
    VPNService.refresh();
  }

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.pageIndicatorHeight
    spacing: Style.marginS

    // ---------------- basic page ----------------
    ColumnLayout {
      id: basicCol
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.topMargin: Style.marginM
      Layout.bottomMargin: Style.marginM
      // Fixed height: sliders (35+35) + quick switch row (60) + spacing
      Layout.preferredHeight: Style.quickControlPanelHeight
      visible: root.currentPage === 0
      spacing: Style.marginS

        // Volume slider
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.sliderBasicHeight
          spacing: Style.marginS

          NIcon {
            icon: "volume-off"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }

          NSlider {
            Layout.fillWidth: true
            from: 0
            to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
            value: AudioService.volume
            stepSize: 0.01
            heightRatio: 0.5
            onMoved: AudioService.setVolume(value)
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
          Layout.fillWidth: true
          Layout.preferredHeight: Style.sliderBasicHeight
          Layout.topMargin: Style.marginS
          spacing: Style.marginS
          visible: brightnessMonitor !== null && brightnessMonitor.brightnessControlAvailable

          readonly property var brightnessMonitor: BrightnessService.getMonitorForScreen(root.screen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)) ?? null

          Connections {
            target: parent && parent.brightnessMonitor ? parent.brightnessMonitor : null
            ignoreUnknownSignals: true
            function onBrightnessUpdated() {
              const bm = parent.brightnessMonitor;
              if (bm && !brightnessSlider.pressed)
                parent.localBrightness = bm.brightness || 0;
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
            value: parent.localBrightness
            stepSize: 0.01
            heightRatio: 0.5
            onMoved: {
              parent.localBrightness = value;
              brightnessMonitor?.setBrightness(value);
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
        GridLayout {
          Layout.preferredHeight: Style.quickSwitchHeight
          Layout.topMargin: Style.marginS
          Layout.alignment: Qt.AlignHCenter
          columns: 5
          columnSpacing: Style.marginXS
          rowSpacing: Style.marginS
          width: Math.min(root.width - Style.margin2M, Style.quickSwitchWidth * 5 + Style.marginXS * 4)

          Repeater {
            model: root.currentPage === 0 ? root.shortcuts.slice(0, Math.min(5, root.shortcuts.length)) : []

            delegate: QuickSwitchButton {
              required property var modelData
              required property int index
              readonly property var widgetData: modelData
              widgetId: widgetData !== undefined ? widgetData.id : ""
              widgetScreen: root.screen
              widgetProps: widgetData !== undefined ? {
                                                  "widgetId": widgetData.id,
                                                  "section": "quickSettings",
                                                  "sectionWidgetIndex": index,
                                                  "sectionWidgetsCount": root.shortcuts.length,
                                                  "widgetSettings": widgetData
                                                } : null
            }
          }
        }
    }

    // ---------------- switch pages (overflow) ----------------
    Item {
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.preferredHeight: Style.quickSwitchHeight + Style.marginS
      visible: root.currentPage >= 1 && root.currentPage <= root.switchPageCount

      GridLayout {
        anchors.fill: parent
        columns: 5
        columnSpacing: Style.marginXS
        rowSpacing: Style.marginS

        Repeater {
          // Page N (1-based) shows shortcuts [(N-1)*5, N*5)
          model: {
            const start = (root.currentPage - 1) * 5;
            const end = Math.min(start + 5, root.shortcuts.length);
            return root.shortcuts.slice(start, end);
          }

          delegate: QuickSwitchButton {
            required property var modelData
            required property int index
            // The model is sliced to this page, so index is page-local;
            // absoluteIndex is the position in the full shortcut list.
            readonly property int absoluteIndex: (root.currentPage - 1) * 5 + index
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
    }

    // ---------------- detail pages ----------------
    Item {
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.preferredHeight: Style.quickSwitchHeight * 3 + Style.margin2S
      visible: root.currentDetailPage !== ""

      ControlCenterDetailPages {
        anchors.fill: parent
        screen: root.screen
        page: root.currentDetailPage
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