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

  // App list vs category list (DESIGN §3.4.2 two-level list; upstream drives
  // it off WindowedFrame::m_displayMode, windowedframe.cpp onSwitchBtnClicked).
  // The picked bucket lives on the provider (ddeCategory) so the rows on
  // screen ARE model.results — keyboard selection and Enter stay aligned.
  property bool showCategoryList: false
  // Highlighted row while the 12 category rows are on screen (model.selection
  // tracks _results, which are not what the list is showing in that state).
  property int catIndex: 0
  readonly property bool inCategory: showCategoryList && ddeCategory !== "all"
  // showingCategoryRows = the bucket list itself; inCategory = inside a bucket
  readonly property bool showingCategoryRows: showCategoryList && !inCategory

  readonly property var appsProvider: model.appsProvider
  readonly property string ddeCategory: appsProvider ? appsProvider.ddeCategory : "all"

  // Category-list rows: "All Apps" first, then the 11 DDE buckets
  // (minicategorywidget.cpp:46-56).
  readonly property var categoryRows: ["all"].concat(appsProvider ? (appsProvider.ddeCategories || []) : [])

  readonly property bool hasApps: model.results.length > 0

  // Category-row activation: "all" leaves the category views entirely, a
  // bucket enters it (switchToCategory -> setCategory).
  function pickCategory(cat) {
    if (cat === "all") {
      showCategoryList = false;
      appsProvider.selectDDECategory("all");
    } else {
      appsProvider.selectDDECategory(cat);
    }
  }

  // Upstream resets the windowed frame to the all-apps list every time it
  // hides (windowedframe.cpp hideEvent). Drop the category state and the
  // bucket filter so a reopened launcher never comes up silently filtered.
  Connections {
    target: LauncherState
    function onClosed() {
      root.showCategoryList = false;
      root.catIndex = 0;
      if (root.appsProvider)
        root.appsProvider.selectDDECategory("all");
    }
  }

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
                        if (root.showingCategoryRows)
                        root.catIndex = Math.max(0, root.catIndex - 1);
                        else
                        model.selectPreviousRow(1);
                        event.accepted = true;
                        break;
                        case Qt.Key_Down:
                        if (root.showingCategoryRows)
                        root.catIndex = Math.min(root.categoryRows.length - 1, root.catIndex + 1);
                        else
                        model.selectNextRow(1);
                        event.accepted = true;
                        break;
                        case Qt.Key_Enter:
                        case Qt.Key_Return:
                        // On the bucket rows Enter enters/buckets the row
                        // (upstream switchToCategory); elsewhere the result.
                        if (root.showingCategoryRows) {
                          if (root.catIndex >= 0 && root.catIndex < root.categoryRows.length)
                          root.pickCategory(root.categoryRows[root.catIndex]);
                        } else {
                          model.activate();
                        }
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
            // The category list reuses this view: rows are the 12 DDE buckets
            // as bare strings while the apps keep their result-entry shape.
            // The bucket filter rides on the provider, so in-category browsing
            // shows exactly model.results.
            model: {
              if (model.searchText.trim() !== "")
                return model.results;
              if (root.showingCategoryRows)
                return root.categoryRows;
              return model.results;
            }
            currentIndex: root.showingCategoryRows ? root.catIndex : model.selectedIndex
            spacing: 0
            interactive: true
            reserveScrollbarSpace: false

            delegate: Item {
              required property var modelData
              required property int index

              readonly property bool isCategoryRow: typeof modelData === "string"
              // In the category list the checked row mirrors the view state:
              // "All Apps" while not inside a category, the bucket otherwise.
              readonly property bool isActiveRow: isCategoryRow && (modelData === root.ddeCategory || (modelData === "all" && !root.inCategory))

              width: appList.width
              height: Style.launcherMiniRowHeight

              Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Style.radiusRow
                color: {
                  if (isCategoryRow) {
                    // Category rows (§3.4.2): dark tile only when active,
                    // hover otherwise.
                    if (isActiveRow)
                      return Qt.rgba(0.082, 0.082, 0.082, 0.2);
                    return (rowMouse.containsMouse || appList.currentIndex === index) ? Color.overlay("hover") : "transparent";
                  }
                  return (rowMouse.containsMouse || appList.currentIndex === index) ? Color.overlay("hover") : "transparent";
                }
              }

              IconImage {
                x: 10
                y: 6
                width: 24
                height: 24
                source: (!isCategoryRow && modelData.icon) ? ThemeIcons.iconFromName(modelData.icon) : ""
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
                visible: !isCategoryRow && modelData.icon === ""
              }

              // App row label
              NText {
                x: 48
                width: parent.width - 58
                height: 36
                verticalAlignment: Text.AlignVCenter
                text: isCategoryRow ? "" : (modelData.name || "")
                pointSize: Style.fontSizeBody
                color: Color.onShell
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: !isCategoryRow
              }

              // Category row label (§3.4.2: white×0.6 text, accent when
              // selected; upstream MiniCategoryItem is a centered text button)
              NText {
                anchors.fill: parent
                visible: isCategoryRow
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: isCategoryRow ? (appsProvider ? appsProvider.getDDECategoryName(modelData) : modelData) : ""
                pointSize: Style.fontSizeBody
                color: isActiveRow ? Color.accent : Qt.alpha(Color.onShell, 0.6)
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onClicked: {
                  if (isCategoryRow) {
                    root.pickCategory(modelData);
                    return;
                  }
                  model.selectIndex(index);
                  model.activate();
                }
              }
            }

            onCountChanged: {
              if (root.showingCategoryRows)
                root.catIndex = Math.min(root.catIndex, count - 1);
              else if (currentIndex >= count)
                model.selectIndex(0);
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
              // Upstream: "All Categories" with the enter arrow while browsing
              // all apps, "Back" in the category views
              // (miniframeswitchbtn.cpp updateStatus).
              text: root.showCategoryList ? I18n.tr("launcher.dde.back") : I18n.tr("launcher.dde.categories-label")
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
              visible: !root.showCategoryList
            }
          }

          MouseArea {
            id: switchRowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
              // windowedframe.cpp onSwitchBtnClicked: from inside a category
              // the button returns to the category list, not straight to all
              // apps.
              if (root.inCategory) {
                root.appsProvider.selectDDECategory("all");
              } else {
                root.showCategoryList = !root.showCategoryList;
                root.catIndex = 0;
              }
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
