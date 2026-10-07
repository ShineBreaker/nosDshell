import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  property var timeOptions
  property var schemeColorsCache: ({})
  property int cacheVersion: 0
  property var screen

  function extractSchemeName(schemePath) {
    var pathParts = schemePath.split("/");
    var filename = pathParts[pathParts.length - 1];
    var schemeName = filename.replace(".json", "");

    if (schemeName === "nosDshell-default") {
      schemeName = "nosDshell (default)";
    } else if (schemeName === "Tokyo-Night") {
      schemeName = "Tokyo Night";
    } else if (schemeName === "Rosepine") {
      schemeName = "Rose Pine";
    }

    return schemeName;
  }

  function getSchemeColor(schemeName, colorKey) {
    var _ = cacheVersion;

    if (schemeColorsCache[schemeName]) {
      var entry = schemeColorsCache[schemeName];
      var variant = entry;

      if (entry.dark || entry.light) {
        variant = Settings.data.colorSchemes.darkMode ? (entry.dark || entry.light) : (entry.light || entry.dark);
      }

      if (variant && variant[colorKey]) {
        return variant[colorKey];
      }
    }

    if (colorKey === "mSurface")
      return Color.mSurfaceVariant;
    if (colorKey === "mPrimary")
      return Color.mPrimary;
    if (colorKey === "mSecondary")
      return Color.mSecondary;
    if (colorKey === "mTertiary")
      return Color.mTertiary;
    if (colorKey === "mError")
      return Color.mError;
    return Color.mOnSurfaceVariant;
  }

  function schemeLoaded(schemeName, jsonData) {
    var value = jsonData || {};
    schemeColorsCache[schemeName] = value;
    cacheVersion++;
  }

  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    Connections {
      target: ColorSchemeService
      function onSchemesChanged() {
        root.schemeColorsCache = {};
        root.cacheVersion++;
      }
    }

    Item {
      id: fileLoaders
      visible: false

      Repeater {
        model: ColorSchemeService.schemes
        delegate: Item {
          FileView {
            path: modelData
            blockLoading: false
            onLoaded: {
              var schemeName = root.extractSchemeName(path);

              try {
                var jsonData = JSON.parse(text());
                root.schemeLoaded(schemeName, jsonData);
              } catch (e) {
                Logger.w("ColorSchemeTab", "Failed to parse JSON for scheme:", schemeName, e);
                root.schemeLoaded(schemeName, null);
              }
            }
          }
        }
      }
    }

    NToggle {
      label: I18n.tr("tooltips.switch-to-dark-mode")
      description: I18n.tr("panels.color-scheme.dark-mode-switch-description")
      checked: Settings.data.colorSchemes.darkMode
      onToggled: checked => {
                   Settings.data.colorSchemes.darkMode = checked;
                   root.cacheVersion++;
                 }
    }

    NToggle {
      label: I18n.tr("panels.color-scheme.sync-gsettings-label")
      description: I18n.tr("panels.color-scheme.sync-gsettings-description")
      checked: Settings.data.colorSchemes.syncGsettings
      defaultValue: Settings.getDefaultValue("colorSchemes.syncGsettings")
      onToggled: checked => {
                   Settings.data.colorSchemes.syncGsettings = checked;
                   if (checked)
                   ColorSchemeService.pushSystemColorScheme();
                 }
    }

    NComboBox {
      label: I18n.tr("panels.color-scheme.dark-mode-mode-label")
      description: I18n.tr("panels.color-scheme.dark-mode-mode-description")

      model: [
        {
          "name": I18n.tr("panels.color-scheme.dark-mode-mode-off"),
          "key": "off"
        },
        {
          "name": I18n.tr("panels.color-scheme.dark-mode-mode-manual"),
          "key": "manual"
        },
        {
          "name": I18n.tr("common.location"),
          "key": "location"
        }
      ]

      currentKey: Settings.data.colorSchemes.schedulingMode
      defaultValue: Settings.getDefaultValue("colorSchemes.schedulingMode")

      onSelected: key => {
                    Settings.data.colorSchemes.schedulingMode = key;
                    AppThemeService.generate();
                  }
    }

    NDccRow {
      interactive: false
      Layout.fillWidth: true
      visible: Settings.data.colorSchemes.schedulingMode === "manual"

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
          label: I18n.tr("panels.display.night-light-manual-schedule-label")
          description: I18n.tr("panels.display.night-light-manual-schedule-description")
        }

        RowLayout {
          Layout.fillWidth: false
          spacing: Style.marginS

          NText {
            text: I18n.tr("panels.display.night-light-manual-schedule-sunrise")
            pointSize: Style.fontSizeM
            color: Color.onShellTertiary
          }

          NComboBox {
            model: root.timeOptions
            currentKey: Settings.data.colorSchemes.manualSunrise
            placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-start")
            onSelected: key => Settings.data.colorSchemes.manualSunrise = key
            minimumWidth: 120
          }

          Item {
            Layout.preferredWidth: Style.settingsTimeGroupGap
          }

          NText {
            text: I18n.tr("panels.display.night-light-manual-schedule-sunset")
            pointSize: Style.fontSizeM
            color: Color.onShellTertiary
          }

          NComboBox {
            model: root.timeOptions
            currentKey: Settings.data.colorSchemes.manualSunset
            placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-stop")
            onSelected: key => Settings.data.colorSchemes.manualSunset = key
            minimumWidth: 120
          }
        }
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 2: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      label: I18n.tr("panels.color-scheme.color-source-use-wallpaper-colors-label")
      description: I18n.tr("panels.color-scheme.color-source-use-wallpaper-colors-description")
      checked: Settings.data.colorSchemes.useWallpaperColors
      defaultValue: Settings.getDefaultValue("colorSchemes.useWallpaperColors")
      onToggled: checked => {
                   Settings.data.colorSchemes.useWallpaperColors = checked;
                   if (checked) {
                     AppThemeService.generate();
                   } else {
                     ToastService.showNotice(I18n.tr("toast.wallpaper-colors.label"), I18n.tr("toast.wallpaper-colors.disabled"), "settings-color-scheme");
                     if (Settings.data.colorSchemes.predefinedScheme) {
                       ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
                     }
                   }
                 }
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.color-scheme.wallpaper-monitor-source-label")
      description: I18n.tr("panels.color-scheme.wallpaper-monitor-source-description")
      enabled: Settings.data.colorSchemes.useWallpaperColors
      model: {
        var m = [];
        if (Quickshell.screens) {
          for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i];
            var name = screen.name;
            var displayName = name + " (" + screen.width + "x" + screen.height + ")";
            m.push({
                     "key": name,
                     "name": displayName
                   });
          }
        }
        return m;
      }
      currentKey: Settings.data.colorSchemes.monitorForColors || (screen ? screen.name : "")
      onSelected: key => {
                    Settings.data.colorSchemes.monitorForColors = key;
                    AppThemeService.generate();
                  }
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("panels.color-scheme.wallpaper-method-label")
      description: I18n.tr("panels.color-scheme.wallpaper-method-description")
      enabled: Settings.data.colorSchemes.useWallpaperColors
      model: TemplateProcessor.schemeTypes
      currentKey: Settings.data.colorSchemes.generationMethod
      onSelected: key => {
                    Settings.data.colorSchemes.generationMethod = key;
                    AppThemeService.generate();
                  }
    }

    NBox {
      visible: Settings.data.colorSchemes.useWallpaperColors
      Layout.fillWidth: true
      implicitHeight: descriptionColumn.implicitHeight + Style.margin2L
      color: Color.overlay("field")

      Column {
        id: descriptionColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
          width: parent.width
          wrapMode: Text.WordWrap
          text: I18n.tr("panels.color-scheme.method-description." + Settings.data.colorSchemes.generationMethod)
          pointSize: Style.fontSizeS
          color: Color.onShellTertiary
        }

        Row {
          id: colorPreviewRow
          spacing: Style.marginS

          property int diameter: 16 * Style.uiScaleRatio

          Repeater {
            model: [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError]

            Rectangle {
              width: colorPreviewRow.diameter
              height: colorPreviewRow.diameter
              radius: width * 0.5
              color: modelData
            }
          }
        }
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  ColumnLayout {
    spacing: Style.settingsGroupGap
    Layout.fillWidth: true
    enabled: !Settings.data.colorSchemes.useWallpaperColors

    NHeader {
      label: I18n.tr("panels.color-scheme.predefined-title")
      description: I18n.tr("panels.color-scheme.predefined-desc")
      Layout.fillWidth: true
    }

    GridLayout {
      columns: 2
      rowSpacing: Style.marginM
      columnSpacing: Style.marginM
      Layout.fillWidth: true

      Repeater {
        model: ColorSchemeService.schemes

        Rectangle {
          id: schemeItem

          property string schemePath: modelData
          property string schemeName: root.extractSchemeName(modelData)

          opacity: enabled ? 1.0 : 0.6
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          height: 50 * Style.uiScaleRatio
          radius: Style.radiusS
          color: root.getSchemeColor(schemeName, "mSurface")
          border.width: Style.borderL
          border.color: {
            if ((Settings.data.colorSchemes.predefinedScheme === schemeName) && schemeItem.enabled) {
              return Color.accent;
            }
            if (itemMouseArea.containsMouse) {
              return Color.onShellTertiary;
            }
            return Color.borderShell;
          }

          RowLayout {
            id: scheme
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            NText {
              text: schemeItem.schemeName
              pointSize: Style.fontSizeS
              color: root.getSchemeColor(schemeItem.schemeName, "mOnSurface")
              // schemeItem dims the whole card; no second factor on the text.
              autoDim: false
              Layout.fillWidth: true
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              maximumLineCount: 1
            }

            property int diameter: 16 * Style.uiScaleRatio

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mPrimary")
            }

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mSecondary")
            }

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mTertiary")
            }

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mError")
            }
          }

          MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            enabled: schemeItem.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Settings.data.colorSchemes.useWallpaperColors = false;
              Logger.i("ColorSchemeTab", "Disabled wallpaper colors");

              Settings.data.colorSchemes.predefinedScheme = schemeItem.schemeName;
              ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
            }
          }

          Rectangle {
            visible: (Settings.data.colorSchemes.predefinedScheme === schemeItem.schemeName) && schemeItem.enabled
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 0
            anchors.topMargin: -3
            width: Style.settingsSchemeBadgeSize
            height: Style.settingsSchemeBadgeSize
            radius: Math.min(Style.radiusL, width / 2)
            color: Color.accent
            border.width: Style.borderS
            border.color: Color.onAccent

            NIcon {
              icon: "check"
              pointSize: Style.fontSizeXS
              color: Color.onAccent
              anchors.centerIn: parent
            }
          }

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationNormal
            }
          }
        }
      }
    }
  }
}
