import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Cards
import qs.Modules.Panels.ControlCenter
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterModulesPage - module page (DESIGN §3.5.2).
*
* Enabled content cards from controlCenter.cards first — weather, media,
* system monitor, calendar — each as a block with overlay("idle") and
* radiusItem, restyled from the Noctalia card look; then the module grid:
* 3 columns, cells inset 5, radiusItem, overlay("idle") / overlay("hover"),
* 24 px glyph plus label below (to the right when the cell is too short).
*
* Since Phase 5b a click opens the module view inside the frame (DESIGN §3.5.3)
* via `moduleSelected` instead of leaving the control center.
*/
Item {
  id: root

  property var screen: null

  // The module the home grid last pushed into the module view.
  signal moduleSelected(var module)

  readonly property real contentWidth: Math.max(1, root.width - Style.margin2M)
  readonly property var cards: Settings.data.controlCenter.cards ?? []
  readonly property var modules: ControlCenterModules.modules.filter(m => ControlCenterModules.isVisible(m))
  readonly property int gridColumns: 3

  // Height of a grid cell (gxde-control-center navdelegate.cpp:22-107
  // stretches the rows to fill the view; we use a fixed cell height and a
  // label that flips to the right when the cell is too short).
  readonly property real cellHeight: Math.round(80 * Style.uiScaleRatio)

  implicitHeight: content.implicitHeight

  NScrollView {
    id: scroll
    anchors.fill: parent
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded
    reserveScrollbarSpace: false
    gradientColor: Color.maskShell
    // Scrollbar hidden until hover (DESIGN §3.5.2)
    ScrollBar.horizontal.visible: false

    ColumnLayout {
      id: content
      width: scroll.availableWidth
      spacing: Style.marginM

      // ---------------- content cards ----------------
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

      // ---------------- module grid ----------------
      GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        columns: root.gridColumns
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
          model: root.modules

          delegate: Rectangle {
            id: cell
            required property var modelData
            required property int index

            readonly property int column: index % root.gridColumns
            readonly property int row: Math.floor(index / root.gridColumns)
            readonly property int rowCount: Math.ceil(root.modules.length / root.gridColumns)
            readonly property real cellWidth: root.contentWidth / root.gridColumns
            // Only pad the trailing empty cells in the last row so the grid
            // stays flush on its outer edges.
            readonly property bool spacerCell: modelData === undefined || modelData === null
            // Original nav art where the module has it (normal variant: the grid
            // has no selected state); "" → Tabler glyph. Hoisted to the delegate
            // root: properties on layout containers (Row/ColumnLayout) are not
            // reliably visible to their children on first evaluation.
            readonly property string ddeArt: (modelData === undefined || modelData === null) ? "" : ControlCenterModules.navIconUrl(modelData, false)

            Layout.fillWidth: true
            Layout.preferredWidth: cellWidth
            Layout.preferredHeight: root.cellHeight
            Layout.leftMargin: root.column === 0 ? 0 : Style.moduleCellInset
            Layout.rightMargin: root.column === root.gridColumns - 1 ? 0 : Style.moduleCellInset
            Layout.topMargin: root.row === 0 ? 0 : Style.moduleCellInset
            Layout.bottomMargin: root.row === root.rowCount - 1 ? 0 : Style.moduleCellInset
            radius: Style.radiusItem
            color: cellArea.containsMouse ? Color.overlay("hover") : Color.overlay("idle")
            opacity: spacerCell ? 0 : 1

            ColumnLayout {
              anchors.centerIn: parent
              spacing: Style.marginXXS

              // (ddeArt lives on the delegate root.)
              Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.moduleCellIcon
                Layout.preferredHeight: Style.moduleCellIcon
                sourceSize.width: Math.round(Style.moduleCellIcon * Style.uiScaleRatio)
                sourceSize.height: Math.round(Style.moduleCellIcon * Style.uiScaleRatio)
                source: ddeArt
                visible: ddeArt !== ""
                smooth: true
              }

              NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: modelData.icon
                pointSize: Style.moduleCellIcon
                applyUiScale: false
                visible: ddeArt === ""
                color: cellArea.containsMouse ? Color.onShell : Color.onShellSecondary
              }

              NText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: cell.width - Style.marginS
                text: ControlCenterModules.tr(modelData.label)
                pointSize: Style.fontSizeS
                color: Color.onShell
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: cellArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !parent.spacerCell
              onClicked: root.moduleSelected(modelData)
            }
          }
        }
      }
    }
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
        Layout.preferredHeight: Math.round(200 * Style.uiScaleRatio)
      }

      SystemMonitorCard {
        Layout.preferredWidth: Math.round(Style.baseWidgetSize * 2.625)
        Layout.fillHeight: true
      }
    }
  }
}
