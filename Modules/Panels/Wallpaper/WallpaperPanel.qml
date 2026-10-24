import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI
import qs.Widgets

// Wallpaper selector (DESIGN.md §3.10): a full-width filmstrip flush to the
// bottom screen edge. The previous centred grid panel is replaced wholesale;
// local scanning, directory browsing, the Wallhaven source and applying a
// wallpaper are all kept.
SmartPanel {
  id: root

  dimsBackground: false

  property var contentItem: null

  // §3.10: the strip spans the whole screen and sits on the bottom edge, which
  // SmartPanel's bottom edge-sheet branch handles.
  edgeSheet: true
  edgeSheetEdge: "bottom"

  panelBackgroundColor: Colors.maskDark

  // panelContent is created lazily by SmartPanel's content loader, so these
  // key handlers must not assume the strip exists yet — the same guard the
  // grid panel used before this rewrite.
  function onLeftPressed() {
    if (!root.contentItem)
      return;
    root.contentItem.stripView.moveCurrentIndexLeft();
  }
  function onRightPressed() {
    if (!root.contentItem)
      return;
    root.contentItem.stripView.moveCurrentIndexRight();
  }
  function onDownPressed() {
    if (!root.contentItem)
      return;
    root.contentItem.stripView.moveCurrentIndexRight();
  }
  function onUpPressed() {
    if (!root.contentItem)
      return;
    root.contentItem.stripView.moveCurrentIndexLeft();
  }
  function onReturnPressed() {
    if (!root.contentItem)
      return;
    root.contentItem.stripView.applyCurrentIndex();
  }
  function onEnterPressed() {
    onReturnPressed();
  }

  panelContent: Item {
    id: strip

    // SmartPanel reads this optional property off the content item to decide
    // whether the panel may sit flush against the bar.
    property bool allowAttachToBar: true

    // Exposed so the panel's key handlers can reach the strip without
    // depending on an id that only exists once the loader has run.
    property alias stripView: stripView

    // panelContent is instantiated lazily, so publish the content item from
    // here rather than from the panel's own Component.onCompleted.
    Component.onCompleted: {
      root.contentItem = strip;
    }
    readonly property real contentPreferredWidth: root.width
    // The sheet is pinned to the screen bottom edge; clear whatever shell
    // strip occupies that edge — the fashion dock or a bottom status bar
    // with its floating margin — so the thumbnails are never clipped. The
    // bar term alone is not enough: in fashion mode getBarPositionForScreen
    // falls back to the taskbar edge while getBarHeightForScreen returns
    // the status-bar density height, which is smaller than the dock's
    // thickness (BarService.edgeClearance).
    readonly property real barInset: BarService.edgeClearance(targetScreenName, "bottom")
    readonly property real contentPreferredHeight: Style.wallpaperStripHeight + barInset
    readonly property string targetScreenName: root.screen ? root.screen.name : ""
    readonly property bool isWallhaven: Settings.data.wallpaper.useWallhaven
    readonly property string currentSlot: Settings.data.colorSchemes.darkMode ? "dark" : "light"
    readonly property bool wallhavenBusy: typeof WallhavenService !== "undefined" && WallhavenService.fetching

    property string filterText: ""
    property string currentWallpaper: ""
    property bool isBrowseMode: false
    property int _browseScanGeneration: 0

    ListModel {
      id: stripModel
    }

    // ------------------------------------------------------------------
    // Applying
    // ------------------------------------------------------------------

    function applyToScreens(path, slot) {
      if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          WallpaperService.changeWallpaper(path, Quickshell.screens[i].name, slot);
        }
      } else if (targetScreenName !== "") {
        WallpaperService.changeWallpaper(path, targetScreenName, slot);
      }
    }

    // §3.10 puts three buttons under a hovered thumbnail. The shell has no
    // separate lock-screen wallpaper (LockScreenBackground mirrors the
    // desktop one through a blurred cache), so the two appearance slots the
    // service actually supports take that role instead of desktop/lock.
    // Buttons are labelled by the fixed slot they write ("light"/"dark"/
    // "both") — "current appearance" labels forced the reader to know which
    // mode was active before the buttons made sense.
    function applyCurrent(path) {
      applyToScreens(path, currentSlot);
    }
    function applySlot(path, slot) {
      if (slot === "both")
        applyBoth(path);
      else
        applyToScreens(path, slot);
    }
    function applyBoth(path) {
      applyToScreens(path, "light");
      applyToScreens(path, "dark");
    }

    function applyWallhaven(wallpaper, slot) {
      WallhavenService.downloadWallpaper(wallpaper, function (path, success) {
        if (!success || !path) {
          Logger.w("WallpaperPanel", "Wallhaven download failed for", wallpaper.id);
          return;
        }
        if (slot === "light" || slot === "dark" || slot === "both")
          applySlot(path, slot);
        else
          applyCurrent(path);
      });
    }

    // ------------------------------------------------------------------
    // Model
    // ------------------------------------------------------------------

    function rebuildItems(directories, files) {
      var items = [];
      for (var i = 0; i < directories.length; i++) {
        items.push({
                     "path": directories[i],
                     "name": directories[i].split('/').pop(),
                     "isDirectory": true,
                     "wallhavenId": "",
                     "thumbUrl": ""
                   });
      }
      for (var i = 0; i < files.length; i++) {
        items.push({
                     "path": files[i],
                     "name": files[i].split('/').pop(),
                     "isDirectory": false,
                     "wallhavenId": "",
                     "thumbUrl": ""
                   });
      }
      WallpaperService.favoritesRevision;
      items.sort(function (a, b) {
        const af = !a.isDirectory && WallpaperService.isFavorite(a.path) ? 0 : 1;
        const bf = !b.isDirectory && WallpaperService.isFavorite(b.path) ? 0 : 1;
        if (af !== bf)
          return af - bf;
        return a.name.localeCompare(b.name);
      });

      var visible = items;
      if (filterText.trim() !== "") {
        visible = FuzzySort.go(filterText.trim(), items, {
                                 "key": "name",
                                 "limit": 200
                               }).map(function (r) {
                                 return r.obj;
                               });
      }

      stripModel.clear();
      for (var i = 0; i < visible.length; i++) {
        stripModel.append(visible[i]);
      }
      stripView.currentIndex = stripModel.count > 0 ? 0 : -1;
    }

    function rebuildWallhaven() {
      stripModel.clear();
      var list = (typeof WallhavenService !== "undefined") ? WallhavenService.currentResults : [];
      for (var i = 0; i < list.length; i++) {
        const w = list[i];
        const url = WallhavenService.getThumbnailUrl(w, "large");
        stripModel.append({
                            "path": url,
                            "wallhavenId": w.id,
                            "name": w.resolution || w.id,
                            "isDirectory": false,
                            "thumbUrl": url
                          });
      }
      stripView.currentIndex = stripModel.count > 0 ? 0 : -1;
    }

    function refresh() {
      currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreenName, currentSlot);
      if (isWallhaven) {
        rebuildWallhaven();
        return;
      }
      if (isBrowseMode) {
        // Bump the generation so stale scan callbacks from rapid navigation
        // are ignored.
        const gen = ++_browseScanGeneration;
        const browsePath = WallpaperService.getCurrentBrowsePath(targetScreenName);
        WallpaperService.scanDirectoryWithDirs(targetScreenName, browsePath, function (result) {
          if (gen !== _browseScanGeneration)
            return;
          Logger.d("WallpaperPanel", "Browse", browsePath, "->", result.files.length, "files,", result.directories.length, "dirs");
          rebuildItems(result.directories, result.files);
        });
      } else {
        rebuildItems([], WallpaperService.getWallpapersList(targetScreenName));
      }
    }

    function selectItem(item) {
      if (item.isDirectory) {
        WallpaperService.setBrowsePath(targetScreenName, item.path);
        isBrowseMode = true;
        stripView.contentX = 0;
        refresh();
        return;
      }
      if (isWallhaven)
        applyWallhaven(stripView.wallhavenById(item.wallhavenId), "current");
      else
        applyCurrent(item.path);
    }

    Connections {
      target: WallpaperService
      function onFavoritesChanged() {
        strip.refresh();
      }
      // The XDG scan finishes after the panel may already be open; refresh so
      // a late scan is not invisible.
      function onWallpaperListChanged() {
        strip.refresh();
      }
      function onCurrentWallpapersChanged() {
        strip.currentWallpaper = WallpaperService.getWallpaperPathForSlot(strip.targetScreenName, strip.currentSlot);
      }
    }

    Connections {
      target: root
      // getCurrentBrowsePath() always returns the configured root, so browse
      // mode is tracked by strip itself: it turns on when a folder is opened
      // and off again at the root.
      function onOpened() {
        if (!root.contentItem)
          root.contentItem = strip;
        searchInput.text = strip.isWallhaven ? (Settings.data.wallpaper.wallhavenQuery || "") : strip.filterText;
        strip.refresh();
        Qt.callLater(function () {
          if (searchInput.inputItem)
            searchInput.inputItem.forceActiveFocus();
        });
      }
    }

    // ------------------------------------------------------------------
    // Source row (§3.10: above the filmstrip, 30 px high)
    // ------------------------------------------------------------------

    Timer {
      id: searchDebounceTimer
      interval: strip.isWallhaven ? 500 : 150
      onTriggered: {
        strip.filterText = searchInput.text;
        if (strip.isWallhaven) {
          Settings.data.wallpaper.wallhavenQuery = searchInput.text;
          if (typeof WallhavenService !== "undefined")
            WallhavenService.search(searchInput.text, 1);
        }
        strip.refresh();
      }
    }

    RowLayout {
      id: sourceRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.marginL
      anchors.rightMargin: Style.marginL
      height: Style.wallpaperStripRowHeight
      spacing: Style.marginS

      NIcon {
        icon: "settings-wallpaper-selector"
        pointSize: Style.fontSizeXXL
        color: Colors.onShell
      }

      NTextInput {
        id: searchInput
        Layout.preferredWidth: Math.round(290 * Style.uiScaleRatio)
        height: Style.wallpaperStripRowHeight
        fontSize: Style.fontSizeM
        placeholderText: strip.isWallhaven ? I18n.tr("placeholders.search-wallhaven") : I18n.tr("placeholders.search-wallpapers")
        onTextChanged: searchDebounceTimer.restart()
      }

      NComboBox {
        id: sourceCombo
        Layout.preferredWidth: Math.round(140 * Style.uiScaleRatio)
        height: Style.wallpaperStripRowHeight
        onShellSurface: true
        model: [
          {
            "key": "local",
            "name": I18n.tr("common.local")
          },
          {
            "key": "wallhaven",
            "name": I18n.tr("wallpaper.panel.source-wallhaven")
          }
        ]
        currentKey: strip.isWallhaven ? "wallhaven" : "local"
        property bool skipNextSelected: false
        Component.onCompleted: {
          skipNextSelected = true;
          Qt.callLater(function () {
            skipNextSelected = false;
          });
        }
        onSelected: key => {
                      if (skipNextSelected)
                      return;
                      const useWallhaven = key === "wallhaven";
                      Settings.data.wallpaper.useWallhaven = useWallhaven;
                      searchInput.text = useWallhaven ? (Settings.data.wallpaper.wallhavenQuery || "") : strip.filterText;
                      if (useWallhaven && typeof WallhavenService !== "undefined") {
                        WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
                        WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
                        WallhavenService.sorting = Settings.data.wallpaper.wallhavenSorting;
                        WallhavenService.order = Settings.data.wallpaper.wallhavenOrder;
                        stripView.contentX = 0;
                        WallhavenService.search(searchInput.text, 1);
                      }
                      strip.refresh();
                    }
      }

      NComboBox {
        id: resolutionCombo
        Layout.preferredWidth: Math.round(190 * Style.uiScaleRatio)
        height: Style.wallpaperStripRowHeight
        onShellSurface: true
        visible: strip.isWallhaven
        model: [
          {
            "key": "",
            "name": I18n.tr("wallpaper.panel.resolution-label")
          },
          {
            "key": "1920x1080",
            "name": I18n.tr("wallpaper.panel.resolution-atleast") + " 1920x1080"
          },
          {
            "key": "2560x1440",
            "name": I18n.tr("wallpaper.panel.resolution-atleast") + " 2560x1440"
          },
          {
            "key": "3840x2160",
            "name": I18n.tr("wallpaper.panel.resolution-atleast") + " 3840x2160"
          }
        ]
        currentKey: {
          const w = Settings.data.wallpaper.wallhavenResolutionWidth;
          const h = Settings.data.wallpaper.wallhavenResolutionHeight;
          return (w && h) ? w + "x" + h : "";
        }
        onSelected: key => {
                      if (key === "") {
                        Settings.data.wallpaper.wallhavenResolutionWidth = "";
                        Settings.data.wallpaper.wallhavenResolutionHeight = "";
                      } else {
                        const parts = key.split("x");
                        Settings.data.wallpaper.wallhavenResolutionWidth = parts[0];
                        Settings.data.wallpaper.wallhavenResolutionHeight = parts[1];
                      }
                      if (typeof WallhavenService !== "undefined") {
                        stripView.contentX = 0;
                        WallhavenService.search(searchInput.text, 1);
                      }
                    }
      }

      Item {
        Layout.fillWidth: true
      }

      NIconButton {
        icon: "palette"
        baseSize: Style.wallpaperStripRowHeight
        tooltipText: I18n.tr("wallpaper.panel.solid-color-tooltip")
        colorBg: Settings.data.wallpaper.useSolidColor ? Colors.mPrimary : "transparent"
        colorFg: Settings.data.wallpaper.useSolidColor ? Colors.mOnPrimary : Colors.onShellSecondary
        onClicked: solidColorPicker.open()
      }

      NIconButton {
        visible: !strip.isWallhaven && strip.isBrowseMode
        icon: "folder-up"
        baseSize: Style.wallpaperStripRowHeight
        tooltipText: I18n.tr("wallpaper.browse.go-up")
        onClicked: {
          WallpaperService.navigateUp(strip.targetScreenName);
          stripView.contentX = 0;
          strip.refresh();
        }
      }

      NIconButton {
        visible: !strip.isWallhaven && strip.isBrowseMode
        icon: "home"
        baseSize: Style.wallpaperStripRowHeight
        tooltipText: I18n.tr("wallpaper.browse.go-root")
        onClicked: {
          WallpaperService.navigateToRoot(strip.targetScreenName);
          strip.isBrowseMode = false;
          stripView.contentX = 0;
          strip.refresh();
        }
      }

      NIconButton {
        visible: strip.isWallhaven
        icon: "settings"
        baseSize: Style.wallpaperStripRowHeight
        tooltipText: I18n.tr("wallpaper.panel.wallhaven-settings-title")
        onClicked: wallhavenPopup.showAt(sourceRow)
      }
    }

    // ------------------------------------------------------------------
    // Filmstrip
    // ------------------------------------------------------------------

    ListView {
      id: stripView

      function wallhavenById(id) {
        var list = (typeof WallhavenService !== "undefined") ? WallhavenService.currentResults : [];
        for (var i = 0; i < list.length; i++) {
          if (list[i].id === id)
            return list[i];
        }
        return null;
      }

      function applyCurrentIndex() {
        if (currentIndex < 0 || currentIndex >= count)
          return;
        strip.selectItem(model.get(currentIndex));
      }

      // §3.10: wheel and chevron paging share one animation so a drag or a
      // new scroll request cancels the in-flight one cleanly.
      NumberAnimation {
        id: stripScrollAnim
        target: stripView
        property: "contentX"
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }

      function scrollBy(delta) {
        stripScrollAnim.stop();
        stripScrollAnim.to = Math.max(0, Math.min(Math.max(0, contentWidth - width), contentX + delta));
        stripScrollAnim.start();
      }

      // One page keeps the first/last visible thumb as an anchor for the eye.
      function scrollPage(dir) {
        scrollBy(dir * Math.max(Style.wallpaperStripThumbWidth, width - Style.wallpaperStripThumbWidth));
      }

      onDraggingChanged: {
        if (dragging)
          stripScrollAnim.stop();
      }
      onFlickingChanged: {
        if (flicking)
          stripScrollAnim.stop();
      }

      // §3.10: a horizontal strip answers the wheel — vertical wheel and
      // touchpad pans both scroll contentX. This deliberately uses an item's
      // wheelEvent path (MouseArea.onWheel), not a WheelHandler: on niri the
      // PointerHandler never sees the wheel while item-level delivery works
      // (verified via qt.quick.pointer tracing — the event enters the window
      // but the handler's wantsPointerEvent path drops it before onWheel).
      // Parented to the view itself, not the content item, so it is the
      // topmost leaf under the cursor even over a delegate; NoButton keeps
      // clicks, drags and hover flowing through to the delegates below.
      MouseArea {
        parent: stripView
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
                   const delta = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : (wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y) / 2;
                   if (delta === 0) {
                     wheel.accepted = false;
                     return;
                   }
                   // Same 2x wheel multiplier as the N*View widgets (their
                   // wheelScrollMultiplier default): one mouse notch moves
                   // about one thumbnail, touchpad pans stay 1:1-ish.
                   stripView.scrollBy(-delta * 2.0);
                   wheel.accepted = true;
                 }
      }

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: sourceRow.bottom
      anchors.bottom: parent.bottom
      anchors.topMargin: Style.marginXS
      anchors.leftMargin: Style.marginL
      anchors.rightMargin: Style.marginL
      anchors.bottomMargin: Style.marginS + strip.barInset
      orientation: ListView.Horizontal
      // Without this the flickable consumes vertical wheel events as a
      // dead-axis flick attempt before any WheelHandler sees them — the
      // strip's wheel scrolling appeared to do nothing.
      flickableDirection: Flickable.HorizontalFlick
      spacing: Style.wallpaperStripSpacing
      clip: true
      model: stripModel
      focus: true
      highlightMoveDuration: 0
      cacheBuffer: Math.round(900 * Style.uiScaleRatio)
      boundsBehavior: Flickable.StopAtBounds

      delegate: Item {
        id: thumb

        required property int index
        required property string path
        required property string name
        required property bool isDirectory
        required property string wallhavenId
        required property string thumbUrl

        readonly property bool isCurrent: !isDirectory && !strip.isWallhaven && path === strip.currentWallpaper
        property bool hovered: false
        readonly property bool showsActions: hovered && !isDirectory

        width: Style.wallpaperStripThumbWidth
        height: Style.wallpaperStripThumbHeight

        // Local files resolve through ImageCacheService; Wallhaven items
        // already carry a remote thumbnail URL.
        property string cachedPath: ""

        Component.onCompleted: {
          if (isDirectory) {
            cachedPath = "";
            return;
          }
          if (thumbUrl !== "") {
            cachedPath = thumbUrl;
            return;
          }
          if (ImageCacheService.initialized) {
            ImageCacheService.getThumbnail(path, function (p, success) {
              thumb.cachedPath = success ? p : path;
            });
          } else {
            cachedPath = path;
          }
        }

        Rectangle {
          id: thumbFrame
          width: Style.wallpaperStripThumbWidth
          height: Style.wallpaperStripThumbHeight
          radius: Style.radiusM
          color: Colors.overlay("field")
          border.width: thumb.isCurrent ? Style.wallpaperStripCurrentRingWidth : 0
          border.color: Colors.accent
          clip: true

          NImageRounded {
            anchors.fill: parent
            radius: Style.radiusM
            visible: !thumb.isDirectory
            imagePath: thumb.cachedPath
          }

          NIcon {
            anchors.centerIn: parent
            visible: thumb.isDirectory
            icon: "folder"
            pointSize: Style.fontSizeXXXL
            color: Colors.accent
          }
        }

        // Favorite star (top-left of the thumbnail). Local files only —
        // a Wallhaven entry's path is a remote thumbnail URL, not a local
        // wallpaper, so favoriting it would be meaningless.
        Rectangle {
          id: favStar

          readonly property bool isFavorited: {
            WallpaperService.favoritesRevision;
            return !thumb.isDirectory && !strip.isWallhaven && WallpaperService.isFavorite(thumb.path);
          }

          anchors.top: thumbFrame.top
          anchors.left: thumbFrame.left
          anchors.margins: Style.marginS
          width: Style.baseWidgetSize
          height: width
          radius: width / 2
          z: 11
          visible: isFavorited || thumb.hovered
          color: {
            if (isFavorited)
              return starHover.hovered ? Colors.mHover : Colors.mPrimary;
            return starHover.hovered ? Colors.mSurfaceVariant : Colors.mSurface;
          }
          opacity: isFavorited || starHover.hovered ? 1.0 : 0.7

          NIcon {
            icon: favStar.isFavorited ? "star-filled" : "star"
            pointSize: Style.fontSizeM
            color: {
              if (favStar.isFavorited)
                return starHover.hovered ? Colors.mOnHover : Colors.mOnPrimary;
              return starHover.hovered ? Colors.mOnSurface : Colors.mOnSurfaceVariant;
            }
            anchors.centerIn: parent
          }

          HoverHandler {
            id: starHover
          }

          TapHandler {
            onTapped: {
              var mon = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : strip.targetScreenName;
              WallpaperService.toggleFavorite(thumb.path, WallpaperService.wallpaperSelectionAppearance, mon);
            }
          }
        }

        // §3.10: hovering reveals the three apply buttons — labelled by the
        // fixed slot they write ("light" / "dark" / both), so the meaning is
        // the same no matter which appearance is active. They overlay the
        // thumbnail's bottom edge; reserving strip space for a hover-only row
        // would clip or waste the band height.
        Row {
          id: actions

          anchors.horizontalCenter: thumbFrame.horizontalCenter
          anchors.bottom: thumbFrame.bottom
          anchors.bottomMargin: Style.marginXS
          spacing: Style.marginXS
          z: 1
          visible: thumb.showsActions
          opacity: thumb.showsActions ? 1 : 0

          // On-image chips (DESIGN §1.5): a photo is an arbitrary backdrop,
          // so the pill gets the fixed dark veil + onWallpaper text — the
          // theme-following overlay/onShell ladder washes out on bright
          // wallpapers.
          NButton {
            text: I18n.tr("wallpaper.strip.light")
            tooltipText: I18n.tr("wallpaper.strip.light-tip")
            fontSize: Style.fontSizeXS
            buttonRadius: Style.radiusPill
            height: Style.wallpaperStripActionHeight
            backgroundColor: Qt.alpha(Colors.veilWallpaper, 0.6)
            textColor: Colors.onWallpaper
            hoverColor: Qt.alpha(Colors.veilWallpaper, 0.8)
            textHoverColor: Colors.onWallpaper
            onClicked: strip.isWallhaven ? strip.applyWallhaven(stripView.wallhavenById(thumb.wallhavenId), "light") : strip.applySlot(thumb.path, "light")
          }
          NButton {
            text: I18n.tr("wallpaper.strip.dark")
            tooltipText: I18n.tr("wallpaper.strip.dark-tip")
            fontSize: Style.fontSizeXS
            buttonRadius: Style.radiusPill
            height: Style.wallpaperStripActionHeight
            backgroundColor: Qt.alpha(Colors.veilWallpaper, 0.6)
            textColor: Colors.onWallpaper
            hoverColor: Qt.alpha(Colors.veilWallpaper, 0.8)
            textHoverColor: Colors.onWallpaper
            onClicked: strip.isWallhaven ? strip.applyWallhaven(stripView.wallhavenById(thumb.wallhavenId), "dark") : strip.applySlot(thumb.path, "dark")
          }
          NButton {
            text: I18n.tr("wallpaper.strip.both")
            tooltipText: I18n.tr("wallpaper.strip.both-tip")
            fontSize: Style.fontSizeXS
            buttonRadius: Style.radiusPill
            height: Style.wallpaperStripActionHeight
            backgroundColor: Qt.alpha(Colors.veilWallpaper, 0.6)
            textColor: Colors.onWallpaper
            hoverColor: Qt.alpha(Colors.veilWallpaper, 0.8)
            textHoverColor: Colors.onWallpaper
            onClicked: strip.isWallhaven ? strip.applyWallhaven(stripView.wallhavenById(thumb.wallhavenId), "both") : strip.applyBoth(thumb.path)
          }
        }

        HoverHandler {
          id: hoverHandler
          onHoveredChanged: thumb.hovered = hovered
        }

        HoverHandler {
          id: tipHandler
          onHoveredChanged: {
            if (hovered)
              TooltipService.show(thumbFrame, thumb.name);
            else
              TooltipService.hide();
          }
        }

        TapHandler {
          acceptedButtons: Qt.LeftButton
          onTapped: {
            stripView.currentIndex = thumb.index;
            strip.selectItem({
                               "path": thumb.path,
                               "isDirectory": thumb.isDirectory,
                               "wallhavenId": thumb.wallhavenId
                             });
          }
        }
      }
    }

    // Edge chevrons (§3.10): paged scrolling for pointer users. They overlay
    // the thumbnail band at the strip ends and only appear while content can
    // actually be revealed in that direction.
    NIconButtonHot {
      id: stripPrev
      anchors.left: stripView.left
      anchors.leftMargin: Style.marginXS
      y: stripView.y + (Style.wallpaperStripThumbHeight - height) / 2
      icon: "chevron-left"
      baseSize: Style.baseWidgetSize
      applyUiScale: false
      visible: stripView.contentWidth > stripView.width && stripView.contentX > 0.5
      colorBg: Colors.overlay("field")
      colorBgHover: Colors.overlay("hover")
      colorBorder: Colors.borderShell
      onClicked: stripView.scrollPage(-1)
    }

    NIconButtonHot {
      id: stripNext
      anchors.right: stripView.right
      anchors.rightMargin: Style.marginXS
      y: stripView.y + (Style.wallpaperStripThumbHeight - height) / 2
      icon: "chevron-right"
      baseSize: Style.baseWidgetSize
      applyUiScale: false
      visible: stripView.contentWidth > stripView.width && stripView.contentX < stripView.contentWidth - stripView.width - 0.5
      colorBg: Colors.overlay("field")
      colorBgHover: Colors.overlay("hover")
      colorBorder: Colors.borderShell
      onClicked: stripView.scrollPage(1)
    }

    // Empty state
    Column {
      anchors.centerIn: parent
      spacing: Style.marginXS
      visible: stripView.count === 0

      NIcon {
        width: Style.fontSizeXXL
        height: Style.fontSizeXXL
        icon: "settings-wallpaper-selector"
        color: Colors.overlay("strong")
      }

      NLabel {
        labelSize: Style.fontSizeM
        labelColor: Colors.onShell
        label: strip.isWallhaven ? (strip.wallhavenBusy ? I18n.tr("wallpaper.wallhaven.loading") : I18n.tr("wallpaper.wallhaven.no-results")) : (strip.filterText.trim() === "" ? I18n.tr("wallpaper.no-wallpaper") : I18n.tr("wallpaper.no-match"))
      }
    }

    WallhavenSettingsPopup {
      id: wallhavenPopup
      screen: root.screen
    }

    NColorPickerDialog {
      id: solidColorPicker
      screen: root.screen
      selectedColor: Settings.data.wallpaper.solidColor
      onColorSelected: color => WallpaperService.setSolidColor(color.toString())
    }
  }
}
