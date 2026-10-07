import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../../../Helpers/QtObj2JS.js" as QtObj2JS
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  // Profile section
  // The section head is the NTabBar strip in GeneralTab.qml (groupMode), which
  // heads this sub-tab; a second NHeader here would just repeat it.
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginL

      // Avatar preview
      NImageRounded {
        Layout.preferredWidth: 128 * Style.uiScaleRatio
        Layout.preferredHeight: width
        radius: width / 2
        imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
        fallbackIcon: "person"
        borderColor: Color.mPrimary
        borderWidth: Style.borderM
        Layout.alignment: Qt.AlignTop
      }

      ColumnLayout {
        spacing: Style.settingsGroupGap
        NText {
          text: HostService.displayName
          pointSize: Style.fontSizeM
          color: Color.mPrimary
        }

        NTextInputButton {
          label: I18n.tr("panels.general.profile-picture-label")
          description: I18n.tr("panels.general.profile-picture-description")
          // Read-only basename: the raw stored path is an internal detail;
          // picking a different avatar goes through the file picker button.
          inputReadOnly: true
          text: {
            const path = Settings.data.general.avatarImage;
            return path ? path.split("/").pop() : "";
          }
          placeholderText: '~/.face' // don't translate path
          buttonIcon: "photo"
          buttonTooltip: I18n.tr("panels.general.profile-tooltip")
          onButtonClicked: {
            avatarPicker.openFilePicker();
          }
        }
      }
    }

    NFilePicker {
      id: avatarPicker
      title: I18n.tr("panels.general.profile-select-avatar")
      selectionMode: "files"
      initialPath: Settings.preprocessPath(Settings.data.general.avatarImage).substr(0, Settings.preprocessPath(Settings.data.general.avatarImage).lastIndexOf("/")) || Quickshell.env("HOME")
      nameFilters: ImageCacheService.basicImageFilters
      onAccepted: paths => {
                    if (paths.length > 0) {
                      Settings.data.general.avatarImage = paths[0];
                    }
                  }
    }
  }

  // Fonts

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  ColumnLayout {
    spacing: Style.settingsGroupGap
    Layout.fillWidth: true

    // Font configuration section
    ColumnLayout {
      spacing: Style.settingsGroupGap
      Layout.fillWidth: true

      NSearchableComboBox {
        label: I18n.tr("panels.general.fonts-default-label")
        description: I18n.tr("panels.general.fonts-default-description")
        model: FontService.availableFonts
        currentKey: Settings.data.ui.fontDefault
        placeholder: I18n.tr("panels.general.fonts-default-placeholder")
        searchPlaceholder: I18n.tr("panels.general.fonts-default-search-placeholder")
        popupHeight: 420
        defaultValue: Settings.getDefaultValue("ui.fontDefault")
        settingsPath: "ui.fontDefault"
        onSelected: key => Settings.data.ui.fontDefault = key
      }

      NSearchableComboBox {
        label: I18n.tr("panels.general.fonts-monospace-label")
        description: I18n.tr("panels.general.fonts-monospace-description")
        model: FontService.monospaceFonts
        currentKey: Settings.data.ui.fontFixed
        placeholder: I18n.tr("panels.general.fonts-monospace-placeholder")
        searchPlaceholder: I18n.tr("panels.general.fonts-monospace-search-placeholder")
        popupHeight: 320
        defaultValue: Settings.getDefaultValue("ui.fontFixed")
        settingsPath: "ui.fontFixed"
        onSelected: key => Settings.data.ui.fontFixed = key
      }

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.general.fonts-default-scale-label")
        description: I18n.tr("panels.general.fonts-default-scale-description")
        from: 0.75
        to: 1.25
        stepSize: 0.01
        showReset: true
        value: Settings.data.ui.fontDefaultScale
        defaultValue: Settings.getDefaultValue("ui.fontDefaultScale")
        onMoved: value => Settings.data.ui.fontDefaultScale = value
        text: Math.floor(Settings.data.ui.fontDefaultScale * 100) + "%"
      }

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.general.fonts-monospace-scale-label")
        description: I18n.tr("panels.general.fonts-monospace-scale-description")
        from: 0.75
        to: 1.25
        stepSize: 0.01
        showReset: true
        value: Settings.data.ui.fontFixedScale
        defaultValue: Settings.getDefaultValue("ui.fontFixedScale")
        onMoved: value => Settings.data.ui.fontFixedScale = value
        text: Math.floor(Settings.data.ui.fontFixedScale * 100) + "%"
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 3: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.reverse-scrolling-label")
      description: I18n.tr("panels.general.reverse-scrolling-description")
      checked: Settings.data.general.reverseScroll
      defaultValue: Settings.getDefaultValue("general.reverseScroll")
      onToggled: checked => Settings.data.general.reverseScroll = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.smooth-scrolling-label")
      description: I18n.tr("panels.general.smooth-scrolling-description")
      checked: Settings.data.general.smoothScrollEnabled
      defaultValue: Settings.getDefaultValue("general.smoothScrollEnabled")
      onToggled: checked => Settings.data.general.smoothScrollEnabled = checked
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 4: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    RowLayout {
      spacing: Style.marginL
      Layout.fillWidth: true

      NButton {
        icon: "wand"
        text: I18n.tr("panels.general.launch-setup-wizard")
        outlined: true
        Layout.fillWidth: true
        onClicked: {
          var targetScreen = PanelService.openedPanel ? PanelService.openedPanel.screen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
          if (!targetScreen) {
            return;
          }
          var setupPanel = PanelService.getPanel("setupWizardPanel", targetScreen);
          if (setupPanel) {
            setupPanel.telemetryOnlyMode = false;
            setupPanel.open();
          } else {
            Qt.callLater(() => {
                           var sp = PanelService.getPanel("setupWizardPanel", targetScreen);
                           if (sp) {
                             sp.telemetryOnlyMode = false;
                             sp.open();
                           }
                         });
          }
        }
      }

      NButton {
        icon: "external-link"
        text: I18n.tr("common.documentation")
        outlined: true
        Layout.fillWidth: true
        onClicked: {
          Qt.openUrlExternally("https://github.com/ShineBreaker/nosDshell");
        }
      }

      NButton {
        icon: "json"
        text: I18n.tr("panels.general.copy-settings")
        outlined: true
        Layout.fillWidth: true
        onClicked: {
          var plainData = QtObj2JS.qtObjectToPlainObject(Settings.data);
          var json = JSON.stringify(plainData, null, 2);
          Quickshell.execDetached(["wl-copy", json]);
          ToastService.showNotice(I18n.tr("panels.general.settings-copied"));
        }
      }
    }
  }
}
