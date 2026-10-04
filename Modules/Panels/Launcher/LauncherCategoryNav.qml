import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Widgets
import QtQuick.Layouts

// Category navigation column for the fullscreen launcher (DESIGN §3.4.1,
// gxde-launcher NavigationWidget): 11 DDE categories, ~42 px rows with a 22 px
// glyph and text at onShell 0.6 / 0.8 hover / 1.0 current; the whole column
// zooms 1.0 -> 1.2 on hover with Style.motionNavZoom.
// Clicking a row switches the grid to that category's section.
Item {
  id: root

  required property var model
  required property var appsProvider
  required property var gridView

  // DDE 15 categories → the 11 buckets used by the DDE launcher nav
  // (deepin-daemon launcher/category.go, mirrored by gxde-launcher).
  readonly property var categories: [
    "Internet", "Chat", "Music", "Video", "Graphics", "Game",
    "Office", "Reading", "Development", "System", "Others"
  ]

  readonly property var categoryIcons: ({
                                     "Internet": "world",
                                     "Chat": "message-circle",
                                     "Music": "music",
                                     "Video": "device-tv",
                                     "Graphics": "brush",
                                     "Game": "device-gamepad",
                                     "Office": "file-text",
                                     "Reading": "book",
                                     "Development": "code",
                                     "System": "device-desktop",
                                     "Others": "dots"
                                   })

  readonly property string currentCategory: appsProvider ? (appsProvider.ddeCategory || "Others") : "Others"
  readonly property int currentIndex: categories.indexOf(currentCategory)

  readonly property bool hovering: navMouseArea.containsMouse

  // Whole-column zoom 1.0 -> 1.2 on hover (DESIGN §1.7 motionNavZoom)
  scale: hovering ? 1.2 : 1.0

  Behavior on scale {
    NumberAnimation {
      duration: Style.motionNavZoom
      easing.type: Easing.OutCubic
    }
  }

  function step(delta) {
    if (!appsProvider)
    return;
    const next = Math.max(0, Math.min(categories.length - 1, currentIndex + delta));
    select(categories[next]);
  }

  function select(category) {
    if (!appsProvider)
    return;
    appsProvider.selectDDECategory(category);
    if (gridView)
    gridView.positionViewAtBeginning();
  }

  function activateCurrent() {
    select(currentCategory);
  }

  NListView {
    id: navList
    anchors.fill: parent
    spacing: Style.marginS
    model: root.categories
    currentIndex: root.currentIndex
    interactive: false
    verticalPolicy: ScrollBar.AlwaysOff
    reserveScrollbarSpace: false

    delegate: Item {
      required property string modelData
      required property int index

      width: navList.width
      height: 42

      readonly property bool isCurrent: navList.currentIndex === index

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusRow
        color: navItemMouseArea.containsMouse ? Color.overlay("hover") : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: Style.animationFast
          }
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginS
        spacing: Style.marginS

        NIcon {
          icon: root.categoryIcons[modelData] || "dots"
          pointSize: Style.fontSizeBody
          Layout.alignment: Qt.AlignVCenter
          color: isCurrent ? Color.onShell : (navItemMouseArea.containsMouse ? Qt.alpha(Color.onShell, 0.8) : Qt.alpha(Color.onShell, 0.6))
        }

        NText {
          text: appsProvider ? (appsProvider.getDDECategoryName ? appsProvider.getDDECategoryName(modelData) : modelData) : modelData
          pointSize: Style.fontSizeBody
          Layout.fillWidth: true
          elide: Text.ElideRight
          maximumLineCount: 1
          color: isCurrent ? Color.onShell : (navItemMouseArea.containsMouse ? Qt.alpha(Color.onShell, 0.8) : Qt.alpha(Color.onShell, 0.6))
        }
      }

      MouseArea {
        id: navItemMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.select(modelData)
      }
    }
  }

  // Hover detection over the whole column drives the zoom
  MouseArea {
    id: navMouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }
}
