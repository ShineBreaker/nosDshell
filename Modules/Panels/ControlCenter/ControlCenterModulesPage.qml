import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.ControlCenter
import qs.Services.UI
import qs.Widgets

/**
* ControlCenterModulesPage - the all-settings module grid (DESIGN §3.5.2/3.5.3).
*
* 〔演进〕 The module grid is the all-settings entry page, not the landing
* view: the home page is notification-first and the content cards moved
* below the notification list. The grid is reached from the header gear,
* the bell toggle and settings entries; a cell click opens the module view
* inside the frame (DESIGN §3.5.3) via `moduleSelected`.
*
* Grid: 3 columns, cells inset 5, radiusItem, overlay("idle") /
* overlay("hover"), 24 px glyph plus label below (to the right when the
* cell is too short).
*/
Item {
  id: root

  property var screen: null

  // The module the home grid last pushed into the module view.
  signal moduleSelected(var module)

  readonly property real contentWidth: Math.max(1, root.width - Style.margin2M)
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
    gradientColor: Colors.maskShell
    // Scrollbar hidden until hover (DESIGN §3.5.2)
    ScrollBar.horizontal.visible: false

    ColumnLayout {
      id: content
      width: scroll.availableWidth
      spacing: Style.marginM

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
            // Theme symbolic first, bundled Papirus nav art as the floor
            // (the unhovered dim comes from cellArt.opacity); "" → Tabler
            // glyph. Hoisted to the delegate root: properties on layout
            // containers (Row/ColumnLayout) are not reliably visible to their
            // children on first evaluation.
            readonly property string ddeArt: (modelData === undefined || modelData === null) ? "" : ControlCenterModules.navIconUrl(modelData)

            Layout.fillWidth: true
            Layout.preferredWidth: cellWidth
            Layout.preferredHeight: root.cellHeight
            Layout.leftMargin: root.column === 0 ? 0 : Style.moduleCellInset
            Layout.rightMargin: root.column === root.gridColumns - 1 ? 0 : Style.moduleCellInset
            Layout.topMargin: root.row === 0 ? 0 : Style.moduleCellInset
            Layout.bottomMargin: root.row === root.rowCount - 1 ? 0 : Style.moduleCellInset
            radius: Style.radiusItem
            color: cellArea.containsMouse ? Colors.overlay("hover") : Colors.overlay("idle")
            opacity: spacerCell ? 0 : 1

            ColumnLayout {
              anchors.centerIn: parent
              spacing: Style.marginXXS

              // (ddeArt lives on the delegate root.)
              NSymbolicImage {
                id: cellArt
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.moduleCellIcon
                Layout.preferredHeight: Style.moduleCellIcon
                sourceSize.width: Math.round(Style.moduleCellIcon * Style.uiScaleRatio)
                sourceSize.height: Math.round(Style.moduleCellIcon * Style.uiScaleRatio)
                source: ddeArt
                visible: ddeArt !== ""
                smooth: true
                // Same ink ladder as the NIcon fallback below.
                color: Colors.onShell
                opacity: cellArea.containsMouse ? 1.0 : Colors.onShellSecondary.a
              }

              NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: modelData.icon
                pointSize: Style.moduleCellIcon
                applyUiScale: false
                visible: ddeArt === ""
                color: cellArea.containsMouse ? Colors.onShell : Colors.onShellSecondary
              }

              NText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: cell.width - Style.marginS
                text: ControlCenterModules.tr(modelData.label)
                pointSize: Style.fontSizeS
                color: Colors.onShell
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
}
