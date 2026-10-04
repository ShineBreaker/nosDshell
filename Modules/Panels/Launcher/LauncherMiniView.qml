import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.UI
import qs.Widgets
import QtQuick.Layouts

// Mini launcher content (DESIGN §3.4.2). Left pane: search field, separator,
// app list, "全部应用 ⇄ 分类" switch. Right bar: avatar, XDG place buttons,
// date/time, settings, power, and a fullscreen toggle at the top-right.
Item {
  id: root

  signal requestClose
  signal requestCloseImmediately

  property var screen: null
  property bool efficient: false
  property string barPosition: "bottom"

  readonly property real leftPaneWidth: 320
  readonly property real rightPaneWidth: 160

  // App list vs category list (DESIGN §3.4.2 two-level list)
  property bool showCategoryList: false
  property string activeCategory: ""
  readonly property bool inCategory: showCategoryList && activeCategory !== ""

  readonly property var appsProvider: model.appsProvider

  // Apps to show: the full list, or the active category's apps
  readonly property var listApps: {
    const all = appsProvider ? (appsProvider.allApps || []) : [];
    if (!inCategory)
    return all;
    return all.filter(app => appsProvider.appMatchesDDECategory(app, activeCategory));
  }

  readonly property bool hasApps: listApps.length > 0

  LauncherModel {
    id: model
    screen: root.screen
    isOpen: true
    Component.onCompleted: LauncherState.registerModel("mini", model)
    Component.onDestruction: LauncherState.unregisterModel("mini", model)
    onRequestClose: root.requestClose()
    onRequestCloseImmediately: root.requestCloseImmediately()
  }

  // Esc closes (the focus holder below owns the key)
  Item {
    anchors.fill: parent
    focus: true

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
        LauncherState.close(root.screen);
        event.accepted = true;
        return;
      }

      // Typing anywhere goes to search
      if (event.text !== "" && event.text >= " " && !(event.modifiers & Qt.ControlModifier)) {
        if (!searchField.textInput.activeFocus)
        searchField.textInput.forceActiveFocus();
        searchField.textInput.text = searchField.textInput.text + event.text;
        model.setSearchText(searchField.textInput.text);
        event.accepted = true;
        return;
      }

      switch (event.key) {
      case Qt.Key_Up:
        model.selectPreviousRow(1);
        event.accepted = true;
        break;
      case Qt.Key_Down:
        model.selectNextRow(1);
        event.accepted = true;
        break;
      case Qt.Key_Enter:
      case Qt.Key_Return:
        model.activate();
        event.accepted = true;
        break;
      }
    }
  }

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ---------------- Left pane ----------------
    Item {
      Layout.preferredWidth: root.leftPaneWidth
      Layout.fillHeight: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 0

        // Search field
        LauncherSearchField {
          id: searchField
          Layout.fillWidth: true
          Layout.preferredWidth: 290
          Layout.preferredHeight: 30
          text: model.searchText
          onTextEdited: txt => model.setSearchText(txt)
          onAccepted: model.activate()
        }

        Item {
          Layout.preferredHeight: 10
        }

        // 1 px separator
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Color.overlay("hover")
        }

        Item {
          Layout.preferredHeight: 4
        }

        // App list (or category list, or search results)
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          NListView {
            id: appList
            anchors.fill: parent
            clip: true
            model: model.searchText.trim() !== "" ? model.results : root.listApps
            currentIndex: model.selectedIndex
            spacing: 0
            interactive: true
            reserveScrollbarSpace: false

            delegate: Item {
              required property var modelData
              required property int index

              width: appList.width
              height: 36

              Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Style.radiusRow
                color: (rowMouse.containsMouse || appList.currentIndex === index) ? Color.overlay("hover") : "transparent"

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              IconImage {
                x: 10
                y: 6
                width: 24
                height: 24
                source: modelData.icon ? ThemeIcons.iconFromName(modelData.icon) : ""
                visible: status === Image.Ready
                asynchronous: true
              }

              NIcon {
                x: 10
                y: 6
                width: 24
                height: 24
                pointSize: Style.fontSizeM
                icon: modelData.icon || "apps"
                color: Color.onShell
                visible: modelData.icon === ""
              }

              NText {
                x: 48
                width: parent.width - 58
                height: 36
                verticalAlignment: Text.AlignVCenter
                text: modelData.name || ""
                pointSize: Style.fontSizeBody
                color: Color.onShell
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onClicked: {
                  appList.currentIndex = index;
                  model.selectIndex(index);
                  model.activate();
                }
              }
            }

            onCountChanged: {
              if (currentIndex >= count)
              model.selectIndex(0);
            }
          }

          // Back row when inside a category
          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            radius: Style.radiusRow
            color: backRowMouse.containsMouse ? Color.overlay("hover") : "transparent"
            visible: root.inCategory

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              spacing: Style.marginS

              NIcon {
                icon: "chevron-left"
                pointSize: Style.fontSizeBody
                color: Color.onShell
              }

              NText {
                text: I18n.tr("launcher.dde.back")
                pointSize: Style.fontSizeBody
                color: Color.onShell
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: backRowMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              onClicked: root.activeCategory = ""
            }
          }
        }

        Item {
          Layout.preferredHeight: 15
        }

        // "全部应用 ⇄ 分类" switch button (pressed text accent)
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          radius: Style.radiusRow
          color: switchRowMouse.containsMouse || switchRowMouse.pressed ? Color.overlay("hover") : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            spacing: Style.marginS

            NIcon {
              icon: root.showCategoryList ? "apps" : "category"
              pointSize: Style.fontSizeBody
              color: switchRowMouse.pressed ? Color.accent : Color.onShell
            }

            NText {
              Layout.fillWidth: true
              text: root.showCategoryList ? I18n.tr("launcher.dde.all-apps") : I18n.tr("launcher.dde.categories-label")
              pointSize: Style.fontSizeBody
              color: switchRowMouse.pressed ? Color.accent : Color.onShell
              elide: Text.ElideRight
            }

            NIcon {
              icon: "arrows-repeat"
              pointSize: Style.fontSizeBody
              color: switchRowMouse.pressed ? Color.accent : Color.onShellTertiary
            }
          }

          MouseArea {
            id: switchRowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
              root.showCategoryList = !root.showCategoryList;
              root.activeCategory = "";
            }
          }
        }
      }
    }

    // ---------------- Right bar ----------------
    Item {
      Layout.preferredWidth: root.rightPaneWidth
      Layout.fillHeight: true

      // 1 px vertical line on the left edge
      Rectangle {
        x: 0
        width: 1
        height: parent.height
        color: Color.overlay("hover")
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        anchors.rightMargin: 12
        anchors.leftMargin: 0
        spacing: 0

        // top spacing 30 before the first row
        Item {
          Layout.preferredHeight: 30 - 18
        }

        // 24x24 fullscreen toggle at the top-right (width - 29, 12)
        NIconButton {
          Layout.alignment: Qt.AlignRight
          Layout.preferredWidth: 24
          Layout.preferredHeight: 24
          icon: "enlarge"
          tooltipText: I18n.tr("launcher.dde.switch-to-fullscreen")
          colorBg: "transparent"
          colorBgHover: Color.overlay("hover")
          onClicked: LauncherState.setMode("fullscreen")
        }

        Item {
          Layout.preferredHeight: 12
        }

        // Circular avatar
        NImageRounded {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 64
          Layout.preferredHeight: 64
          radius: width / 2
          imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
          fallbackIcon: "person"
        }

        Item {
          Layout.preferredHeight: 12
        }

        // Place buttons (XDG user dirs)
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Repeater {
            model: [
              {
                "name": I18n.tr("launcher.dde.places.computer"),
                "icon": "device-desktop",
                "path": Quickshell.env("HOME")
              }, {
                "name": I18n.tr("launcher.dde.places.videos"),
                "icon": "device-tv",
                "path": Quickshell.env("HOME") + "/Videos"
              }, {
                "name": I18n.tr("launcher.dde.places.music"),
                "icon": "music",
                "path": Quickshell.env("HOME") + "/Music"
              }, {
                "name": I18n.tr("launcher.dde.places.pictures"),
                "icon": "photo",
                "path": Quickshell.env("HOME") + "/Pictures"
              }, {
                "name": I18n.tr("launcher.dde.places.documents"),
                "icon": "file-text",
                "path": Quickshell.env("HOME") + "/Documents"
              }, {
                "name": I18n.tr("launcher.dde.places.downloads"),
                "icon": "download",
                "path": Quickshell.env("HOME") + "/Downloads"
              }
            ]

            delegate: Rectangle {
              required property var modelData

              Layout.fillWidth: true
              Layout.preferredHeight: 28
              radius: Style.radiusRow
              color: placeRowMouse.containsMouse || placeRowMouse.pressed ? Color.overlay("hover") : "transparent"

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                spacing: Style.marginS

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeBody
                  color: Color.onShell
                }

                NText {
                  text: modelData.name
                  pointSize: Style.fontSizeBody
                  color: placeRowMouse.pressed ? Color.accent : Color.onShell
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              MouseArea {
                id: placeRowMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onClicked: Qt.openUrlExternally("file://" + modelData.path)
              }
            }
          }
        }

        Item {
          Layout.fillHeight: true
        }

        // Date/time (two lines)
        NText {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: I18n.locale.toString(Time.now, Locale.ShortFormat)
          pointSize: Style.fontSizeBody
          color: Color.onShell
          applyUiScale: false
        }

        NText {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: I18n.locale.toString(Time.now, "HH:mm")
          pointSize: Style.fontSizeTitle
          font.weight: Style.fontWeightBold
          color: Color.onShell
          applyUiScale: false
        }

        Item {
          Layout.preferredHeight: Style.marginM
        }

        // Settings + power
        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.marginS

          NIconButton {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            icon: "settings"
            tooltipText: I18n.tr("launcher.dde.open-settings")
            colorBg: "transparent"
            colorBgHover: Color.overlay("hover")
            onClicked: LauncherState.showSettings(root.screen)
          }

          NIconButton {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            icon: "power"
            tooltipText: I18n.tr("launcher.dde.open-session-menu")
            colorBg: "transparent"
            colorBgHover: Color.overlay("hover")
            onClicked: LauncherState.showSessionMenu(root.screen)
          }
        }
      }
    }
  }
}
