import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell

import qs.Commons
import qs.Widgets
import QtQuick.Layouts

// Category navigation column for the fullscreen launcher (DESIGN §3.4.1,
// gxde-launcher NavigationWidget / CategoryButton): 11 DDE categories with the
// original 22 px multi-state artwork, 42 px rows, text at onShell 0.6 / 0.8 on
// hover / 1.0 when current; hovering the column zooms the rows 1.0 -> 1.2 over
// Style.motionNavZoom (navigationwidget.cpp:209-231).
// Clicking a row switches the grid to that category's apps.
Item {
  id: root

  required property var model
  required property var appsProvider
  required property var gridView

  // DDE 15 categories → the 11 buckets used by the DDE launcher nav
  // (deepin-daemon launcher/category.go, mirrored by gxde-launcher
  // categorybutton.cpp:130-170).
  readonly property var categories: ["Internet", "Chat", "Music", "Video", "Graphics", "Game", "Office", "Reading", "Development", "System", "Others"]

  // Original artwork prefix per category (categorybutton.cpp:130-170;
  // the Video category's icon file is named "multimedia").
  readonly property var categoryIcons: ({
                                          "Internet": "internet",
                                          "Chat": "chat",
                                          "Music": "music",
                                          "Video": "multimedia",
                                          "Graphics": "graphics",
                                          "Game": "game",
                                          "Office": "office",
                                          "Reading": "reading",
                                          "Development": "development",
                                          "System": "system",
                                          "Others": "others"
                                        })

  readonly property string ddeIcons: Quickshell.shellDir + "/Assets/DDE/gxde-launcher/src/skin/icons/"

  readonly property string currentCategory: appsProvider ? (appsProvider.ddeCategory || "Others") : "Others"
  readonly property int currentIndex: categories.indexOf(currentCategory)

  readonly property bool hovering: navMouseArea.containsMouse

  // Upstream does not transform the column: on hover it raises each button's
  // height to NAVIGATION_ICON_HEIGHT * 1.2 and the icon to 22 * 1.2, keeping the
  // 20 px left inset fixed (categorybutton.cpp:229-241). Zoom the rows instead.
  property real navZoom: 1.0

  onHoveringChanged: navZoom = hovering ? Style.launcherNavZoom : 1.0

  Behavior on navZoom {
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
    spacing: 0
    model: root.categories
    currentIndex: root.currentIndex
    interactive: false
    verticalPolicy: ScrollBar.AlwaysOff
    reserveScrollbarSpace: false

    delegate: Item {
      required property string modelData
      required property int index

      width: navList.width
      height: Style.launcherCategoryRowHeight * root.navZoom

      readonly property bool isCurrent: navList.currentIndex === index
      readonly property real textAlpha: isCurrent ? 1.0 : (navItemMouseArea.containsMouse ? 0.8 : 0.6)

      // <icon>_<normal|hover|active>_22px.svg (categorybutton.cpp:170-188)
      Image {
        id: categoryIcon
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        width: Style.launcherCategoryIconSize * root.navZoom
        height: Style.launcherCategoryIconSize * root.navZoom
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
        source: {
          const name = root.categoryIcons[modelData] || "others";
          const state = isCurrent ? "active" : (navItemMouseArea.containsMouse ? "hover" : "normal");
          const path = root.ddeIcons + name + "_" + state + "_22px.svg";
          return (Screen.devicePixelRatio || 1) > 1 ? path.replace(/_22px\.svg$/, "_22px@2x.svg") : path;
        }
      }

      NText {
        anchors.left: categoryIcon.right
        anchors.leftMargin: Style.marginM
        anchors.right: parent.right
        anchors.rightMargin: Style.marginS
        anchors.verticalCenter: parent.verticalCenter
        text: appsProvider ? (appsProvider.getDDECategoryName ? appsProvider.getDDECategoryName(modelData) : modelData) : modelData
        pointSize: Style.fontSizeBody
        elide: Text.ElideRight
        maximumLineCount: 1
        color: Qt.alpha(Color.onShell, parent.textAlpha)
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
