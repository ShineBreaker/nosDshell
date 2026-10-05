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

  readonly property real leftPaneWidth: Style.launcherMiniLeftPaneWidth
  readonly property real rightPaneWidth: Style.launcherMiniRightPaneWidth
  // Width the right bar settles on: miniframerightbar.cpp updateSize() widens
  // the bar until the settings + power row and the date both fit, with 160 px
  // as the floor (DESIGN §3.4.2 "about 160").
  readonly property real measuredRightPaneWidth: Math.ceil(Math.max(rightPaneWidth, settingsButton.implicitWidth + powerButton.implicitWidth + 38, dateLabel.implicitWidth + 60))

  implicitWidth: leftPaneWidth + measuredRightPaneWidth
  implicitHeight: Style.launcherMiniHeight

  // Original DDE multi-state artwork (DESIGN §1.9)
  readonly property string ddeIcons: Quickshell.shellDir + "/Assets/DDE/gxde-launcher/src/skin/icons/"
  readonly property string ddeImages: Quickshell.shellDir + "/Assets/DDE/gxde-launcher/src/widgets/images/"

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

      // Spacing after gxde-launcher windowedframe.cpp:143-156: 10 px around the
      // search row, then the 1 px separator, 4 px, the app list, the switch
      // button and 15 px at the bottom.
      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.launcherMiniBottomGap
        spacing: 0

        // Search field
        LauncherSearchField {
          id: searchField
          Layout.fillWidth: true
          Layout.preferredWidth: Style.launcherSearchWidth
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
              height: Style.launcherMiniRowHeight

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
                // Shown only when the entry has no icon name at all; keep the
                // app icon name out of the font path (it would warn).
                icon: "apps"
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

        // "全部应用 ⇄ 分类" switch button. 36 px tall, 24 px all.svg at 10 px
        // from the left, 12 px gap, the label, then the 20 px enter arrow shown
        // in the "all categories" state (miniframeswitchbtn.cpp:32-52).
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.launcherMiniRowHeight
          radius: Style.radiusRow
          color: switchRowMouse.containsMouse || switchRowMouse.pressed ? Color.overlay("hover") : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginS

            Image {
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24
              source: root.ddeImages + "all.svg"
              fillMode: Image.PreserveAspectFit
              smooth: true
              asynchronous: true
              opacity: switchRowMouse.pressed ? 0.6 : 1.0
            }

            NText {
              Layout.fillWidth: true
              text: root.showCategoryList ? I18n.tr("launcher.dde.all-apps") : I18n.tr("launcher.dde.categories-label")
              pointSize: Style.fontSizeBody
              font.weight: Style.fontWeightMedium
              color: switchRowMouse.pressed ? Color.accent : Color.onShell
              elide: Text.ElideRight
            }

            Image {
              Layout.preferredWidth: 20
              Layout.preferredHeight: 20
              source: root.ddeImages + "enter_details_normal.svg"
              fillMode: Image.PreserveAspectFit
              smooth: true
              asynchronous: true
              visible: root.showCategoryList
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
    // After gxde-launcher miniframerightbar.cpp: 30 px top band, the 60 px
    // avatar top-left, the XDG place buttons centred, then the 40 px clock with
    // the long date under it and the settings / power row at the bottom.
    // Contents margins are (18, 0, 12, 18) (miniframerightbar.cpp:144).
    Item {
      Layout.preferredWidth: root.measuredRightPaneWidth
      Layout.fillHeight: true

      // 1 px vertical line on the left edge, white x 0.1
      // (miniframerightbar.cpp:204-212)
      Rectangle {
        x: 0
        width: 1
        height: parent.height
        color: Qt.alpha(Color.onShell, 0.1)
      }

      // 24x24 fullscreen toggle, 5 px from the right edge and 12 px from the
      // top (miniframerightbar.cpp:368), fullscreen_{normal,hover,press}.png
      LauncherImageButton {
        x: parent.width - width - 5
        y: 12
        width: Style.launcherMiniModeToggleSize
        height: Style.launcherMiniModeToggleSize
        iconSize: Style.launcherMiniModeToggleSize
        normalSource: root.ddeIcons + "fullscreen_normal.png"
        hoverSource: root.ddeIcons + "fullscreen_hover.png"
        pressSource: root.ddeIcons + "fullscreen_press.png"
        tooltipText: I18n.tr("launcher.dde.switch-to-fullscreen")
        onClicked: LauncherState.setMode("fullscreen")
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.launcherMiniPaddingLeft
        anchors.rightMargin: Style.launcherMiniPaddingRight
        anchors.bottomMargin: Style.launcherMiniPaddingBottom
        spacing: 0

        Item {
          Layout.preferredHeight: Style.launcherMiniTopBand
        }

        // ---- avatar (avatar.cpp:42, 60x60 circular, top-left) ----
        NImageRounded {
          Layout.alignment: Qt.AlignLeft
          Layout.preferredWidth: Style.launcherMiniAvatarSize
          Layout.preferredHeight: Style.launcherMiniAvatarSize
          radius: width / 2
          imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
          fallbackImagePath: Settings.ddeDefaultAvatar
        }

        Item {
          Layout.fillHeight: true
        }

        // ---- XDG place buttons. Text only: upstream builds them with
        // MiniFrameButton(tr("Computer")) and calls setIcon() only for the
        // settings and power buttons (miniframerightbar.cpp:59-67,95-98).
        // "Computer" opens computer:/// upstream; nosDshell has no such
        // protocol, so it falls back to the filesystem root.
        ColumnLayout {
          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          spacing: 0

          Repeater {
            model: [
              {
                "name": I18n.tr("launcher.dde.places.computer"),
                "path": "/"
              },
              {
                "name": I18n.tr("launcher.dde.places.videos"),
                "path": Quickshell.env("HOME") + "/Videos"
              },
              {
                "name": I18n.tr("launcher.dde.places.music"),
                "path": Quickshell.env("HOME") + "/Music"
              },
              {
                "name": I18n.tr("launcher.dde.places.pictures"),
                "path": Quickshell.env("HOME") + "/Pictures"
              },
              {
                "name": I18n.tr("launcher.dde.places.documents"),
                "path": Quickshell.env("HOME") + "/Documents"
              },
              {
                "name": I18n.tr("launcher.dde.places.downloads"),
                "path": Quickshell.env("HOME") + "/Downloads"
              }
            ]

            delegate: LauncherRightBarButton {
              required property var modelData

              Layout.fillWidth: true
              Layout.preferredHeight: Style.launcherMiniButtonRowHeight
              text: modelData.name
              onClicked: Qt.openUrlExternally("file://" + modelData.path)
            }
          }
        }

        Item {
          Layout.fillHeight: true
        }

        // ---- date and time (datetimewidget.cpp:35) ----
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: I18n.locale.toString(Time.now, "HH:mm")
            pointSize: Style.launcherMiniClockSize / (96 / 72)
            font.weight: Style.fontWeightRegular
            color: Color.onShell
            applyUiScale: false
          }

          NText {
            id: dateLabel
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Time.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            pointSize: Style.fontSizeBody
            color: Qt.alpha(Color.onShell, Style.launcherMiniClockDateAlpha)
            applyUiScale: false
          }
        }

        // ---- settings + power (miniframerightbar.cpp:95-101). The icons are
        // 24 px — updateSize() measures the row with iconWidth = 24.
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.marginS
          spacing: Style.marginS

          LauncherRightBarButton {
            id: settingsButton
            Layout.fillWidth: true
            Layout.preferredHeight: Style.launcherMiniButtonRowHeight
            text: I18n.tr("launcher.dde.open-settings")
            iconSource: root.ddeImages + "settings.svg"
            iconSize: Style.launcherMiniModeToggleSize
            onClicked: LauncherState.showSettings(root.screen)
          }

          LauncherRightBarButton {
            id: powerButton
            Layout.fillWidth: true
            Layout.preferredHeight: Style.launcherMiniButtonRowHeight
            text: I18n.tr("launcher.dde.open-session-menu")
            iconSource: root.ddeImages + "power.svg"
            iconSize: Style.launcherMiniModeToggleSize
            onClicked: LauncherState.showSessionMenu(root.screen)
          }
        }
      }
    }
  }
}
