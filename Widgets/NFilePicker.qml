import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Popup {
  id: root
  enter: NPopupEnter {}
  exit: NPopupExit {}

  // Properties
  property string title: I18n.tr("widget.file-picker.title")
  property string initialPath: Quickshell.env("HOME") || "/home"
  property string selectionMode: "files" // "files" or "folders"
  property var nameFilters: ["*"]
  property bool showDirs: true
  property bool showHiddenFiles: false
  property bool allowMultiSelection: false

  property var selectedPaths: []
  property string currentPath: initialPath
  property bool shouldResetSelection: false

  // Signals
  signal accepted(var paths)
  signal cancelled

  function openFilePicker() {
    if (!root.currentPath)
      root.currentPath = root.initialPath;
    shouldResetSelection = true;
    open();
  }

  function getFileIcon(fileName) {
    const ext = fileName.split('.').pop().toLowerCase();
    const iconMap = {
      "txt": 'filepicker-file-text',
      "md": 'filepicker-file-text',
      "log": 'filepicker-file-text',
      "jpg": 'filepicker-photo',
      "jpeg": 'filepicker-photo',
      "png": 'filepicker-photo',
      "gif": 'filepicker-photo',
      "bmp": 'filepicker-photo',
      "svg": 'filepicker-photo',
      "mp4": 'filepicker-video',
      "avi": 'filepicker-video',
      "mkv": 'filepicker-video',
      "mov": 'filepicker-video',
      "mp3": 'filepicker-music',
      "wav": 'filepicker-music',
      "flac": 'filepicker-music',
      "ogg": 'filepicker-music',
      "zip": 'filepicker-archive',
      "tar": 'filepicker-archive',
      "gz": 'filepicker-archive',
      "rar": 'filepicker-archive',
      "7z": 'filepicker-archive',
      "pdf": 'filepicker-text',
      "doc": 'filepicker-text',
      "docx": 'filepicker-text',
      "xls": 'filepicker-table',
      "xlsx": 'filepicker-table',
      "ppt": 'filepicker-presentation',
      "pptx": 'filepicker-presentation',
      "html": 'filepicker-code',
      "htm": 'filepicker-code',
      "css": 'filepicker-code',
      "js": 'filepicker-code',
      "json": 'filepicker-code',
      "xml": 'filepicker-code',
      "exe": 'filepicker-settings',
      "app": 'filepicker-settings',
      "deb": 'filepicker-settings',
      "rpm": 'filepicker-settings'
    };
    return iconMap[ext] || 'filepicker-file';
  }

  function formatFileSize(bytes) {
    if (bytes === 0)
      return "0 B";
    const k = 1024, sizes = ["B", "KB", "MB", "GB", "TB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
  }

  function confirmSelection() {
    if (filePickerPanel.currentSelection.length === 0)
      return;
    root.selectedPaths = filePickerPanel.currentSelection;
    root.accepted(filePickerPanel.currentSelection);
    root.close();
  }

  function updateFilteredModel() {
    filteredModel.clear();
    const searchText = filePickerPanel.filterText.toLowerCase();

    for (var i = 0; i < folderModel.count; i++) {
      const fileName = folderModel.get(i, "fileName");
      const filePath = folderModel.get(i, "filePath");
      const fileIsDir = folderModel.get(i, "fileIsDir");
      const fileSize = folderModel.get(i, "fileSize");

      // Skip hidden items if showHiddenFiles is false
      // This additional check ensures hidden files are properly filtered
      if (!root.showHiddenFiles && fileName.startsWith(".")) {
        continue;
      }

      // In folder mode, hide files
      if (root.selectionMode === "folders" && !fileIsDir)
        continue;
      if (searchText === "" || fileName.toLowerCase().includes(searchText)) {
        filteredModel.append({
                               "fileName": fileName,
                               "filePath": filePath,
                               "fileIsDir": fileIsDir,
                               "fileSize": fileSize
                             });
      }
    }
  }

  width: 900
  height: 700
  modal: true
  closePolicy: Popup.CloseOnEscape
  Shortcut {
    sequences: ["Escape"]
    // While search is open, Escape only dismisses the search field. The
    // panel Keys handler does that; this shortcut covers focus sitting on
    // a file row, which never reached Popup.CloseOnEscape.
    enabled: root.visible && !filePickerPanel.showSearchBar
    onActivated: root.close()
  }
  anchors.centerIn: parent
  // The settings surface does not publish a blur region for dialogs
  // (DESIGN §1.2). Host on the popup-menu window before the popup shows.
  onAboutToShow: PanelService.hostSettingsPopup(root, null)
  onOpened: filePickerPanel.forceActiveFocus()

  background: Rectangle {
    color: Colors.maskShell
    radius: Style.radiusWindow
    border.color: Colors.borderShell
    border.width: Style.borderS
  }

  Rectangle {
    id: filePickerPanel
    anchors.fill: parent
    anchors.margins: Style.marginL
    color: "transparent"

    property string filterText: ""
    property var currentSelection: []
    property bool viewMode: true // true = grid, false = list
    property string searchText: ""
    property bool showSearchBar: false

    focus: true

    Keys.onPressed: event => {
                      if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) {
                        filePickerPanel.showSearchBar = !filePickerPanel.showSearchBar;
                        if (filePickerPanel.showSearchBar)
                        Qt.callLater(() => searchInput.forceActiveFocus());
                        event.accepted = true;
                      } else if (event.key === Qt.Key_Escape) {
                        if (filePickerPanel.showSearchBar) {
                          filePickerPanel.showSearchBar = false;
                          filePickerPanel.searchText = "";
                          filePickerPanel.filterText = "";
                          root.updateFilteredModel();
                        } else {
                          root.close();
                        }
                        event.accepted = true;
                      }
                    }

    // Function when an item is clicked, either a folder or a file since both have the same functionality, reduces repetitive code
    function itemClicked(modifiers, path) {
      var list = currentSelection.slice();
      const index = list.indexOf(path);
      if (root.allowMultiSelection && (modifiers & Qt.ShiftModifier) && list.length > 0) {
        if (index > -1) {
          list.splice(index, 1);
          currentSelection = list;
        } else {
          var i = 0;
          var toggle = false;
          const firstItemPath = list[0];
          while (i < filteredModel.count) {
            const itemPath = filteredModel.get(i).filePath;

            // This should be called twice, when we get to the item selected and when we get to the starting item.
            if (itemPath === firstItemPath || itemPath === path) {
              toggle = !toggle;
            }

            // Add all files between the starting item and the item selected.
            if (toggle) {
              if (!list.includes(itemPath)) {
                list.push(itemPath);
              }
            }

            i++;
          }

          // Add the path selected as well since it's skipped in the while loop
          if (!list.includes(path)) {
            list.push(path);
          }
          currentSelection = list;
        }
      } else if (root.allowMultiSelection && (modifiers & Qt.ControlModifier)) {
        if (index > -1) {
          list.splice(index, 1);
          currentSelection = list;
        } else {
          list.push(path);
          currentSelection = list;
        }
      } else {
        currentSelection = [path];
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: "filepicker-folder"
          color: Colors.accent
          pointSize: Style.fontSizeXXL
        }
        NText {
          text: root.title
          pointSize: Style.fontSizeXL
          font.weight: Style.fontWeightSemiBold
          color: Colors.onShell
          Layout.fillWidth: true
        }

        // "Select Current" button only visible in folder selection mode
        NButton {
          text: I18n.tr("widgets.file-picker.select-current")
          icon: "filepicker-folder-current"
          visible: root.selectionMode === "folders"
          onClicked: {
            filePickerPanel.currentSelection = [root.currentPath];
            root.confirmSelection();
          }
        }

        NIconButton {
          icon: "filepicker-refresh"
          tooltipText: I18n.tr("common.refresh")
          onClicked: {
            // Force a proper refresh by resetting the folder
            const currentFolder = folderModel.folder;
            folderModel.folder = "";
            folderModel.folder = currentFolder;
            Qt.callLater(root.updateFilteredModel);
          }
        }
        NIconButton {
          icon: "filepicker-close"
          tooltipText: I18n.tr("common.close")
          onClicked: {
            root.cancelled();
            root.close();
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      // Navigation toolbar
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 45
        color: Colors.overlay("field")
        radius: Style.radiusWindow
        border.color: Colors.borderShell
        border.width: Style.borderS

        RowLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.marginS
          anchors.rightMargin: Style.marginS
          spacing: Style.marginS

          NIconButton {
            icon: "filepicker-arrow-up"
            tooltipText: I18n.tr("tooltips.up")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: folderModel.folder.toString() !== "file:///"
            onClicked: {
              const parentPath = folderModel.parentFolder.toString().replace("file://", "");
              folderModel.folder = "file://" + parentPath;
              root.currentPath = parentPath;
            }
          }

          NIconButton {
            icon: "filepicker-home"
            tooltipText: I18n.tr("tooltips.home")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              const homePath = Quickshell.env("HOME") || "/home";
              folderModel.folder = "file://" + homePath;
              root.currentPath = homePath;
            }
          }

          NIconButton {
            icon: filePickerPanel.showSearchBar ? "filepicker-x" : "filepicker-search"
            tooltipText: filePickerPanel.showSearchBar ? I18n.tr("tooltips.search-close") : I18n.tr("common.search")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              filePickerPanel.showSearchBar = !filePickerPanel.showSearchBar;
              if (!filePickerPanel.showSearchBar) {
                filePickerPanel.searchText = "";
                filePickerPanel.filterText = "";
                root.updateFilteredModel();
              }
            }
          }

          NTextInput {
            id: locationInput
            text: root.currentPath
            placeholderText: I18n.tr("placeholders.enter-path")
            Layout.fillWidth: true

            visible: !filePickerPanel.showSearchBar
            enabled: !filePickerPanel.showSearchBar

            onEditingFinished: {
              const newPath = text.trim();
              if (newPath !== "" && newPath !== root.currentPath) {
                folderModel.folder = "file://" + newPath;
                root.currentPath = newPath;
              } else {
                text = root.currentPath;
              }
            }
            Connections {
              target: root
              function onCurrentPathChanged() {
                if (!locationInput.activeFocus)
                  locationInput.text = root.currentPath;
              }
            }
          }

          // Search bar
          NTextInput {
            id: searchInput
            inputIconName: "search"
            placeholderText: I18n.tr("placeholders.search")
            Layout.fillWidth: true

            visible: filePickerPanel.showSearchBar
            enabled: filePickerPanel.showSearchBar

            text: filePickerPanel.searchText
            onTextChanged: {
              filePickerPanel.searchText = text;
              filePickerPanel.filterText = text;
              root.updateFilteredModel();
            }
            Keys.onEscapePressed: {
              filePickerPanel.showSearchBar = false;
              filePickerPanel.searchText = "";
              filePickerPanel.filterText = "";
              root.updateFilteredModel();
            }
          }

          NIconButton {
            icon: filePickerPanel.viewMode ? "filepicker-list" : "filepicker-layout-grid"
            tooltipText: filePickerPanel.viewMode ? I18n.tr("tooltips.list-view") : I18n.tr("tooltips.grid-view")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: filePickerPanel.viewMode = !filePickerPanel.viewMode
          }
          NIconButton {
            icon: root.showHiddenFiles ? "filepicker-eye-off" : "filepicker-eye"
            tooltipText: root.showHiddenFiles ? I18n.tr("tooltips.hidden-files-hide") : I18n.tr("tooltips.hidden-files-show")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              root.showHiddenFiles = !root.showHiddenFiles;
              // Force model refresh by resetting the folder
              const currentFolder = folderModel.folder;
              folderModel.folder = "";
              folderModel.folder = currentFolder;
              Qt.callLater(root.updateFilteredModel);
            }
          }
        }
      }

      // File list area
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Colors.maskShell
        radius: Style.radiusWindow
        border.color: Colors.borderShell
        border.width: Style.borderS

        FolderListModel {
          id: folderModel
          folder: "file://" + root.currentPath
          // Use wildcard filters including hidden files when showHiddenFiles is true
          nameFilters: root.showHiddenFiles ? ["*", ".*"] : root.nameFilters
          showDirs: root.showDirs
          showHidden: true // Always true, we'll filter in updateFilteredModel
          showDotAndDotDot: false
          sortField: FolderListModel.Name
          sortReversed: false

          onFolderChanged: {
            root.currentPath = folder.toString().replace("file://", "");
            filePickerPanel.currentSelection = [];
            Qt.callLater(root.updateFilteredModel);
          }

          onStatusChanged: {
            if (status === FolderListModel.Error) {
              if (root.currentPath !== Quickshell.env("HOME")) {
                folder = "file://" + Quickshell.env("HOME");
                root.currentPath = Quickshell.env("HOME");
              }
            } else if (status === FolderListModel.Ready) {
              root.updateFilteredModel();
            }
          }
        }

        // Update nameFilters when showHiddenFiles changes
        Connections {
          target: root
          function onShowHiddenFilesChanged() {
            folderModel.nameFilters = root.showHiddenFiles ? ["*", ".*"] : root.nameFilters;
          }
        }

        ListModel {
          id: filteredModel
        }

        // Grid view
        NGridView {
          id: gridView
          anchors.fill: parent
          anchors.margins: Style.marginM
          model: filteredModel
          visible: filePickerPanel.viewMode
          reuseItems: true

          property int columns: Math.max(1, Math.floor(availableWidth / 120))
          property int itemSize: Math.floor((availableWidth - leftMargin - rightMargin - (columns * Style.marginS)) / columns)

          cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
          cellHeight: Math.floor(itemSize * 0.8) + Style.marginXS + Style.fontSizeS + Style.marginM

          leftMargin: Style.marginS
          rightMargin: Style.marginS
          topMargin: Style.marginS
          bottomMargin: Style.marginS

          delegate: Rectangle {
            id: gridItem
            // Roles as required properties — model.<role> in bindings captures
            // the live row proxy and crashes on the next model mutation
            // (DESIGN §1.7). filteredModel is rebuilt on every keystroke.
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property real fileSize
            width: gridView.itemSize
            height: gridView.cellHeight
            color: "transparent"
            radius: Style.radiusItem

            property bool isSelected: filePickerPanel.currentSelection.includes(filePath)

            Rectangle {
              anchors.fill: parent
              color: "transparent"
              radius: parent.radius
              border.color: isSelected ? Colors.accent : Colors.borderShell
              border.width: Style.borderL
            }

            Rectangle {
              anchors.fill: parent
              color: (mouseArea.containsMouse && !isSelected) ? Colors.overlay("checked") : "transparent"
              radius: parent.radius
              border.color: (mouseArea.containsMouse && !isSelected) ? Colors.overlay("checked") : "transparent"
              border.width: Style.borderS
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginXS

              Rectangle {
                id: iconContainer
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(gridView.itemSize * 0.67)
                color: "transparent"

                property bool isImage: {
                  if (fileIsDir)
                    return false;
                  const ext = fileName.split('.').pop().toLowerCase();
                  return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico'].includes(ext);
                }

                Image {
                  id: thumbnail
                  anchors.fill: parent
                  anchors.margins: Style.marginXS
                  source: iconContainer.isImage ? "file://" + filePath : ""
                  fillMode: Image.PreserveAspectFit
                  visible: iconContainer.isImage && status === Image.Ready
                  smooth: false
                  cache: true
                  asynchronous: true
                  sourceSize.width: 120
                  sourceSize.height: 120
                  onStatusChanged: {
                    if (status === Image.Error)
                      visible = false;
                  }

                  Rectangle {
                    anchors.fill: parent
                    color: Colors.overlay("field")
                    radius: Style.radiusItem
                    visible: thumbnail.status === Image.Loading
                    NIcon {
                      icon: "filepicker-photo"
                      pointSize: Style.fontSizeL
                      color: Colors.onShellSecondary
                      anchors.centerIn: parent
                    }
                  }
                }

                NIcon {
                  icon: fileIsDir ? "filepicker-folder" : root.getFileIcon(fileName)
                  pointSize: Style.fontSizeXXL * 2
                  color: {
                    if (isSelected)
                      return Colors.accent;
                    else if (mouseArea.containsMouse)
                      return Colors.accent;
                    else
                      return fileIsDir ? Colors.accent : Colors.onShellSecondary;
                  }
                  anchors.centerIn: parent
                  visible: !iconContainer.isImage || thumbnail.status !== Image.Ready
                }

                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Style.marginS
                  width: 24
                  height: 24
                  radius: Math.min(Style.radiusRow, width / 2)
                  color: Colors.accent
                  border.color: Colors.borderShell
                  border.width: Style.borderS
                  visible: isSelected
                  NIcon {
                    icon: "filepicker-check"
                    pointSize: Style.fontSizeS
                    color: Colors.onAccent
                    anchors.centerIn: parent
                  }
                }
              }

              NText {
                text: fileName
                color: {
                  if (isSelected)
                    return Colors.accent;
                  else if (mouseArea.containsMouse)
                    return Colors.accent;
                  else
                    return Colors.onShellSecondary;
                }
                pointSize: Style.fontSizeS
                font.weight: isSelected ? Style.fontWeightSemiBold : Style.fontWeightRegular
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                maximumLineCount: 2
              }
            }

            MouseArea {
              id: mouseArea
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton

              onClicked: mouse => {
                           if (mouse.button === Qt.LeftButton) {
                             if (fileIsDir) {
                               // In folder mode, single click selects the folder
                               if (root.selectionMode === "folders") {
                                 filePickerPanel.itemClicked(mouse.modifiers, filePath);
                               }
                               // In file mode, single click on folder does nothing (must double-click to enter)
                             } else {
                               // Single click on file selects it (only in file mode)
                               if (root.selectionMode === "files") {
                                 filePickerPanel.itemClicked(mouse.modifiers, filePath);
                               }
                             }
                           }
                         }

              onDoubleClicked: mouse => {
                                 if (mouse.button === Qt.LeftButton) {
                                   if (fileIsDir) {
                                     // Double-click on folder always navigates into it
                                     folderModel.folder = "file://" + filePath;
                                     root.currentPath = filePath;
                                   } else {
                                     // Double-click on file selects and confirms (only in file mode)
                                     if (root.selectionMode === "files") {
                                       filePickerPanel.currentSelection = [filePath];
                                       root.confirmSelection();
                                     }
                                   }
                                 }
                               }
            }
          }
        }

        // List view
        NListView {
          id: listView
          anchors.fill: parent
          anchors.margins: Style.marginS
          model: filteredModel
          visible: !filePickerPanel.viewMode

          delegate: Rectangle {
            id: listItem
            // Roles as required properties — see gridItem (DESIGN §1.7).
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property real fileSize
            width: listView.width
            height: 40
            color: {
              if (filePickerPanel.currentSelection.includes(filePath))
                return Colors.accent;
              if (listMouseArea.containsMouse)
                return Colors.overlay("checked");
              return "transparent";
            }
            radius: Style.radiusItem

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginM
              anchors.rightMargin: Style.marginM
              spacing: Style.marginM

              NIcon {
                icon: fileIsDir ? "filepicker-folder" : root.getFileIcon(fileName)
                pointSize: Style.fontSizeL
                color: fileIsDir ? (filePickerPanel.currentSelection.includes(filePath) ? Colors.onAccent : Colors.accent) : Colors.onShellSecondary
              }

              NText {
                text: fileName
                color: filePickerPanel.currentSelection.includes(filePath) ? Colors.onAccent : Colors.onShell
                pointSize: Style.fontSizeM
                font.weight: filePickerPanel.currentSelection.includes(filePath) ? Style.fontWeightSemiBold : Style.fontWeightRegular
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              NText {
                text: fileIsDir ? "" : root.formatFileSize(fileSize)
                color: filePickerPanel.currentSelection.includes(filePath) ? Colors.onAccent : Colors.onShellSecondary
                pointSize: Style.fontSizeS
                visible: !fileIsDir
                Layout.preferredWidth: implicitWidth
              }
            }

            MouseArea {
              id: listMouseArea
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton

              onClicked: mouse => {
                           if (mouse.button === Qt.LeftButton) {
                             if (fileIsDir) {
                               // In folder mode, single click selects the folder
                               if (root.selectionMode === "folders") {
                                 filePickerPanel.itemClicked(mouse.modifiers, filePath);
                               }
                               // In file mode, single click on folder does nothing (must double-click to enter)
                             } else {
                               // Single click on file selects it (only in file mode)
                               if (root.selectionMode === "files") {
                                 filePickerPanel.itemClicked(mouse.modifiers, filePath);
                               }
                             }
                           }
                         }

              onDoubleClicked: mouse => {
                                 if (mouse.button === Qt.LeftButton) {
                                   if (fileIsDir) {
                                     // Double-click on folder always navigates into it
                                     folderModel.folder = "file://" + filePath;
                                     root.currentPath = filePath;
                                   } else {
                                     // Double-click on file selects and confirms (only in file mode)
                                     if (root.selectionMode === "files") {
                                       filePickerPanel.currentSelection = [filePath];
                                       root.confirmSelection();
                                     }
                                   }
                                 }
                               }
            }
          }
        }
      }

      // DDialog button bar separator
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Colors.overlay("hover")
      }

      // Footer
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: {
            if (filePickerPanel.searchText.length > 0) {
              return "Searching for: \"" + filePickerPanel.searchText + "\" (" + filteredModel.count + " matches)";
            } else if (filePickerPanel.currentSelection.length > 0) {
              const selectedName = filePickerPanel.currentSelection[0].split('/').pop();
              return I18n.tr("widgets.file-picker.selected") + " " + selectedName;
            } else {
              return filteredModel.count + " " + (filteredModel.count === 1 ? I18n.tr("widgets.file-picker.item") : I18n.tr("widgets.file-picker.items"));
            }
          }
          color: filePickerPanel.searchText.length > 0 ? Colors.accent : Colors.onShellSecondary
          pointSize: Style.fontSizeS
          Layout.fillWidth: true
        }

        NButton {
          text: I18n.tr("common.cancel")
          outlined: true
          onClicked: {
            root.cancelled();
            root.close();
          }
        }

        NButton {
          text: root.selectionMode === "folders" ? I18n.tr("widgets.file-picker.select-folder") : I18n.tr("widgets.file-picker.select-file")
          icon: "filepicker-check"
          backgroundColor: Colors.accent // recommended action → accent text
          enabled: filePickerPanel.currentSelection.length > 0
          onClicked: root.confirmSelection()
        }
      }
    }

    Connections {
      target: root
      function onShouldResetSelectionChanged() {
        if (root.shouldResetSelection) {
          filePickerPanel.currentSelection = [];
          root.shouldResetSelection = false;
        }
      }
    }

    Component.onCompleted: {
      if (!root.currentPath)
        root.currentPath = root.initialPath;
      folderModel.folder = "file://" + root.currentPath;
    }
  }
}
