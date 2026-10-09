import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

import qs.Commons
import qs.Services.UI
import qs.Widgets
import QtQuick.Layouts

// Fullscreen launcher content (DESIGN §3.4.1). Consumes LauncherModel for all
// non-visual state and only builds UI on top of it.
//
// Layout: search row (30 px) -> 20 px -> body: [category nav] + results area
// (non-app list under the search row, app grid below it). Geometry comes in as
// properties from the window wrapper so the same view could be embedded.
Item {
  id: root

  signal requestClose
  signal requestCloseImmediately

  // ---- geometry in ----
  property var screen: null
  // Taskbar thickness when the taskbar sits on the left / right edge; the
  // launcher's own bands are the other three (gxde-launcher
  // fullscreenframe.cpp:1321-1345).
  property int leftInset: 0
  property int rightInset: 0
  property int topInset: Style.launcherTopBand
  property int bottomGap: Style.launcherGridBottomMargin
  property int sidePadding: 200
  property int navWidth: 180
  property int columns: 6
  property real cellWidth: 170
  property real cellHeight: 170
  property int cellSpacing: 10
  property real iconSize: 85
  property string barPosition: "bottom"

  // Original DDE multi-state artwork (DESIGN §1.9)
  readonly property string ddeIcons: Quickshell.shellDir + "/Assets/DDE/gxde-launcher/src/skin/icons/"

  // ---- state ----
  readonly property bool categoryMode: Settings.data.appLauncher.displayMode === "category"
  readonly property var appsProvider: model.appsProvider
  property bool searchActive: false
  property int focusZone: 0 // 0 = grid, 1 = nav, 2 = search

  // Width aligned to the search field, capped at 600
  readonly property real listWidth: Math.min(600, Math.max(200, resultsArea.width))

  // App results are the apps provider's output; everything else is a list
  // entry. While searching, app hits go to the list too (DESIGN §3.4.1:
  // "搜索结果以列表形式展示"): grid is only for the browse view.
  readonly property bool browsing: model.searchText.trim() === "" && !model.activeProvider
  readonly property var listResults: {
    if (root.browsing)
      return [];
    if (model.activeProvider && model.activeProvider !== appsProvider)
      return model.results;
    if (model.searchText.trim() !== "")
      return model.results;
    return [];
  }

  readonly property var appResults: {
    if (!root.browsing)
      return [];
    if (model.activeProvider && model.activeProvider !== appsProvider)
      return [];
    return model.results.filter(r => r.provider === appsProvider);
  }

  onCategoryModeChanged: if (!categoryMode)
                           focusZone = 0

  // ---------------------------------------------------------------
  // Model (providers, search text, results, selection, activation)
  // ---------------------------------------------------------------
  LauncherModel {
    id: model
    screen: root.screen
    // Real open state — hardcoding true would keep onClosed() (search clear,
    // result reset) from ever firing since the view lives in an always-on Loader.
    isOpen: LauncherState.fullscreenOpen && LauncherState.fullscreenScreen?.name === root.screen?.name
    Component.onCompleted: LauncherState.registerModel("fullscreen", model)
    Component.onDestruction: LauncherState.unregisterModel("fullscreen", model)
    onRequestClose: root.requestClose()
    onRequestCloseImmediately: root.requestCloseImmediately()
  }

  // Escape closes and typing goes to the search field
  Item {
    anchors.fill: parent
    focus: false

    // DDE fullscreen: left-click on empty canvas retracts the launcher. Sits
    // under the content ColumnLayout so controls and cells keep their clicks.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      onClicked: root.requestClose()
    }

    Keys.onPressed: event => {
                      // Escape works from every zone
                      if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                        LauncherState.close(root.screen);
                        event.accepted = true;
                        return;
                      }

                      // While the search field has focus it handles its own keys
                      if (root.focusZone === 2) {
                        if (searchField.textInput.activeFocus) {
                          if (event.key === Qt.Key_Tab) {
                            root.focusZone = 0;
                            event.accepted = true;
                          }
                          return;
                        }
                      }

                      // Typing anywhere goes to the search field
                      if (event.text !== "" && event.text >= " " && !(event.modifiers & Qt.ControlModifier)) {
                        if (root.focusZone !== 2) {
                          root.focusZone = 2;
                        }
                        if (!searchField.textInput.activeFocus) {
                          searchField.textInput.forceActiveFocus();
                        }
                        // Forward the typed character
                        searchField.textInput.text = searchField.textInput.text + event.text;
                        model.setSearchText(searchField.textInput.text);
                        event.accepted = true;
                        return;
                      }

                      if (event.modifiers & Qt.ControlModifier) {
                        // Ctrl+V pastes into the search field (DESIGN §3.4.1)
                        if (event.matches(StandardKey.Paste)) {
                          root.pasteIntoSearch();
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                          root.adjustIconRatio(0.1);
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_Minus) {
                          root.adjustIconRatio(-0.1);
                          event.accepted = true;
                          return;
                        }
                      }

                      root.handleGridKeys(event);
                    }
  }

  function handleGridKeys(event) {
    // Tab cycles grid -> nav -> search (search is always in the cycle;
    // nav is skipped in free mode)
    if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ControlModifier)) {
      root.cycleFocus();
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_PageUp) {
      model.selectPreviousPage(5);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_PageDown) {
      model.selectNextPage(5);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Home) {
      model.selectFirst();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_End) {
      model.selectLast();
      event.accepted = true;
      return;
    }

    if (root.focusZone === 1 && root.categoryMode) {
      switch (event.key) {
      case Qt.Key_Up:
        categoryNav.step(-1);
        event.accepted = true;
        break;
      case Qt.Key_Down:
        categoryNav.step(1);
        event.accepted = true;
        break;
      case Qt.Key_Enter:
      case Qt.Key_Return:
        categoryNav.activateCurrent();
        event.accepted = true;
        break;
      }
      if (event.accepted)
        return;
    }

    switch (event.key) {
    case Qt.Key_Up:
      model.selectPreviousRow(root.columns);
      event.accepted = true;
      break;
    case Qt.Key_Down:
      model.selectNextRow(root.columns);
      event.accepted = true;
      break;
    case Qt.Key_Left:
      model.selectPreviousColumn(root.columns);
      event.accepted = true;
      break;
    case Qt.Key_Right:
      model.selectNextColumn(root.columns);
      event.accepted = true;
      break;
    case Qt.Key_Enter:
    case Qt.Key_Return:
      model.activate();
      event.accepted = true;
      break;
    case Qt.Key_Delete:
      model.deleteSelected();
      event.accepted = true;
      break;
    }
  }

  function cycleFocus() {
    const zones = categoryMode ? [0, 1, 2] : [0, 2];
    const idx = zones.indexOf(focusZone);
    focusZone = zones[(idx + 1) % zones.length];

    if (focusZone === 2) {
      searchField.textInput.forceActiveFocus();
    } else {
      resultsGrid.forceActiveFocus();
    }
  }

  function pasteIntoSearch() {
    Clipboard.getText(function (text) {
      if (!text)
        return;
      searchField.textInput.text = text;
      model.setSearchText(text);
    });
  }

  function adjustIconRatio(delta) {
    let value = Settings.data.appLauncher.iconRatio + delta;
    value = Math.max(0.2, Math.min(0.6, Math.round(value * 10) / 10));
    Settings.data.appLauncher.iconRatio = value;
  }

  // Ctrl + wheel adjusts iconRatio (DESIGN §3.4.1)
  WheelHandler {
    acceptedModifiers: Qt.ControlModifier
    onWheel: event => {
               if (event.angleDelta.y > 0)
               root.adjustIconRatio(0.1);
               else
               root.adjustIconRatio(-0.1);
             }
  }

  // ---------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.topMargin: root.topInset
    anchors.bottomMargin: root.bottomGap
    spacing: Style.launcherAppsAreaTopMargin

    // ---------------- Search row ----------------
    // Layout after gxde-launcher searchwidget.cpp:81-103: 30 px left margin,
    // category toggle, stretch, the 290 px search box centred, stretch, the
    // mini-mode toggle, 30, settings, 30, power, 30 px right margin.
    RowLayout {
      id: searchRow
      Layout.fillWidth: true
      Layout.preferredHeight: Style.launcherSearchButtonSizeAlt
      spacing: 0

      Item {
        Layout.preferredWidth: Style.launcherSearchButtonGap
      }

      // Category / free mode toggle (category_{normal,hover,active}_22px.png)
      LauncherImageButton {
        Layout.preferredWidth: Style.launcherSearchButtonSizeAlt
        Layout.preferredHeight: Style.launcherSearchButtonSizeAlt
        iconSize: Style.launcherSearchButtonSizeAlt
        checked: root.categoryMode
        normalSource: root.ddeIcons + "category_normal_22px.png"
        hoverSource: root.ddeIcons + "category_hover_22px.png"
        pressSource: root.ddeIcons + "category_active_22px.png"
        activeSource: root.ddeIcons + "category_active_22px.png"
        tooltipText: I18n.tr("launcher.dde.toggle-category")
        onClicked: Settings.data.appLauncher.displayMode = root.categoryMode ? "free" : "category"
      }

      Item {
        Layout.fillWidth: true
      }

      LauncherSearchField {
        id: searchField
        Layout.preferredWidth: Style.launcherSearchWidth
        Layout.preferredHeight: 30
        wallpaperSurface: true
        text: model.searchText
        onTextEdited: txt => model.setSearchText(txt)
        onAccepted: model.activate()
        onActiveFocusChanged: {
          if (searchField.textInput.activeFocus)
            root.focusZone = 2;
          else if (root.focusZone === 2)
            root.focusZone = 0;
        }
      }

      Item {
        Layout.fillWidth: true
      }

      // Switch to mini (unfullscreen_{normal,hover,press}.png)
      LauncherImageButton {
        Layout.preferredWidth: Style.launcherSearchButtonSizeAlt
        Layout.preferredHeight: Style.launcherSearchButtonSizeAlt
        iconSize: Style.launcherSearchButtonSizeAlt
        normalSource: root.ddeIcons + "unfullscreen_normal.png"
        hoverSource: root.ddeIcons + "unfullscreen_hover.png"
        pressSource: root.ddeIcons + "unfullscreen_press.png"
        tooltipText: I18n.tr("launcher.dde.switch-to-mini")
        onClicked: LauncherState.setMode("mini")
      }

      Item {
        Layout.preferredWidth: Style.launcherSearchButtonGap
      }

      // Settings (settings_{normal,hover,press}_24px.svg)
      LauncherImageButton {
        Layout.preferredWidth: Style.launcherSearchButtonSizeAlt
        Layout.preferredHeight: Style.launcherSearchButtonSizeAlt
        iconSize: Style.launcherSearchButtonSizeAlt
        normalSource: root.ddeIcons + "settings_normal_24px.svg"
        hoverSource: root.ddeIcons + "settings_hover_24px.svg"
        pressSource: root.ddeIcons + "settings_press_24px.svg"
        tooltipText: I18n.tr("launcher.dde.open-settings")
        onClicked: LauncherState.showSettings(root.screen)
      }

      Item {
        Layout.preferredWidth: Style.launcherSearchButtonGap
      }

      // Power (poweroff_{normal,hover,press}.png)
      LauncherImageButton {
        Layout.preferredWidth: Style.launcherSearchButtonSizeAlt
        Layout.preferredHeight: Style.launcherSearchButtonSizeAlt
        iconSize: Style.launcherSearchButtonSizeAlt
        normalSource: root.ddeIcons + "poweroff_normal.png"
        hoverSource: root.ddeIcons + "poweroff_hover.png"
        pressSource: root.ddeIcons + "poweroff_press.png"
        tooltipText: I18n.tr("launcher.dde.open-session-menu")
        onClicked: LauncherState.showSessionMenu(root.screen)
      }

      Item {
        Layout.preferredWidth: Style.launcherSearchButtonGap
      }
    }

    // ---------------- Body: nav + results ----------------
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Category navigation column (DESIGN §3.4.1). It sits flush against the
      // taskbar edge when the taskbar is on the left (fullscreenframe.cpp:1348).
      LauncherCategoryNav {
        id: categoryNav
        visible: root.categoryMode
        x: root.leftInset
        width: root.navWidth
        height: parent.height
        z: 2

        model: root.model
        appsProvider: root.appsProvider
        gridView: resultsGrid
      }

      Item {
        id: resultsArea
        anchors.left: categoryNav.visible ? categoryNav.right : parent.left
        anchors.leftMargin: categoryNav.visible ? 0 : root.sidePadding + root.leftInset
        anchors.right: parent.right
        anchors.rightMargin: root.sidePadding + root.rightInset
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // Grouped non-app list under the search row (DESIGN §3.4.1):
        // rows like the mini list, width aligned to the search field
        NListView {
          id: resultsList
          visible: root.listResults.length > 0
          width: root.listWidth
          height: Math.min(contentHeight, root.height * 0.5)
          spacing: 0
          clip: true
          model: root.listResults
          currentIndex: model.selectedIndex
          interactive: true
          reserveScrollbarSpace: false

          delegate: LauncherListRow {
            listView: resultsList
            onActivated: {
              model.selectIndex(index);
              model.activate();
            }
          }

          // Clipboard preview in a dark card to the right of the list
          Loader {
            x: resultsList.width + Style.marginL
            width: 260
            anchors.top: resultsList.top
            anchors.bottom: resultsList.bottom
            active: model.activeProvider === model.clipboardProvider
            visible: active

            sourceComponent: ClipboardPreview {
              currentItem: model.selectedIndex >= 0 && model.selectedIndex < model.results.length ? model.results[model.selectedIndex] : null
            }
          }
        }

        // ---- app grid ----
        NGridView {
          id: resultsGrid

          anchors.top: resultsList.visible ? resultsList.bottom : parent.top
          anchors.topMargin: resultsList.visible ? Style.marginM : (pinnedTitle.visible ? pinnedTitle.height : 0)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          // Layout: square cells (gxde-launcher calculate_util.cpp:104-145),
          // vertical scroll with the scrollbar hidden (free mode does not page)
          cellWidth: root.cellWidth
          cellHeight: root.cellHeight
          spacing: root.cellSpacing
          model: root.appResults
          currentIndex: model.selectedIndex
          // Only grab the pointer while the grid actually scrolls — otherwise an
          // interactive Flickable eats every press on empty canvas and the
          // dismiss MouseArea below can never see them. Wheel scroll still goes
          // through NGridView's own WheelHandler either way.
          interactive: contentOverflows
          focus: true
          verticalPolicy: ScrollBar.AlwaysOff
          horizontalPolicy: ScrollBar.AlwaysOff
          reserveScrollbarSpace: false
          showGradientMasks: false
          boundsBehavior: Flickable.StopAtBounds

          // Sits under the inner GridView (z:-1): clicks on empty canvas between
          // or below cells retract the launcher (DDE fullscreen behaviour).
          MouseArea {
            z: -1
            width: Math.max(resultsGrid.contentWidth, resultsGrid.width)
            height: Math.max(resultsGrid.contentHeight, resultsGrid.height)
            acceptedButtons: Qt.LeftButton
            onClicked: root.requestClose()
          }

          // Keyboard selection: animates to the new row (NGridView smooth scroll)
          onCurrentIndexChanged: {
            if (currentIndex >= 0)
              positionViewAtIndex(currentIndex, GridView.Contain);
          }
          delegate: LauncherGridCell {
            width: resultsGrid.effectiveCellWidth
            height: resultsGrid.effectiveCellHeight
            iconSize: Math.round(resultsGrid.effectiveCellWidth * Settings.data.appLauncher.iconRatio)
            // `index` is the position inside appResults (apps only, filtered)
            // — map back to the real result object before activating.
            onActivated: model.activateItem(root.appResults[index])
          }
        }

        // Pinned section title (category mode): text + a 1 px line fading from
        // white@0.3 to 0, pinned to the grid top while scrolling. Upstream
        // paints no background here (categorytitlewidget.cpp: a transparent
        // QLabel + CategoryWhiteLine) — a band under the text reads as a dark
        // frame that collides with the selected cell's pressDim block.
        Rectangle {
          id: pinnedTitle
          visible: root.categoryMode && !resultsList.visible
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Style.launcherCategoryTitleHeight
          color: "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginS

            NText {
              text: appsProvider ? (appsProvider.getDDECategoryName ? appsProvider.getDDECategoryName(appsProvider.ddeCategory) : appsProvider.ddeCategory) : ""
              pointSize: Style.fontSizeBody
              font.weight: Style.fontWeightMedium
              color: Color.onWallpaper
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              opacity: 0.3
              gradient: Gradient {
                GradientStop {
                  position: 0.0
                  color: Qt.alpha(Color.onWallpaper, 0.3)
                }
                GradientStop {
                  position: 1.0
                  color: Qt.alpha(Color.onWallpaper, 0)
                }
              }
            }
          }
        }
      }
    }
  }

  // ---- section tracking (DESIGN §3.4.1) ----
  // The grid already shows one category's apps, so the pinned title follows
  // the active DDE category; the nav column owns selection.
  Component.onCompleted: Qt.callLater(() => {
                                        mainContainer.forceActiveFocus();
                                      })

  Item {
    id: mainContainer
    anchors.fill: parent
    focus: true
  }
}
